//
//  kkp_helper.m
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import "kkp_helper.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import "lauxlib.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_instance.h"
#import "kkp_converter.h"
#import "KKPBlockDescription.h"

#define KKP_BEGIN_STACK_MODIFY(L) int __startStackIndex = lua_gettop((L));
#define KKP_END_STACK_MODIFY(L, i) while(lua_gettop((L)) > (__startStackIndex + (i))) lua_remove((L), __startStackIndex + 1);

int kkp_safeInLuaStack(lua_State *L, kkp_lua_stack_safe_block_t block)
{
    return kkp_performLocked(^int{
        int result = 0;
        KKP_BEGIN_STACK_MODIFY(L)
        if (block) {
            result = block();
        }
        KKP_END_STACK_MODIFY(L, result)
        return result;
    });
}

static NSRecursiveLock *lock = nil;

int kkp_performLocked(kkp_lua_lock_safe_block_t block) {
    int result = 0;
    
    if (lock == nil) {
        lock = [[NSRecursiveLock alloc] init];
    }
    [lock lock];
    result = block();
    [lock unlock];
    return result;
}

void traverse_table(lua_State *L, int index)
{
    lua_pushnil(L);
    while (lua_next(L, index)) {
        lua_pushvalue(L, -2);
        const char* key = lua_tostring(L, -1);
        int type = lua_type(L, -2);
        printf("%s => type %s", key, lua_typename(L, type));
        switch (type) {
            case LUA_TNUMBER:
                printf(" value=%f", lua_tonumber(L, -2));
                break;
            case LUA_TSTRING:
                printf(" value=%s", lua_tostring(L, -2));
                break;
            case LUA_TFUNCTION:
                if (lua_iscfunction(L, -2)) {
                    printf(" C:%p", lua_tocfunction(L, -2));
                }
        }
        printf("\n");
        lua_pop(L, 2);
    }
}

void kkp_stackDump(lua_State *L) {
    printf("------------ kkp_stackDump begin ------------\n");
    int top = lua_gettop(L);
    for (int i = 0; i < top; i++) {
        int positive = top - i;
        int negative = -(i + 1);
        int type = lua_type(L, positive);
        int typeN = lua_type(L, negative);
        assert(type == typeN);
        const char* typeName = lua_typename(L, type);
        printf("%d/%d: type=%s", positive, negative, typeName);
        switch (type) {
            case LUA_TNUMBER:
                printf(" value=%f", lua_tonumber(L, positive));
                break;
            case LUA_TSTRING:
                printf(" value=%s", lua_tostring(L, positive));
                break;
            case LUA_TFUNCTION:
                if (lua_iscfunction(L, positive)) {
                    printf(" C:%p", lua_tocfunction(L, positive));
                }
            case LUA_TUSERDATA:
                if (lua_isuserdata(L, positive)) {
                    printf(" C:%p", lua_touserdata(L, positive));
                }
            case LUA_TTABLE:
                if (lua_istable(L, positive)) {
                    printf("\nvalue=\n{\n");
                    traverse_table(L, positive);
                    printf("}\n");
                }
                break;
        }
        printf("\n");
    }
    printf("------------ kkp_stackDump end ------------\n\n");
}

/// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
char kkp_removeProtocolEncodings(const char *typeDescription)
{
    char type = typeDescription[0];
    switch (type) {
        case KKP_PROTOCOL_TYPE_CONST:
        case KKP_PROTOCOL_TYPE_INOUT:
        case KKP_PROTOCOL_TYPE_OUT:
        case KKP_PROTOCOL_TYPE_BYCOPY:
        case KKP_PROTOCOL_TYPE_BYREF:
        case KKP_PROTOCOL_TYPE_ONEWAY:
            type = typeDescription[1];
            break;
    }
    if (type == _C_PTR) {
        type = @encode(long)[0];
    } else if (type == 'l') {
        #if __LP64__
        type = 'q';
        #endif
    } else if (type == 'g') {
        if (sizeof(CGFloat) == sizeof(double)) {
            type = 'd';
        } else {
            type = 'f';
        }
    }
    return type;
}

/// lua 函数名转成 oc 函数名时规则
/// 一个 _ 下划线转换成 :
/// 两个 __ 下划线转换成一个 _ 下划线
const char* kkp_toObjcSel(const char *luaFuncName)
{
    NSString* __autoreleasing s = [NSString stringWithFormat:@"%s", luaFuncName];
    s = [s stringByReplacingOccurrencesOfString:@"__" withString:@"!"];
    s = [s stringByReplacingOccurrencesOfString:@"_" withString:@":"];
    s = [s stringByReplacingOccurrencesOfString:@"!" withString:@"_"];
    return s.UTF8String;
}

char* kkp_toObjcPropertySel(const char *prop)
{
    if (!prop) {
        return NULL;
    }
    size_t len = strlen(prop) + 3 + 2;
    char* func = malloc(len);
    memset(func, 0, len);
    
    char c = prop[0];
    if(c >= 'a' && c <= 'z') {
        c = c - 32;
    }
    
    strcpy(func, "set");
    memset(func+3, c, 1);
    strcpy(func+4, prop+1);
    strcat(func, ":");
    return func;
}

const char* kkp_toLuaFuncName(const char *objcSel)
{
    NSString* __autoreleasing s = [NSString stringWithFormat:@"%s", objcSel];
    s = [s stringByReplacingOccurrencesOfString:@"_" withString:@"__"];
    s = [s stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    return s.UTF8String;
}

bool kkp_isBlock(id object)
{
    Class klass = object_getClass(object);
    if (klass == NSClassFromString(@"__NSGlobalBlock__")
        || klass == NSClassFromString(@"__NSStackBlock__")
        || klass == NSClassFromString(@"__NSMallocBlock__")) {
        return true;
    }
    return false;
}

bool kkp_isAllocMethod(const char *methodName) {
    if (strncmp(methodName, "alloc", 5) == 0) {
        if (methodName[5] == '\0') return true; // It's just an alloc
        if (isupper(methodName[5]) || isdigit(methodName[5])) return YES; // It's alloc[A-Z0-9]
    }
    
    return false;
}

int kkp_callBlock(lua_State *L)
{
    KKPInstanceUserdata* instance = lua_touserdata(L, 1);
    id block = instance->instance;
    KKPBlockDescription* blockDescription = [[KKPBlockDescription alloc] initWithBlock:block];
    NSMethodSignature *signature = blockDescription.blockSignature;
    
    int nresults = [signature methodReturnLength] ? 1 : 0;
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:block];
    
    for (unsigned long i = [signature numberOfArguments] - 1; i >= 1; i--) {
        const char *typeDescription = [signature getArgumentTypeAtIndex:i];
        void *pReturnValue = kkp_toOCObject(L, typeDescription, -1);
        lua_pop(L, 1);
        [invocation setArgument:pReturnValue atIndex:i];
    }
    
    [invocation invoke];
    
    if (nresults > 0) {
        const char *typeDescription = [signature methodReturnType];
        NSUInteger size = 0;
        NSGetSizeAndAlignment(typeDescription, &size, NULL);
        void *buffer = malloc(size);
        [invocation getReturnValue:buffer];
        kkp_toLuaObjectWithBuffer(L, typeDescription, buffer);
        free(buffer);
    }
    
    return nresults;
}

static NSMutableDictionary *_propKeys;
static const void *kkp_propKey(NSString *propName) {
    if (!_propKeys) _propKeys = [[NSMutableDictionary alloc] init];
    id key = _propKeys[propName];
    if (!key) {
        key = [propName copy];
        [_propKeys setObject:key forKey:propName];
    }
    return (__bridge const void *)(key);
}

static const bool kkp_propKeyExists(NSString *propName) {
    return [_propKeys.allKeys containsObject:propName];
}

/// lua 层调用 c 层
/// 比如调用是这样的： self:view()，在 lua 语法糖中，self:view() == self.view(self)
/// 所以 第一个参数是 self（userdata，如果是调用实例方法就是 实例 user data，如果是调用类方法就是 class userdata），索引是 1，后面的索引全部都是参数了
/// 而第一个 upvalue 则是之前捕获的 view 字符串
int kkp_invoke_closure(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        KKPInstanceUserdata *instance = lua_touserdata(L, 1);
        if (instance && instance->instance) {
            Class klass = object_getClass(instance->instance);
            const char* func = lua_tostring(L, lua_upvalueindex(1));
            
            NSString *selectorName;
            selectorName = [NSString stringWithFormat:@"%s", kkp_toObjcSel(func)];
            // May be you call class function user static prefix, need to be remove
            selectorName = [selectorName stringByReplacingOccurrencesOfString:KKP_STATIC_PREFIX withString:@""];
            
            if (instance->isCallSuper) {// 如果是调用父类方法，就需要为当前类添加一个父类方法实现
                instance->isCallSuper = false;// 还原 super 到 false
                NSString *superSelectorName = [NSString stringWithFormat:@"%@%@", KKP_SUPER_PREFIX, selectorName];
                SEL superSelector = NSSelectorFromString(superSelectorName);
                Class klass = object_getClass(instance->instance);
                Class superClass = class_getSuperclass(klass);
                // 获取父类的方法实现
                Method superMethod = class_getInstanceMethod(superClass, NSSelectorFromString(selectorName));
                IMP superMethodImp = method_getImplementation(superMethod);
                char *typeDescription = (char *)method_getTypeEncoding(superMethod);
                // 如果是调用父类方法，就为当前类添加一个父类的实现
                class_addMethod(klass, superSelector, superMethodImp, typeDescription);
                selectorName = superSelectorName;
            } else if (instance->isCallOrigin) {// 如果是调用原始方法，就重新拼接原始方法前缀
                instance->isCallOrigin = false;// 还原 origin 到 false
                NSString *originSelectorName = [NSString stringWithFormat:@"%@%@", KKP_ORIGIN_PREFIX, selectorName];
                selectorName = originSelectorName;
            }
            
            SEL sel = NSSelectorFromString(selectorName);
            NSMethodSignature *signature = [klass instanceMethodSignatureForSelector:sel];
            if (signature) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                invocation.target = instance->instance;
                invocation.selector = sel;
                
                // args
                int nresults = [signature methodReturnLength] ? 1 : 0;
                for (int i = 2; i < [signature numberOfArguments]; i++) {
                    const char* typeDescription = [signature getArgumentTypeAtIndex:i];
                    void *argValue = kkp_toOCObject(L, typeDescription, i);
                    if (argValue == NULL) {
                        id object = nil;
                        [invocation setArgument:&object atIndex:i];
                    } else {
                        [invocation setArgument:argValue atIndex:i];
                    }
                }
                [invocation invoke];
                
                if (nresults > 0) {
                    const char *typeDescription = [signature methodReturnType];
                    NSUInteger size = 0;
                    NSGetSizeAndAlignment(typeDescription, &size, NULL);
                    void *buffer = malloc(size);
                    [invocation getReturnValue:buffer];
                    kkp_toLuaObjectWithBuffer(L, typeDescription, buffer);
                    free(buffer);
                }
                return nresults;
            } else {// 说明要调用的方法不存在
                if (!instance->isClass && instance->instance) {// 如果是实例的话，尝试把添加值到关联属性里
                    /// 计算参数个数，通过偏离 : 符号来确定个数
                    int argCount = 0;
                    const char *match = selectorName.UTF8String;
                    while ((match = strchr(match, ':'))) {
                        match += 1; // Skip past the matched char
                        argCount++;
                    }
                    
                    NSString *propName = selectorName;
                    if (argCount == 1 && [selectorName hasPrefix:@"set"]) {// 说明调用的是设置属性
                        void *argValue = kkp_toOCObject(L, "@", 2);
                        id value = *(__unsafe_unretained id *)argValue;
                        propName = [propName stringByReplacingOccurrencesOfString:@"set" withString:@""];
                        propName = [propName stringByReplacingOccurrencesOfString:@":" withString:@""];
                        propName = [propName lowercaseString];
                        objc_setAssociatedObject(instance->instance, kkp_propKey(propName), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        return 0;
                    } else if (argCount == 0 && kkp_propKeyExists(propName)) {// 说明调用的是获取属性，属性 key 一定要存在，只有先调用 set 属性方法，才会存在 key
                        id value = objc_getAssociatedObject(instance->instance, kkp_propKey(propName));
                        return kkp_toLuaObject(L, value);
                    }
                }
                
                NSString* error = [NSString stringWithFormat:@"selector %s not be found in %@. You may need to use ‘_’ to indicate that there are parameters. If your selector is 'function:', use 'function_', if your selector is 'function:a:b:', use 'function_a_b_'", func, klass];
                KKP_ERROR(L, error.UTF8String);
                return 0;
            }
        }
        return 0;
    });
}

NSArray* kkp_parseStructFromTypeDescription(NSString *typeDes)
{
    if (typeDes.length == 0) {
        return nil;
    }
    
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^\\{([A-Za-z0-9_]+)=" options:NSRegularExpressionCaseInsensitive error:&error];
    assert(error == nil);
    NSTextCheckingResult *match = [regex firstMatchInString:typeDes options:0 range:NSMakeRange(0, typeDes.length)];
    NSString* klass = match.numberOfRanges > 0?[typeDes substringWithRange:[match rangeAtIndex:1]]:nil;
    error = nil;
    regex = [NSRegularExpression regularExpressionWithPattern:@"=([a-z]+)\\}" options:NSRegularExpressionCaseInsensitive error:&error];
    assert(error == nil);
    NSMutableString* des = [NSMutableString string];
    NSArray *matches = [regex matchesInString:typeDes options:0 range:NSMakeRange(0, typeDes.length)];
    for (NSTextCheckingResult *match in matches) {
        NSRange range = [match rangeAtIndex:1];
        [des appendString:[typeDes substringWithRange:range]];
    }
    
    // fix CGFloat
    NSMutableString* rdes = [NSMutableString string];
    for (int i = 0; i < des.length; i++) {
        char c = [des characterAtIndex:i];
        if (c == 'g') {
            if (sizeof(CGFloat) == sizeof(double)) {
                c = 'd';
            } else {
                c = 'f';
            }
        }
        [rdes appendString:[NSString stringWithFormat:@"%c", c]];
    }
    
    if (klass.length > 0 && rdes.length > 0) {
        return @[klass, rdes];
    } else {
        return nil;
    }
}
