//
//  kkp_class.m
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import "kkp_class.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "lauxlib.h"
#import "kkp.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_runtime_helper.h"
#import "kkp_instance.h"
#import "kkp_converter.h"
#import "KKPBlockWrapper.h"

#pragma mark - 运行时方法替换
static void __KKP_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation)
{
    lua_State* L = kkp_currentLuaState();
    kkp_safeInLuaStack(L, ^int{
        if (kkp_runtime_isReplaceByKKP(object_getClass(self), invocation.selector)) {// selector 是否已经被替换了
            int nresults = kkp_callLuaFunction(L, self, invocation.selector, invocation);
            if (nresults > 0) {
                NSMethodSignature *signature = [self methodSignatureForSelector:invocation.selector];
                void *pReturnValue = kkp_toOCObject(L, [signature methodReturnType], -1);
                if (pReturnValue != NULL) {
                    [invocation setReturnValue:pReturnValue];
                    free(pReturnValue);
                }
            }
        } else {
            SEL origin_selector = NSSelectorFromString(KKP_ORIGIN_FORWARD_INVOCATION_SELECTOR_NAME);
            ((void(*)(id, SEL, id))objc_msgSend)(self, origin_selector, invocation);
        }
        return 0;
    });
}

static NSMutableArray * kkp_class_replacedClassMethods() {
    static NSMutableArray *class2method = nil;
    if (class2method == nil) {
        class2method = [NSMutableArray array];
    }
    return class2method;
}

static void kkp_class_overrideMethod(Class klass, SEL sel, const char *typeDescription)
{
    if (klass == nil || sel == nil) {
        return;
    }
    
    if (!typeDescription) {// 类型描述为空时，就从类里获取
        Method method = class_getInstanceMethod(klass, sel);
        typeDescription = (char *)method_getTypeEncoding(method);
    }
    
    /// 给类添加自定义的 forwardInvocation 方法实现，并替换掉旧的 forwardInvocation 方法
    kkp_runtime_swizzleForwardInvocation(klass, (IMP)__KKP_ARE_BEING_CALLED__);
    
    /// 如果类能响应入参方法，就给类添加一个原始方法，方便被 hook 的方法内部调用原始的方法
    if (class_respondsToSelector(klass, sel)) {
        IMP originalImp = class_getMethodImplementation(klass, sel);
        SEL originSelector = kkp_runtime_originForSelector(sel);
        if(!class_respondsToSelector(klass, originSelector)) {
            class_addMethod(klass, originSelector, originalImp, typeDescription);
        }
    }
    
    /// 把要 hook 的方法实现，直接替换成 _objc_msgForward，意味着 hook 的方法在调用时，直接走消息转发流程，不用经过 method list 查找流程
    /// 如果方法存在就替换，否则就是添加
    class_replaceMethod(klass, sel, kkp_runtime_getMsgForwardIMP(klass, sel), typeDescription);
    
    /// 把已经替换的方法记录下
    [kkp_class_replacedClassMethods() addObject:@{@"class":NSStringFromClass(klass), @"sel":NSStringFromSelector(sel)}];
}

static bool kkp_class_recoverMethod(const char* class_name, const char* selector_name)
{
    if (class_name && selector_name) {
        Class klass = objc_getClass(class_name);
        Class metaClass = object_getClass(klass);
        SEL sel = NSSelectorFromString([NSString stringWithFormat:@"%s", kkp_toObjcSel(selector_name)]);
        
        BOOL canBeReplace = NO;
        NSString* selectorName = [NSString stringWithFormat:@"%s", selector_name];
        if ([selectorName hasPrefix:KKP_STATIC_PREFIX]) {
            sel = NSSelectorFromString([selectorName substringFromIndex:[KKP_STATIC_PREFIX length]]);
            if ([metaClass instancesRespondToSelector:sel]) {
                klass = metaClass;
                canBeReplace = YES;
            }
        } else {
            if ([klass instancesRespondToSelector:sel]) {
                canBeReplace = YES;
            } else {
                if ([metaClass instancesRespondToSelector:sel]) {
                    klass = metaClass;
                    canBeReplace = YES;
                }
            }
        }
        if (canBeReplace) {
            // cancel forward
            SEL originSelector = kkp_runtime_originForSelector(sel);
            Method originalMethod = class_getInstanceMethod(klass, originSelector);
            const char *typeEncoding = method_getTypeEncoding(originalMethod);
            IMP originalIMP = method_getImplementation(originalMethod);
            class_replaceMethod(klass, sel, originalIMP, typeEncoding);
            
            return true;
        }
    }
    return false;
}

#pragma mark - 帮助方法
int kkp_class_create_userdata(lua_State *L, const char *klass_name)
{
    return kkp_safeInLuaStack(L, ^int{
        // 从类列表元表里获取 class_name 对应 class userdata，并压栈，如果没有的话，压入会是一个 nil
        luaL_getmetatable(L, KKP_CLASS_USER_DATA_LIST_TABLE);
        lua_getfield(L, -1, klass_name);
        
        // 如果还没有创建 class userdata
        if (lua_isnil(L, -1)) {
            Class klass = objc_getClass(klass_name);
            if (klass == nil) {
                return 0;// 没有结果返回，在 lua 中做条件判断时，会返回 false
            }
            size_t nbytes = sizeof(KKPInstanceUserdata);
            KKPInstanceUserdata *userData = (KKPInstanceUserdata *)lua_newuserdata(L, nbytes);
            userData->instance = klass;
            userData->isClass = true;
            userData->isCallSuper = false;
            userData->isCallOrigin = false;
            userData->isBlock = false;
            
            // 给 class userdata 设置 元表
            luaL_getmetatable(L, KKP_CLASS_USER_DATA_META_TABLE);
            lua_setmetatable(L, -2);
            
            // 给 class userdata 设置一个关联表，关联表不等于元表
            // 关联表用于存储 lua 函数的名字和函数体，方便 oc 调用 lua 函数
            lua_newtable(L);
            lua_setuservalue(L, -2);
            
            // 把栈顶的 class userdata 复制一遍，然后再放到栈顶，目的是为了设置 KKP_CLASS_LIST_TABLE 的值
            lua_pushvalue(L, -1);
            // -4 的位置是 KKP_CLASS_LIST_TABLE，目的是标记这个类已经加载过了
            lua_setfield(L, -4, klass_name);
        }
        return 1;
    });
}

#pragma mark - class userdata 提供的元API
/// 因为 class userdata 指针是不会存 key的，所以这里取值时会调用 class_userdata[key]，1：userdata 指针，2：key
/// lua 调用原生类方法
static int LUserData_kkp_class__index(lua_State *L)
{
    // 获取要检索的 key，也就是函数名
    const char* func = lua_tostring(L, -1);
    if (func == NULL) {
        return 0;
    }
    
    // 获取 class user data
    KKPInstanceUserdata *userdata = lua_touserdata(L, -2);
    if (userdata == NULL || userdata->instance == NULL) {
        return 0;
    }
    
    // 是否是 alloc 函数，返回一个 alloc 调用闭包
    if (kkp_isAllocMethod(func)) {
        lua_pushcclosure(L, kkp_alloc_closure, 1);
        return 1;
    }
    
    // 返回一个普通函数调用闭包
    Class klass = object_getClass(userdata->instance);
    if ([klass instancesRespondToSelector:NSSelectorFromString([NSString stringWithFormat:@"%s", kkp_toObjcSel(func)])]) {
        lua_pushcclosure(L, kkp_invoke_closure, 1);
        return 1;
    }
    return 0;
}

/// 用于替换和添加 OC 类方法
/// 因为 class userdata 指针是不会存 key的，所以这里更新时会调用 class_userdata[key] = value，1：userdata 指针，2：key，3：value（函数）
static int LUserData_kkp_class__newIndex(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        const char* key = lua_tostring(L, 2);
        if (strcmp(key, [KKP_ENV_SCOPE UTF8String]) == 0) {// 说明是保存环境，把环境保存到关联表里，为了在实例方法调用时，设置 self 关键字
            // 获取 class userdata 的关联表，并压栈
            lua_getuservalue(L, 1);
            // 压入 key
            lua_pushstring(L, [KKP_ENV_SCOPE UTF8String]);
            // 把环境值压栈
            lua_pushvalue(L, 3);
            // 把环境值保存到关联表里，相当于 associated_table["_SCOPE"] = scope
            lua_rawset(L, -3);
        } else if (lua_type(L, 3) == LUA_TFUNCTION) {// 只能 hook 函数
            KKPInstanceUserdata *userdata = lua_touserdata(L, 1);
            if (userdata) {
                const char* func = lua_tostring(L, 2);
                Class klass = userdata->instance;
                Class metaClass = object_getClass(klass);
                char *typeDescription = nil;
                
                NSString *selectorName = [NSString stringWithFormat:@"%s", kkp_toObjcSel(func)];
                SEL sel = NSSelectorFromString(selectorName);
                if ([selectorName hasPrefix:KKP_STATIC_PREFIX]) {// lua 脚本里如果方法名是以 STATIC 为前缀，说明一个静态方法，此时就需要找到 OC 类的元类
                    sel = NSSelectorFromString([selectorName substringFromIndex:[KKP_STATIC_PREFIX length]]);
                    klass = metaClass;
                }
                
                if (class_respondsToSelector(klass, sel)) {// 能响应就替换方法
                    /// 替换方法
                    kkp_class_overrideMethod(klass, sel, NULL);
                } else {// 否则添加新方法
                    /// 计算参数个数，通过偏离 : 符号来确定个数
                    int argCount = 0;
                    const char *match = selectorName.UTF8String;
                    while ((match = strchr(match, ':'))) {
                        match += 1; // Skip past the matched char
                        argCount++;
                    }
                    
                    /// 配置类型描述
                    size_t typeDescriptionSize = 3 + argCount;// 前三个是 返回类型，self 和 :，后面都是参数了。比如 @@: 表示返回类型是对象，self 和 sel
                    typeDescription = malloc(typeDescriptionSize * sizeof(char));
                    memset(typeDescription, '@', typeDescriptionSize);// 设置每个字符都是 @
                    typeDescription[2] = ':'; // 设置第三个字符是 :
                    
                    /// 添加方法
                    kkp_class_overrideMethod(klass, sel, typeDescription);
                    free(typeDescription);
                }
                
                // 获取 class userdata 的关联表，并压栈
                lua_getuservalue(L, 1);
                
                /**
                 此时的栈
                 4/-1: type=table
                 value=
                 {
                 }

                 3/-2: type=function
                 2/-3: type=string value=doSomeThing
                 1/-4: type=userdata
                 */
                
                // 把关联表移动到 第二个 索引上
                lua_insert(L, 2);
                
                /**
                 此时的栈
                 
                 4/-1: type=function
                 3/-2: type=string value=doSomeThing
                 2/-3: type=table
                 value=
                 {
                 }
                 1/-4: type=userdata
                 */
                // 把 索引 3 作为 key，索引 4 作为 value，设置到关联表上
                lua_rawset(L, 2);
                /**
                 此时的栈
                 2/-3: type=table
                 value=
                 {
                 doSomeThing = function
                 }
                 1/-4: type=userdata
                 */
            }
        } else {
            KKP_ERROR(L, "type must function");
        }
        return 0;
    });
}

static const struct luaL_Reg UserDataMetaMethods[] = {
    {"__index", LUserData_kkp_class__index},
    {"__newindex", LUserData_kkp_class__newIndex},
    {NULL, NULL}
};

#pragma mark - class 模块提供的API
/// 查找一个 OC class user data，找不到就创建
static int LF_kkp_class_find_userData(lua_State *L)
{
    const char* klass_name = lua_tostring(L, 1);
    return kkp_class_create_userdata(L, klass_name);
}

/// 给 class user data 对应的 class 添加协议，添加协议的目的，是为了给类添加新方法时可以找到方法签名的依据
/// arg1 是 class user data，arg2 是 lua table 数组
static int LF_kkp_class_add_protocols(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        KKPInstanceUserdata *instanceUserdata = (KKPInstanceUserdata *)luaL_checkudata(L, 1, KKP_CLASS_USER_DATA_META_TABLE);
        
        if (!instanceUserdata->isClass) {
            NSString *error = @"Can only set a protocol on a class (You are trying to set one on an instance)";
            KKP_ERROR(L, error);
            return 0;
        }
        
        if (!lua_istable(L, 2)) {
            NSString *error = @"Can only receive a table as protocol list";
            KKP_ERROR(L, error);
            return 0;
        }
        
        lua_pushnil(L);  // 压入一个key，nil 表示准备遍历一个 table 数组
        while (lua_next(L, 2)) {// 遍历 table 数组，并把键值压栈。2 表示表的位置
            const char *protocolName = luaL_checkstring(L, -1);
            NSString *trimProtolName = kkp_trim([NSString stringWithUTF8String:protocolName]);
            Protocol *protocol = objc_getProtocol(trimProtolName.UTF8String);
            if (!protocol) {
                NSString *error = [NSString stringWithFormat:@"Could not find protocol named '%@'\nHint: Sometimes the runtime cannot automatically find a protocol. Try adding it (via xCode) to the file ProtocolLoader.h", trimProtolName];
                KKP_ERROR(L, error);
            }
            class_addProtocol(instanceUserdata->instance, protocol);
            lua_pop(L, 1);
        }
        
        return 0;
    });
}

static int LF_kkp_class_recoverMethod(lua_State *L)
{
    // class
    const char* class_name = lua_tostring(L, 1);
    const char* selector_name = lua_tostring(L, 2);
    
    bool r =  kkp_class_recoverMethod(class_name, selector_name);
    if (r) {
        __block NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];
        [kkp_class_replacedClassMethods() enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString* klass = obj[@"class"];
            NSString* sel = obj[@"sel"];
            if (strcmp(klass.UTF8String, class_name) == 0
                && strcmp(sel.UTF8String, selector_name) == 0) {
                [indexes addIndex:idx];
                *stop = YES;
            }
        }];
        if (index > 0) {
            [kkp_class_replacedClassMethods() removeObjectsAtIndexes:indexes];
        }
    }
    
    return 0;
}

/// 定义一个 oc block，用于把 lua 函数转成一个 oc block 做的前置工作，主要是先保存 lua 函数的 返回和参数类型
/// arg1 是 lua 函数，arg2 是 返回类型，arg3 是参数类型(一个 lua table  数组，可选)
static int LF_kkp_class_define_block(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        if (!lua_isfunction(L, 1)) {
            NSString* error = @"Can not get lua function when define block";
            KKP_ERROR(L, error);
        }
        
        NSString *typeEncoding = @"void,void";
        const char* type_encoding = lua_tostring(L, 2);
        if (type_encoding) {
            typeEncoding = [NSString stringWithUTF8String:type_encoding];
        }
        
        NSString *realTypeEncoding = kkp_create_real_signature(typeEncoding, true);
        __unused __autoreleasing KKPBlockWrapper *block = [[KKPBlockWrapper alloc] initWithTypeEncoding:realTypeEncoding state:L funcIndex:1];
        return 1;
    });
}

/// 查找一个 OC 类，并创建 OC 类的 class user data
static int LM_kkp_class__index(lua_State *L)
{
    return LF_kkp_class_find_userData(L);
}

/// 创建一个新的 OC 类，并创建 OC 类的 class user data
/// 解释下 __call 元方法
/// __call: 函数调用操作 func(args)。 当 Lua 尝试调用一个非函数的值的时候会触发这个事件 （即 func 不是一个函数）。 查找 func 的元方法， 如果找得到，就调用这个元方法， func 作为第一个参数传入，原来调用的参数（args）后依次排在后面。
/// 比如 a = {}
/// meta_table = { __call = function(self, arg1, arg2, arg3...) print(self, arg1, arg2, arg3) end}
/// setmetatable(a, meta_table)
/// a("ViewController", "BaseViewController", protocols = {"UITableViewDelegate"})
/// 这里 arg1 是 a, arg2 是 "ViewController", arg3 是 "BaseViewController"， arg4 是 protocols = {"UITableViewDelegate"}，那么栈索引1是 arg1，栈索引2是 arg2，栈索引3是 arg3，栈索引4是 arg4
static int LM_kkp_class__call(lua_State *L)
{
    const char *className = luaL_checkstring(L, 2);
    Class klass = objc_getClass(className);
    
    if (!klass) {// 类不存在，就创建新 OC 类
        /// 获取父类
        Class superClass;
        if (lua_isnoneornil(L, 3)) {// 如果没有指定父类，就默认父类是 NSObject
            superClass = [NSObject class];
        } else {// 如果指定了父类
            const char *superClassName = luaL_checkstring(L, 3);
            superClass = objc_getClass(superClassName);
        }
        
        if (!superClass) {
            NSString* error = [NSString stringWithFormat:@"Failed to create '%s'. Unknown superclass \"%s\" received.", className, luaL_checkstring(L, 3)];
            KKP_ERROR(L, error.UTF8String);
        }
        
        /// 创建新类
        klass = objc_allocateClassPair(superClass, className, 0);
        objc_registerClassPair(klass);
    }
    
    return kkp_class_create_userdata(L, className);
}

static const struct luaL_Reg Methods[] = {
    {"findUserData", LF_kkp_class_find_userData},
    {"addProtocols", LF_kkp_class_add_protocols},
    {"recoverMethod", LF_kkp_class_recoverMethod},
    {"defineBlock", LF_kkp_class_define_block},
    {NULL, NULL}
};

static const struct luaL_Reg MetaMethods[] = {
    {"__index", LM_kkp_class__index},
    {"__call", LM_kkp_class__call},
    {NULL, NULL}
};

LUAMOD_API int luaopen_kkp_class(lua_State *L)
{
    [kkp_class_replacedClassMethods() enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString* klass = obj[@"class"];
        NSString* sel = obj[@"sel"];
        kkp_class_recoverMethod(klass.UTF8String, sel.UTF8String);
    }];
    [kkp_class_replacedClassMethods() removeAllObjects];
    
    /// 创建 class user data 元表，并添加元方法
    luaL_newmetatable(L, KKP_CLASS_USER_DATA_META_TABLE);// 新建元表用于存放元方法
    luaL_setfuncs(L, UserDataMetaMethods, 0); //给元表设置函数
    
    /// 新建元表用于存放所有 class user data
    luaL_newmetatable(L, KKP_CLASS_USER_DATA_LIST_TABLE);
    
    /// 新建 class 模块
    luaL_newlib(L, Methods);// 创建库函数
    
    /// 新建 class 模块元表
    luaL_newmetatable(L, KKP_CLASS_META_TABLE);
    luaL_setfuncs(L, MetaMethods, 0); //给元表设置函数
    lua_setmetatable(L, -2);
    
    return 1;
}
