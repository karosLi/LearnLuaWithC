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
#import "kkp_struct.h"
#import "kkp_converter.h"
#import "kkp_global_config.h"
#import "kkp_global_util.h"

static void kkp_setup(void);
static void kkp_addGlobals(lua_State *L);
LUALIB_API void kkp_open_libs(lua_State *L);

#pragma mark - 状态机
static lua_State *currentL;
lua_State *kkp_currentLuaState(void) {
    if (!currentL)
        currentL = luaL_newstate();
    
    return currentL;
}

#pragma mark - 日志相关
static KKPLogHandler kkp_log_handler;
/// 设置日志回调
void kkp_setLogHandler(KKPLogHandler handler)
{
    kkp_log_handler = handler;
}

/// 获取日志回调
KKPLogHandler kkp_getLogHandler(void)
{
    return kkp_log_handler;
}

static KKPLuaRuntimeHanlder kkp_lua_runtime_handler;
/// 设置 lua runtime 处理器
void kkp_setLuaRuntimeHandler(KKPLuaRuntimeHanlder handler)
{
    kkp_lua_runtime_handler = handler;
}

/// 获取 lua runtime  处理器
KKPLuaRuntimeHanlder kkp_getLuaRuntimeHandler(void)
{
    return kkp_lua_runtime_handler;
}

/// 错误处理函数
static int kkp_panic(lua_State *L) {
    NSString *log = [NSString stringWithFormat:@"[KKP] PANIC: unprotected error in call to Lua API (%s)\n\n%s", lua_tostring(L, -1), kkp_getLuaStackTrace(L)];
    
    if (kkp_getLuaRuntimeHandler()) {
        kkp_getLuaRuntimeHandler()(log);
    } else {
        KKP_ERROR(L, log);
    }
    return 0;
}

#pragma mark - 启动 kkp 相关

/// 启动 kkp
void kkp_start(KKPCLibFunction extensionCLibFunction)
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
        NSString *log = [NSString stringWithFormat:@"[KKP] PANIC: opening kkp lua stdlib failed: %s\n", lua_tostring(L, -1)];
        if (kkp_getLuaRuntimeHandler()) {
            kkp_getLuaRuntimeHandler()(log);
        }
        printf("opening kkp lua stdlib failed: %s\n", lua_tostring(L,-1));
        return;
    }
}

/// 安装 lua c 标准库 和 kkp c 库
static void kkp_setup(void)
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
    kkp_addGlobals(L);
    
    // 启动GC
    
}

/// 添加全局 lua 函数
static void kkp_addGlobals(lua_State *L)
{
    lua_getglobal(L, KKP);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1); // 弹出 nil
        lua_newtable(L);
        lua_pushvalue(L, -1);// 把新表拷贝并压栈
        lua_setglobal(L, KKP);
    }
    
    /// 设置 kkp.version 版本号
    lua_pushnumber(L, KKP_VERSION);
    lua_setfield(L, -2, "version");
    
    /// 设置 kkp.setConfig() 函数
    /// 比如： kkp.setConfig({openBindOCFunction="true", mobdebug="true"}
    lua_pushcfunction(L, kkp_global_setConfig);
    lua_setfield(L, -2, "setConfig");
    
    /// 设置 kkp.isNull() 函数
    lua_pushcfunction(L, kkp_global_isNull);
    lua_setfield(L, -2, "isNull");
    
    /// 设置 kkp.root() 函数
    lua_pushcfunction(L, kkp_global_root);
    lua_setfield(L, -2, "root");

    /// 设置 kkp.print() 函数
    lua_pushcfunction(L, kkp_global_print);
    lua_setfield(L, -2, "print");
    
    /// 设置 kkp.exit() 函数
    lua_pushcfunction(L, kkp_global_exitApp);
    lua_setfield(L, -2, "exit");
    
    /// 设置 kkp.appVersion 版本号
    lua_pushstring(L, [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] UTF8String]);
    lua_setfield(L, -2, "appVersion");
    
    /// 设置全局 NSDocumentDirectory
    lua_pushstring(L, [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] UTF8String]);
    lua_setglobal(L, "NSDocumentDirectory");
    
    /// 设置全局 NSLibraryDirectory
    lua_pushstring(L, [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] UTF8String]);
    lua_setglobal(L, "NSLibraryDirectory");
    
    /// 设置全局 NSCacheDirectory
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    lua_pushstring(L, [cachePath UTF8String]);
    lua_setglobal(L, "NSCacheDirectory");

    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes: nil error:&error];
}

#pragma mark - 运行 lua 脚本相关
void kkp_postRunLuaError(int result)
{
    lua_State *L = kkp_currentLuaState();
    if (result != 0) {
        NSString *log = [NSString stringWithFormat:@"[KKP] PANIC: opening kkp scripts failed (%s)\n \n%s", lua_tostring(L, -1), kkp_getLuaStackTrace(L)];
        if (kkp_getLuaRuntimeHandler()) {
            kkp_getLuaRuntimeHandler()(log);
        }
        printf("opening kkp scripts failed: %s\n", lua_tostring(L,-1));
    } else if (kkp_getLogHandler()){
        NSString *successLog = @"[KKP] SUCCESS: lua do string success";
        kkp_getLogHandler()(successLog);
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

static const struct luaL_Reg Methods[] = {
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
    {KKP_STRUCT, luaopen_kkp_struct},
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
