//
//  kkp.m
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import "kkp.h"
#import "lualib.h"
#import "lauxlib.h"
#import "kkp_stdlib.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_class.h"
#import "kkp_instance.h"
#import "kkp_converter.h"

#define KKP "kkp" // kkp lua module

LUALIB_API void kkp_open_libs(lua_State *L);

#pragma mark - 状态机
static lua_State *currentL;
lua_State *kkp_currentLuaState(void) {
    if (!currentL)
        currentL = luaL_newstate();
    
    return currentL;
}

#pragma mark - 日志相关
static kkp_log_block_t log_callback;
/// 设置日志回调
void kkp_setLogCallback(kkp_log_block_t callback)
{
    log_callback = callback;
}

/// 获取日志回调
kkp_log_block_t kkp_getLogCallback(void)
{
    return log_callback;
}

static kkp_complete_block_t swizzle_callback;
/// 设置方法交换的回调
void kkp_setSwizzleCallback(kkp_complete_block_t callback)
{
    swizzle_callback = callback;
}

/// 获取方法交换的回调
kkp_complete_block_t kkp_getSwizzleCallback(void)
{
    return swizzle_callback;
}

static kkp_complete_block_t complete_callback;
/// 设置完成回调
void kkp_setCompleteCallback(kkp_complete_block_t callback)
{
    complete_callback = callback;
}

/// 获取完成回调
kkp_complete_block_t kkp_getCompleteCallback(void)
{
    return complete_callback;
}

/// 错误处理函数
static int kkp_panic(lua_State *L) {
    NSString* log = [NSString stringWithFormat:@"[SPA] PANIC: unprotected error in call to Lua API (%s)\n", lua_tostring(L, -1)];
    if (kkp_getCompleteCallback()) {
        kkp_getCompleteCallback()(NO, log);
    }
    printf("[SPA] PANIC: unprotected error in call to Lua API (%s)\n", lua_tostring(L, -1));
    return 0;
}

#pragma mark - 启动 kkp 相关

/// 安装 lua c 标准库 和 kkp c 库
void kkp_setup(void)
{
    // 切换到应用主bundle目录，为了 lua 可以寻找到 lua 脚本
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];
    
    // 创建状态机
    lua_State *L = kkp_currentLuaState();
    // 设置错误处理函数
    lua_atpanic(L, kkp_panic);
    // 打开 lua c 标准库
    luaL_openlibs(L);
    
    // 打开 kkp c 标准库
    kkp_open_libs(L);
    
    // 添加全局变量
    
    // 启动GC
    
}

/// 启动 kkp
void kkp_start(kkp_CLibFunction extensionCLibFunction)
{
    // 安装 lua c 标准库 和 kkp c 库
    kkp_setup();
    
    lua_State *L = kkp_currentLuaState();
    
    // 加载 c 扩展库，为了方便添加外部 c 模块
    if (extensionCLibFunction) {
        extensionCLibFunction(L);
    }
    
    // 加载 kkp lua 脚本标准库
    char stdlib[] = KKP_STDLIB;// 编译好的字节码，字节码减少了编译过程，能更快加载；如果修改了 stdlib 里的 lua 文件，就需要重新 build，重新生成新的字节码
    size_t stdlibSize = sizeof(stdlib);
    if (luaL_loadbuffer(L, stdlib, stdlibSize, "loading kkp lua stdlib") || lua_pcall(L, 0, LUA_MULTRET, 0)) {
        NSString* log = [NSString stringWithFormat:@"[KKP] PANIC: opening kkp lua stdlib failed: %s\n", lua_tostring(L, -1)];
        if (kkp_getCompleteCallback()) {
            kkp_getCompleteCallback()(NO, log);
        }
        printf("opening kkp lua stdlib failed: %s\n", lua_tostring(L,-1));
        return;
    }
}

#pragma mark - 运行 lua 脚本相关
void kkp_postRunLuaError(int result)
{
    lua_State *L = kkp_currentLuaState();
    if (result != 0) {
        NSString* log = [NSString stringWithFormat:@"[KKP] PANIC: opening kkp scripts failed (%s)\n", lua_tostring(L, -1)];
        if (kkp_getCompleteCallback()) {
            kkp_getCompleteCallback()(NO, log);
        }
        printf("opening kkp scripts failed: %s\n", lua_tostring(L,-1));
    } else if(kkp_getCompleteCallback()){
        NSString *successLog = @"[KKP] SUCCESS: lua do string success";
        kkp_getCompleteCallback()(YES, successLog);
    }
}

void kkp_runLuaString(const char *script)
{
    lua_State *L = kkp_currentLuaState();
    kkp_safeInLuaStack(L, ^int{
        int result = luaL_dostring(L, script);
        kkp_postRunLuaError(result);
        return 0;
    });
}

void kkp_runLuaFile(const char *fname)
{
    lua_State *L = kkp_currentLuaState();
    kkp_safeInLuaStack(L, ^int{
        int result = luaL_dofile(L, fname);
        kkp_postRunLuaError(result);
        return 0;
    });
}

void kkp_runLuaByteCode(NSData *data, NSString *name)
{
    lua_State *L = kkp_currentLuaState();
    kkp_safeInLuaStack(L, ^int{
        int result = (luaL_loadbuffer(L, [data bytes], data.length, [name cStringUsingEncoding:NSUTF8StringEncoding]) || lua_pcall(L, 0, LUA_MULTRET, 0));
        kkp_postRunLuaError(result);
        return 0;
    });
}

#pragma mark - 模块相关方法

static int _log(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        struct S
        {
            id instance;
        };
        struct S* s = kkp_toOCObject(L, "@", -1);
        if (s && s->instance) {
            if (kkp_getLogCallback()) {
                kkp_getLogCallback()([NSString stringWithFormat:@"%@", s->instance]);
            }
        } else {
            if (kkp_getLogCallback()) {
                kkp_getLogCallback()(@"null");
            }
        }
        if (s != NULL) {
            free(s);
        }
        return 0;
    });
}

static int toId(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        struct S
        {
            id instance;
        };
        struct S* s = kkp_toOCObject(L, "@", -1);
        if (s && s->instance) {
            kkp_instance_create_userdata(L, s->instance);
            free(s);
            return 1;
        } else {
            KKP_ERROR(L, "the param type not support !");
        }
        return 0;
    });
}

static int toLuaString(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        KKPInstanceUserdata* instance = lua_touserdata(L, -1);
        if (instance->instance) {
            lua_pushstring(L, [instance->instance description].UTF8String);
            return 1;
        } else {
            KKP_ERROR(L, "the param type not support !");
        }
        return 0;
    });
}

static int _dispatch_after(lua_State *L)
{
    int seconds = lua_tonumber(L, 2);
    struct S
    {
        id block;
    };
    
    struct S* s = (struct S*)kkp_toOCObject(L, "@", -1);
    if (s && s->block) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), s->block);
    }
    
    if (s != NULL) {
        free(s);
    }
    return 0;
}

static int _isNull(lua_State *L){
    return kkp_safeInLuaStack(L, ^int{
        void **ud = (void **)lua_touserdata(L, -1);
        if (ud == NULL || *ud == NULL) {
            lua_pushboolean(L, 1);
            return 1;
        } else {
            lua_pushboolean(L, 0);
            return 1;
        }
    });
}

static const struct luaL_Reg Methods[] = {
    {"log", _log},
    {"toId", toId},
    {"toLuaString", toLuaString},
    {"dispatch_after", _dispatch_after},
    {"isNull",_isNull},
    {NULL, NULL}
};

LUAMOD_API int luaopen_kkp(lua_State *L)
{
    luaL_newlib(L, Methods);// 创建库函数
    return 1;
}

#pragma mark - 库加载相关方法
static const luaL_Reg kkp_libs[] = {
    {KKP, luaopen_kkp},
    {KKP_CLASS, luaopen_kkp_class},
    {KKP_INSTANCE, luaopen_kkp_instance},
    {NULL, NULL}
};

/// 加载 kkp 库
LUALIB_API void kkp_open_libs(lua_State *L)
{
    const luaL_Reg *lib;
    for (lib = kkp_libs; lib->func; lib++) {
        /**
         执行完后，package.loaded 新增一个字段
         package.loaded[libname] = lib {
            注册的函数名：注册函数指针
            其他函数
         }
         
         并且 全局注册表中的loaded表新增一个字段，因为 lua 安装 package 标准库的时候，就已经设置了 register["loaded"] = package.loaded
         register["loaded"] = {
            libname: lib,
            其他库
         }
         
         最后一个参数表示是否需要设置成全局标量，如果为1，表示就是全局变量,
         相当于 _G[libname] = lib，那么在 lua 脚本中也不需要 require 就可以直接使用这个模块
         */
        luaL_requiref(L, lib->name, lib->func, 0);
        lua_pop(L, 1);  /* remove lib */
    }
}
