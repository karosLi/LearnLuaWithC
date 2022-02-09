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

static int kkp_class_callLuaFunction(lua_State *L, id self, SEL selector, NSInvocation *invocation);
static void __KKP_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation);

static NSMutableArray * kkp_class_replacedClassMethods() {
    static NSMutableArray *class2method = nil;
    if (class2method == nil) {
        class2method = [NSMutableArray array];
    }
    return class2method;
}

static void kkp_class_replaceMethod(Class klass, SEL sel)
{
    if (klass == nil || sel == nil) {
        return ;
    }
    
    Method targetMethod = class_getInstanceMethod(klass, sel);
    if (targetMethod) {
        // 给类添加一个原始方法，方便被 hook 的方法内部调用原始的方法
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL originSelector = kkp_runtime_originForSelector(sel);
        class_addMethod(klass, originSelector, method_getImplementation(targetMethod), typeEncoding);
        // 给类添加自定义的 forwardInvocation 方法实现，并替换掉旧的 forwardInvocation 方法
        kkp_runtime_swizzleForwardInvocation(klass, (IMP)__KKP_ARE_BEING_CALLED__);
        
        // 把要 hook 的方法实现，直接替换成 _objc_msgForward，意味着 hook 的方法在调用时，直接走消息转发流程，不用经过 method list 查找流程
        class_replaceMethod(klass, sel, kkp_runtime_getMsgForwardIMP(klass, sel), typeEncoding);
        
        // 把已经替换的方法记录下
        [kkp_class_replacedClassMethods() addObject:@{@"class":NSStringFromClass(klass), @"sel":NSStringFromSelector(sel)}];
    }
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


static void __KKP_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation)
{
    lua_State* L = kkp_currentLuaState();
    kkp_safeInLuaStack(L, ^int{
        if (kkp_runtime_isReplaceByKKP(object_getClass(self), invocation.selector)) {// selector 是否已经被替换了
            int nresults = kkp_class_callLuaFunction(L, self, invocation.selector, invocation);
            if (nresults > 0) {
                NSMethodSignature *signature = [self methodSignatureForSelector:invocation.selector];
                void *pReturnValue = kkp_toOCObject(L, [signature methodReturnType], -1);
                if (pReturnValue != NULL) {
                    [invocation setReturnValue:pReturnValue];
                }
            }
        } else {
            SEL origin_selector = NSSelectorFromString(KKP_ORIGIN_FORWARD_INVOCATION_SELECTOR_NAME);
            ((void(*)(id, SEL, id))objc_msgSend)(self, origin_selector, invocation);
        }
        return 0;
    });
}

#pragma mark - 帮助方法
static int kkp_class_create_userdata(lua_State *L, const char *klass_name)
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

/// 通过 hook oc 的 实例方法和类方法来调用 lua 函数
static int kkp_class_callLuaFunction(lua_State *L, id self, SEL selector, NSInvocation *invocation)
{
    return kkp_safeInLuaStack(L, ^int{
        NSMethodSignature *signature = [self methodSignatureForSelector:selector];
        int nargs = (int)[signature numberOfArguments] - 2;// 减 2 的目的，减去 self 和 _cmd 这个参数，因为 self 会作为环境 _ENV 的环境变量而存在，而 _cmd 也是不需要的
        int nresults = [signature methodReturnLength] ? 1 : 0;
        // 获取 class list table 并压栈
        luaL_getmetatable(L, KKP_CLASS_USER_DATA_LIST_TABLE);
        // in case self KVO ,object_getClassName(self) get wrong class
        // 从 class list table 获取指定名称的 userdata
        lua_getfield(L, -1, [NSStringFromClass([self class]) UTF8String]);
        // 获取 class userdata 的关联表，并压栈
        lua_getuservalue(L, -1);
        
        // 获取关联表上 selector 对应的 lua 函数，并压栈
        if ([self class] == self) {// 说明是类方法调用
            /// 类方法调用不需要设置什么，因为在定义时，已经设置了 class 关键字了
            NSString* staticSelectorName = [NSString stringWithFormat:@"%@%s", KKP_STATIC_PREFIX, sel_getName(selector)];
            lua_getfield(L, -1, kkp_toLuaFuncName(staticSelectorName.UTF8String));
            
            if (lua_isnil(L, -1)) {
                lua_pop(L, 1);
                lua_getfield(L, -1, kkp_toLuaFuncName(sel_getName(selector)));
            }
        } else {// 说明是实例方法调用
            /// 实例方法调用时，需要设置 self 关键字
            
            // 压入key
            lua_pushstring(L, [KKP_ENV_SCOPE UTF8String]);
            // 获取环境值压栈 associated_table["_scope"]
            lua_rawget(L, -2);
            
            // 压入 key
            lua_pushstring(L, [KKP_ENV_SCOPE_SELF UTF8String]);
            // 创建一个 oc 对象对应的 实例 userdata，并压栈，目的是把 实例 userdata 作为 lua 函数的第一个参数，也就是 self
            kkp_instance_create_userdata(L, self);
            // 给环境设置 _scope[self] = 实例 user data
            lua_rawset(L, -3);
            
            // 恢复栈
            lua_pop(L, 1);
            
            // 压入 lua 函数
            lua_getfield(L, -1, kkp_toLuaFuncName(sel_getName(selector)));
        }
        
        if (lua_isnil(L, -1)) {
            NSString* error = [NSString stringWithFormat:@"%s lua function get failed", sel_getName(selector)];
            KKP_ERROR(L, error);
        }
        
        // 如果有参数，就把参数转成 lua 对象，并压栈
        for (NSUInteger i = 2; i < [signature numberOfArguments]; i++) { // start at 2 because to skip the automatic self and _cmd arugments
            const char *typeDescription = [signature getArgumentTypeAtIndex:i];
            char type = kkp_getTypeFromTypeDescription(typeDescription);
            if (type == @encode(id)[0] || type == @encode(Class)[0]) {
                id __autoreleasing object;
                [invocation getArgument:&object atIndex:i];
                kkp_toLuaObject(L, object);
            } else {
                NSUInteger size = 0;
                NSGetSizeAndAlignment(typeDescription, &size, NULL);
                void *buffer = malloc(size);
                [invocation getArgument:buffer atIndex:i];
                kkp_toLuaObjectWithType(L, typeDescription, buffer);
                free(buffer);
            }
        }
        
        // 栈上有了 lua 函数，self 参数，和其他参数后，就可以调用 lua 函数了
        if(lua_pcall(L, nargs, nresults, 0) != 0){
            NSString* log = [NSString stringWithFormat:@"[KKP] PANIC: unprotected error in call to Lua API (%s)\n", lua_tostring(L, -1)];
            NSLog(@"%@", log);
            if (kkp_getSwizzleCallback()) {
                kkp_getSwizzleCallback()(NO, log);
            }
            NSCAssert(NO, log);
        }
        return nresults;
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
    
    // 获取 class
    Class klass = object_getClass(userdata->instance);
    if ([klass instancesRespondToSelector:NSSelectorFromString([NSString stringWithFormat:@"%s", kkp_toObjcSel(func)])]) {
        lua_pushcclosure(L, kkp_invoke, 1);
        return 1;
    }
    return 0;
}

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
            // 把环境值保存到关联表里，相当于 associated_table["_scope"] = scope
            lua_rawset(L, -3);
        } else if (lua_type(L, 3) == LUA_TFUNCTION) {// 只能 hook 函数
            KKPInstanceUserdata *userdata = lua_touserdata(L, 1);
            if (userdata) {
                const char* func = lua_tostring(L, 2);
                Class klass = userdata->instance;
                Class metaClass = object_getClass(klass);
                BOOL canBeReplace = NO;
                NSString* selectorName = [NSString stringWithFormat:@"%s", kkp_toObjcSel(func)];
                SEL sel = NSSelectorFromString(selectorName);
                if ([selectorName hasPrefix:KKP_STATIC_PREFIX]) {// lua 脚本里如果方法名是以 STATIC 为前缀，说明一个静态方法，此时就需要找到 OC 里的元类
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
                    kkp_class_replaceMethod(klass, sel);
                    
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
                } else {
                    NSString* error = [NSString stringWithFormat:@"selector %s not be found in %@. You may need to use ‘_’ to indicate that there are parameters. If your selector is 'function:', use 'function_', if your selector is 'function:a:b:', use 'function_a_b_'", func, klass];
                    KKP_ERROR(L, error.UTF8String);
                }
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

/// 查找一个 OC 类，并创建 OC 类的 class user data
static int LM_kkp_class__index(lua_State *L)
{
    return LF_kkp_class_find_userData(L);
}

/// 创建一个新的 OC 类，并创建 OC 类的 class user data
/// 解释下 __call 元方法
/// __call: 函数调用操作 func(args)。 当 Lua 尝试调用一个非函数的值的时候会触发这个事件 （即 func 不是一个函数）。 查找 func 的元方法， 如果找得到，就调用这个元方法， func 作为第一个参数传入，原来调用的参数（args）后依次排在后面。
/// 比如 a = {}
/// meta_table = { __call = function(self, arg1, arg2, arg3...) print(self, arg1, arg2) end}
/// setmetatable(a, meta_table)
/// a("hello", {key: "world"})
/// 这里的 self 就是 a, arg1 是 hello"， arg2 是 {key: "world"}，那么栈索引1是 self，栈索引2是 arg1，栈索引3是 arg2
static int LM_kkp_class__call(lua_State *L)
{
    
    return 0;
}

static const struct luaL_Reg Methods[] = {
    {"findUserData", LF_kkp_class_find_userData},
    {"recoverMethod", LF_kkp_class_recoverMethod},
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
