//
//  kkp_instance.m
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import "kkp_instance.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "lauxlib.h"
#import "kkp.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_converter.h"

#pragma mark - 公共方法
/// 针对 oc 实例对象创建一个对应的 实例 userdata
int kkp_instance_create_userdata(lua_State *L, id object)
{
    return kkp_safeInLuaStack(L, ^int{
        // 获取实例列表元表，并压栈
        luaL_getmetatable(L, KKP_INSTANCE_USER_DATA_LIST_TABLE);
        lua_pushlightuserdata(L, (__bridge void *)(object));// oc 实例对地址作为 key
        lua_rawget(L, -2);// 获取 oc 实例对象地址 key 对应的 实例 userdata，并压栈，如果没有获取到值，压入的将会是 nil
        lua_remove(L, -2); // 从栈上移除实例列表元表
        
        KKPInstanceUserdata* instanceInTable = lua_touserdata(L, -1);// 转换栈顶数据到一个 实例 userdata 指针
        
        // 如果 实例 userdata 指针或者 实例 userdata 引用的 oc 实例对象不存在，则需要创建 实例 userdata
        if (!instanceInTable || !instanceInTable->instance) {
            lua_pop(L, 1); // 弹出栈顶存在的 nil
            
            // 创建 实例 userdata
            size_t nbytes = sizeof(KKPInstanceUserdata);
            KKPInstanceUserdata *instance = (KKPInstanceUserdata *)lua_newuserdata(L, nbytes);
            instance->instance = object;// 是指 oc 实例对象
            instance->isBlock = kkp_isBlock(object);// 判读下对象是否是 block 对象
            
            // 给 实例 userdata 设置元表
            luaL_getmetatable(L, KKP_INSTANCE_USER_DATA_META_TABLE);
            lua_setmetatable(L, -2);
            
            // oc 实例对象如果不是 block，就需要把 实例 userdata 存入到 实例列表元表里
            if (!instance->isBlock) {
                // 获取 实例列表元表，并压栈
                luaL_getmetatable(L, KKP_INSTANCE_USER_DATA_LIST_TABLE);
                // 压入 oc 实例对象地址作为 key
                lua_pushlightuserdata(L, (__bridge void *)(instance->instance));
                // 复制 实例 userdata 并压栈，作为 value
                lua_pushvalue(L, -3);
                // 把 key 和 value 设置到 实例列表元表里
                lua_rawset(L, -3);
                // 移除 实例列表元表
                lua_pop(L, 1);
            }
            
            // 给 实例 userdata 设置一个关联表，关联表不等于元表
            // 目前用不到
            lua_newtable(L);
            lua_setuservalue(L, -2);
        }
        return 1;
    });
}

#pragma mark - instance userdata 提供的元API
/// 由于 lua 函数内的 self 是一个 实例 userdata，而这个 实例 userdata 的元表中是有该 __index 方法的，如果任何不存在 key 都会进入到这个方法来。
/// 比如 self:view()，在 lua 语法糖中， self:view() == self.view(self)，那么 self 就是 实例 userdata，而 view 就是要检索的 key。在这个方法里就会压入两个参数，第一个是 self(实例 userdata)，第二个是 view 字符串
/// 注意：此时还没有发生实际调用，只是为了寻找 view 这个属性对应的闭包函数
static int LUserData_kkp_instance__index(lua_State *L)
{
    // 获取要检索的 key，此时的 key 也是函数名字
    const char* func = lua_tostring(L, -1);
    if (func) {
        NSString* selector = [NSString stringWithFormat:@"%s", func];
        // if super
        if ([selector hasPrefix:KKP_SUPER_PREFIX]) {
            kkp_safeInLuaStack(L, ^int{
                // make a super selector
                SEL superSelector = NSSelectorFromString(selector);
                SEL sel = NSSelectorFromString([selector substringFromIndex:[KKP_SUPER_PREFIX length]]);
                KKPInstanceUserdata* instance = lua_touserdata(L, -2);
                Class klass = object_getClass(instance->instance);
                Class superClass = class_getSuperclass(klass);
                Method superMethod = class_getInstanceMethod(superClass, sel);
                IMP superMethodImp = method_getImplementation(superMethod);
                char *typeDescription = (char *)method_getTypeEncoding(superMethod);
                BOOL b = class_addMethod(klass, superSelector, superMethodImp, typeDescription);
                assert(b);
                return 0;
            });
        }
        
        // 捕获一个栈顶的值（此时是入参2 view 字符串，也就是 func name）作为 upvalue， 并压入一个闭包到栈顶
        lua_pushcclosure(L, kkp_invoke, 1);
        return 1;// 返回 闭包给到 lua 层，lua 层调用后，才会触发 kkp_invoke 这个函数
    }
    return 0;
}

/// 给实例属性赋值
static int LUserData_kkp_instance__newIndex(lua_State *L)
{
    KKPInstanceUserdata* instance = lua_touserdata(L, -3);
    if (!instance || !instance->instance) {
        return 0;
    }
    const char* prop = lua_tostring(L, -2);
    char* func = kkp_toObjcPropertySel(prop);
    if (!func) {
        return 0;
    }
    
    SEL sel = NSSelectorFromString([NSString stringWithFormat:@"%s", func]);
    Class klass = object_getClass(instance->instance);
    NSMethodSignature  *signature = [klass instanceMethodSignatureForSelector:sel];
    if (signature) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = instance->instance;
        invocation.selector = sel;
        const char* typeDescription = [signature getArgumentTypeAtIndex:2];
        if (typeDescription) {
            void *argValue = kkp_toOCObject(L, typeDescription, -1);
            if (argValue == NULL) {
                id object = nil;
                [invocation setArgument:&object atIndex:2];
            } else {
                [invocation setArgument:argValue atIndex:2];
            }
            [invocation invoke];
        } else {
            NSString* error = [NSString stringWithFormat:@"can not found param [%@ %s]", klass, func];
            KKP_ERROR(L, error.UTF8String);
        }
    } else {
        NSString* error = [NSString stringWithFormat:@"can not found prop [%@ %s]", klass, func];
        KKP_ERROR(L, error.UTF8String);
    }
    free(func);
    return 0;
}

static int LUserData_kkp_instance__call(lua_State *L)
{
    KKPInstanceUserdata* instance = lua_touserdata(L, 1);
    id object = instance->instance;
    if (kkp_isBlock(object)) {
        return kkp_callBlock(L);
    }
    return 0;
}

static int LUserData_kkp_instance__gc(lua_State *L)
{
    KKPInstanceUserdata* instance = lua_touserdata(L, -1);
    if (instance && !instance->isBlock && instance->instance) {
        kkp_instance_create_userdata(L, instance->instance);
    }
    return 0;
}

static const struct luaL_Reg UserDataMetaMethods[] = {
    {"__index", LUserData_kkp_instance__index},
    {"__newindex", LUserData_kkp_instance__newIndex},
    {"__call", LUserData_kkp_instance__call},
    {"__gc", LUserData_kkp_instance__gc},
    {NULL, NULL}
};

#pragma mark - instance 模块提供的API
static const struct luaL_Reg Methods[] = {
    {NULL, NULL}
};

static const struct luaL_Reg MetaMethods[] = {
    {NULL, NULL}
};

LUAMOD_API int luaopen_kkp_instance(lua_State *L)
{
    /// 创建 instance user data 元表，并添加元方法
    luaL_newmetatable(L, KKP_INSTANCE_USER_DATA_META_TABLE);// 新建元表用于存放元方法
    luaL_setfuncs(L, UserDataMetaMethods, 0); //给元表设置函数
    
    /// 新建元表用于存放所有 instance user data
    luaL_newmetatable(L, KKP_INSTANCE_USER_DATA_LIST_TABLE);
    
    // 给存放实例的元表设置元表，目的是让存放实例的元表在设置key的时候，使用weak引用
    lua_newtable(L);
    lua_pushstring(L, "k");
    lua_setfield(L, -2, "__mode");  // Make weak table
    lua_setmetatable(L, -2);
    
    /// 新建 instance 模块
    luaL_newlib(L, Methods);// 创建库函数
    
    /// 新建 instance 模块元表
    luaL_newmetatable(L, KKP_INSTANCE_META_TABLE);
    luaL_setfuncs(L, MetaMethods, 0); //给元表设置函数
    lua_setmetatable(L, -2);
    
    return 1;
}
