//
//  kkp_converter.m
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import "kkp_converter.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <malloc/malloc.h>
#import "lauxlib.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_class.h"
#import "kkp_instance.h"
#import "KKPBlockWrapper.h"


/// 根据 Class 字符串拼接的方法签名, 构造真实方法签名
/// @param signatureStr 字符串参数类型 例'void,NSString*'
/// @param isBlock 是否构造block签名
NSString *kkp_create_real_signature(NSString *signatureStr, bool isBlock) {
    static NSMutableDictionary *typeSignatureDict;
    if (!typeSignatureDict) {
        typeSignatureDict =
            [NSMutableDictionary dictionaryWithObject:@[[NSString stringWithUTF8String:@encode(dispatch_block_t)], @(sizeof(dispatch_block_t))]
                                               forKey:@"?"];
#define KKP_DEFINE_TYPE_SIGNATURE(_type) \
    [typeSignatureDict setObject:@[[NSString stringWithUTF8String:@encode(_type)], @(sizeof(_type))] forKey:@ #_type];

        KKP_DEFINE_TYPE_SIGNATURE(id);
        KKP_DEFINE_TYPE_SIGNATURE(BOOL);
        KKP_DEFINE_TYPE_SIGNATURE(int);
        KKP_DEFINE_TYPE_SIGNATURE(void);
        KKP_DEFINE_TYPE_SIGNATURE(char);
        KKP_DEFINE_TYPE_SIGNATURE(short);
        KKP_DEFINE_TYPE_SIGNATURE(unsigned short);
        KKP_DEFINE_TYPE_SIGNATURE(unsigned int);
        KKP_DEFINE_TYPE_SIGNATURE(long);
        KKP_DEFINE_TYPE_SIGNATURE(unsigned long);
        KKP_DEFINE_TYPE_SIGNATURE(long long);
        KKP_DEFINE_TYPE_SIGNATURE(unsigned long long);
        KKP_DEFINE_TYPE_SIGNATURE(float);
        KKP_DEFINE_TYPE_SIGNATURE(double);
        KKP_DEFINE_TYPE_SIGNATURE(bool);
        KKP_DEFINE_TYPE_SIGNATURE(size_t);
        KKP_DEFINE_TYPE_SIGNATURE(CGFloat);
        KKP_DEFINE_TYPE_SIGNATURE(CGSize);
        KKP_DEFINE_TYPE_SIGNATURE(CGRect);
        KKP_DEFINE_TYPE_SIGNATURE(CGPoint);
        KKP_DEFINE_TYPE_SIGNATURE(CGVector);
        KKP_DEFINE_TYPE_SIGNATURE(NSRange);
        KKP_DEFINE_TYPE_SIGNATURE(NSInteger);
        KKP_DEFINE_TYPE_SIGNATURE(Class);
        KKP_DEFINE_TYPE_SIGNATURE(SEL);
        KKP_DEFINE_TYPE_SIGNATURE(void *);
        KKP_DEFINE_TYPE_SIGNATURE(NSString *);
        KKP_DEFINE_TYPE_SIGNATURE(NSNumber *);
    }
    NSArray *lt = [signatureStr componentsSeparatedByString:@","];
    /**
     * 这里注意下block与func签名要区分下,block中没有_cmd, 并且要用@?便是target
     */
    NSString *funcSignature = isBlock ? @"@?0" : @"@0:8";
    NSInteger size = isBlock ? sizeof(void *) : sizeof(void *) + sizeof(SEL);
    for (NSInteger i = 1; i < lt.count;) {
        // 去掉两边空格
        NSString *t = [lt[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *tpe = typeSignatureDict[typeSignatureDict[t] ? t : @"id"][0];
        if (i == 0) {
            if (!t || t.length == 0)
                funcSignature = [[NSString stringWithFormat:@"%@%@", tpe, [@(size) stringValue]] stringByAppendingString:funcSignature];
            else
                funcSignature = [[NSString stringWithFormat:@"%@%@", tpe, [@(size) stringValue]] stringByAppendingString:funcSignature];
            break;
        } else {
            funcSignature = [funcSignature stringByAppendingString:[NSString stringWithFormat:@"%@%@", tpe, [@(size) stringValue]]];
            size += [typeSignatureDict[typeSignatureDict[t] ? t : @"id"][1] integerValue];
        }
        i = (i == lt.count - 1) ? 0 : i + 1;
    }

    return funcSignature;
}

static void * toStruct(lua_State *L, const char * typeDescription, int index)
{
    NSArray* class2des = kkp_parseStructFromTypeDescription([NSString stringWithUTF8String:typeDescription]);
    if (class2des.count > 1) {
        NSString* className = class2des[0];
        className = [NSString stringWithFormat:@"KKP_%@", className];
        NSString* des = class2des[1];
        
        size_t item_count = strlen(des.UTF8String);
        // create a class
        Class klass = objc_allocateClassPair([NSObject class], [className UTF8String], 0);
        // already exist
        if (klass == nil) {
            klass = NSClassFromString(className);
        } else {
            BOOL success = YES;
            for (int i = 0; i < item_count; i++) {
                char type = des.UTF8String[i];
                NSUInteger size;
                NSUInteger alingment;
                NSGetSizeAndAlignment(&type, &size, &alingment);
                success = class_addIvar(klass, [NSString stringWithFormat:@"x%d", i].UTF8String, size, log2(alingment), &type);
                if (!success) {
                    break;
                }
            }
            if (!success) {
                objc_disposeClassPair(klass);
                KKP_ERROR(L, "toStruct function create class failed !");
                return NULL;
            }
            
            objc_registerClassPair(klass);
        }
        
        id __autoreleasing object = [[klass alloc] init];
        for (int i = 1; i <= item_count; i++) {
            lua_pushinteger(L, i);
            lua_gettable(L, index);
            [object setValue:@(lua_tonumber(L, -1)) forKey:[NSString stringWithFormat:@"x%d", i-1]];
            lua_pop(L, 1);
        }
        void* p = (__bridge void *)object;
        p = p + sizeof(void *);
        return p;
    }
    return NULL;
}

static int toLuaTableFromStruct(lua_State *L, const char * typeDescription, void *buffer)
{
    // create object
    NSArray* class2des = kkp_parseStructFromTypeDescription([NSString stringWithUTF8String:typeDescription]);
    if (class2des.count > 1) {
        NSString* className = class2des[0];
        className = [NSString stringWithFormat:@"KKP_%@", className];
        NSString* des = class2des[1];
        
        size_t item_count = strlen(des.UTF8String);
        // create a class
        Class klass = objc_allocateClassPair([NSObject class], [className UTF8String], 0);
        // already exist
        if (klass == nil) {
            klass = NSClassFromString(className);
        } else {
            BOOL success = YES;
            for (int i = 0; i < item_count; i++) {
                char type = des.UTF8String[i];
                NSUInteger size;
                NSUInteger alingment;
                NSGetSizeAndAlignment(&type, &size, &alingment);
                success = class_addIvar(klass, [NSString stringWithFormat:@"x%d", i].UTF8String, size, log2(alingment), &type);
                if (!success) {
                    break;
                }
            }
            if (!success) {
                objc_disposeClassPair(klass);
                KKP_ERROR(L, "toStruct function create class failed !");
                return 0;
            }
            
            objc_registerClassPair(klass);
        }
        
        id __autoreleasing object = [[klass alloc] init];
        void* p = (__bridge void *)object;
        p = p + sizeof(void *);
        memcpy(p, buffer, class_getInstanceSize(klass) - sizeof(void *));
        
        lua_newtable(L);
        for (int i = 1; i <= item_count; i++) {
            NSString* key = [NSString stringWithFormat:@"x%d", i-1];
            NSNumber* value = [object valueForKey:key];
            if ([value isKindOfClass:[NSNumber class]]) {
                lua_pushnumber(L, i);
                lua_pushnumber(L, value.doubleValue);
                lua_settable(L, -3);
            } else {
                KKP_ERROR(L, "struct type only support number type or ptr type");
            }
        }
    }
    return 1;
}

#define KKP_TO_NUMBER_CONVERT(T) else if (type[0] == @encode(T)[0]) { value = malloc(sizeof(T)); *((T *)value) = (T)lua_tonumber(L, index); }
void * kkp_toOCObject(lua_State *L, const char * typeDescription, int index)
{
    void *value = NULL;
    const char *type = kkp_removeProtocolEncodings(typeDescription);
    
    if (type[0] == _C_VOID) {
        *((int *)value) = 0;
    } else if (type[0] == _C_BOOL) {
        value = malloc(sizeof(BOOL));
        *((BOOL *)value) = (BOOL)( lua_isstring(L, index) ? lua_tostring(L, index)[0] : lua_toboolean(L, index));
    } else if (type[0] == _C_CHR) {
        value = malloc(sizeof(char));
        if (lua_type(L, index) == LUA_TNUMBER){//There should be corresponding with kkp_toLuaObjectWithBuffer, otherwise the incoming char by kkp_toLuaObjectWithBuffer into number, and then through the wax_copyToObjc into strings are truncated.（如'a'->97->'9'）
            *((char *)value) = (char)lua_tonumber(L, index);
        } else if(lua_type(L, index) == LUA_TSTRING){
            *((char *)value) = (char)lua_tostring(L, index)[0];
        } else{//32 bit BOOL is char
            *((char *)value) = (char)lua_toboolean(L, index);
        }
    }
    KKP_TO_NUMBER_CONVERT(int)
    KKP_TO_NUMBER_CONVERT(short)
    KKP_TO_NUMBER_CONVERT(long)
    KKP_TO_NUMBER_CONVERT(long long)
    KKP_TO_NUMBER_CONVERT(unsigned int)
    KKP_TO_NUMBER_CONVERT(unsigned short)
    KKP_TO_NUMBER_CONVERT(unsigned long)
    KKP_TO_NUMBER_CONVERT(unsigned long long)
    KKP_TO_NUMBER_CONVERT(float)
    KKP_TO_NUMBER_CONVERT(double)
    
    else if (type[0] == _C_CHARPTR) {
        const char *string = lua_tostring(L, index);
        value = malloc(sizeof(char *));
        memcpy(value, &string, sizeof(char*));
    } else if (type[0] == @encode(SEL)[0]) {
        if (lua_isnil(L, index)) { // If no slector is passed it, just use an empty string
            lua_pushstring(L, "");
            lua_replace(L, index);
        }
        
        value = malloc(sizeof(SEL));
        const char *selectorName = luaL_checkstring(L, index);
        *((SEL *)value) = sel_getUid(selectorName);
    } else if (type[0] == _C_CLASS) {
        value = malloc(sizeof(Class));
        if (lua_isuserdata(L, index)) {
            KKPInstanceUserdata *instanceUserdata = (KKPInstanceUserdata *)luaL_checkudata(L, index, KKP_CLASS_USER_DATA_META_TABLE);
            //https://www.jianshu.com/p/5fbe5478e24b
            *(__unsafe_unretained id *)value = instanceUserdata->instance;
        }
        else {
            *((Class *)value) = objc_getClass(lua_tostring(L, index));
        }
    } else if (type[0] == _C_ID) {
        value = malloc(sizeof(id));
        id instance = nil;
        
        switch (lua_type(L, index)) {
            case LUA_TNIL:
            case LUA_TNONE:
                instance = nil;
            case LUA_TBOOLEAN: {
                BOOL flag = lua_toboolean(L, index);
                instance = [NSValue valueWithBytes:&flag objCType:@encode(bool)];
                
                if (instance) {
                    __autoreleasing id temp = instance;
                    *(void **)value = (__bridge void *)temp;
                }
                break;
            }
            case LUA_TNUMBER:
                instance = [NSNumber numberWithDouble:lua_tonumber(L, index)];
                
                if (instance) {
                    __autoreleasing id temp = instance;
                    *(void **)value = (__bridge void *)temp;
                }
                break;
            case LUA_TSTRING:
            {
                instance = [NSString stringWithUTF8String:lua_tostring(L, index)];
                
                if (instance) {
                    // 对于创建的 OC 对象，如果不引用下，在返回的时候就会被释放掉了。所以这里用 __autoreleasing 修饰下，让他在下个循环释放
                    
                    __autoreleasing id temp = instance;
                    *(void **)value = (__bridge void *)temp;
                }
                break;
            }
            case LUA_TTABLE:
            {
                BOOL dictionary = NO;
                
                lua_pushvalue(L, index); // Push the table reference on the top
                lua_pushnil(L);  /* first key */
                while (!dictionary && lua_next(L, -2)) {
                    if (lua_type(L, -2) != LUA_TNUMBER) {
                        dictionary = YES;
                        lua_pop(L, 2); // pop key and value off the stack
                    } else {
                        lua_pop(L, 1);
                    }
                }
                
                if (dictionary) {
                    instance = [NSMutableDictionary dictionary];
                    
                    lua_pushnil(L);  /* first key */
                    while (lua_next(L, -2)) {
                        void *keyArg = kkp_toOCObject(L, "@", -2);
                        __unsafe_unretained id key;
                        key = (__bridge id)(*(void **)keyArg);
                        
                        void *valueArg = kkp_toOCObject(L, "@", -1);
                        __unsafe_unretained id object;
                        object = (__bridge id)(*(void **)valueArg);
                        
                        [instance setObject:object forKey:key];
                        lua_pop(L, 1); // Pop off the value
                        
                        if (keyArg != NULL) {
                            free(keyArg);
                        }
                        
                        if (valueArg != NULL) {
                            free(valueArg);
                        }
                    }
                } else {
                    instance = [NSMutableArray array];
                    
                    lua_pushnil(L);  /* first key */
                    while (lua_next(L, -2)) {
                        int index = lua_tonumber(L, -2) - 1;
                        
                        void *valueArg = kkp_toOCObject(L, "@", -1);
                        __unsafe_unretained id object;
                        object = (__bridge id)(*(void **)valueArg);
                        
                        [instance insertObject:object atIndex:index];
                        lua_pop(L, 1);
                        
                        if (valueArg != NULL) {
                            free(valueArg);
                        }
                    }
                }
                
                lua_pop(L, 1); // Pop the table reference off
                
                if (instance) {
                    __autoreleasing id temp = instance;
                    *(void **)value = (__bridge void *)temp;
                }
                break;
            }
            case LUA_TUSERDATA:
            {
                KKPInstanceUserdata *userdata = lua_touserdata(L, index);
                if (userdata && userdata->instance) {
                    if ([userdata->instance isKindOfClass:KKPBlockWrapper.class]) {
                        instance = (__bridge id)((KKPBlockWrapper *)userdata->instance).blockPtr;
                    } else {
                        instance = userdata->instance;
                    }
                } else {
                    instance = nil;
                }
                
                if (instance) {
                    // 不是创建的对象，没必要增加引用
                    __unsafe_unretained id temp = instance;
                    *(void **)value = (__bridge void *)temp;
                }
                break;
            }
            case LUA_TLIGHTUSERDATA: {
                instance = (__bridge id)lua_touserdata(L, -1);
                
                if (instance) {
                    __unsafe_unretained id temp = instance;
                    *(void **)value = (__bridge void *)temp;
                }
                break;
            }
            default:
            {
                free(value);
                NSString *error = [NSString stringWithFormat:@"Can't convert %s to obj-c.", luaL_typename(L, index)];
                KKP_ERROR(L, error.UTF8String);
                return NULL;
            }
        }
    } else if (type[0] == _C_STRUCT_B) {
        return toStruct(L, typeDescription, index);
    } else if (type[0] == _C_PTR) {
        value = malloc(sizeof(void *));
        void *pointer = nil;
        
        switch (typeDescription[1]) {
            case _C_VOID:
            case _C_ID: {
                switch (lua_type(L, index)) {
                    case LUA_TNIL:
                    case LUA_TNONE:
                        break;
                        
                    case LUA_TUSERDATA: {
                        KKPInstanceUserdata *instanceUserdata = (KKPInstanceUserdata *)luaL_checkudata(L, index, KKP_INSTANCE_USER_DATA_META_TABLE);
                        if (typeDescription[1] == _C_VOID) {
                            pointer = (__bridge void *)(instanceUserdata->instance);
                        } else {
                            pointer = &instanceUserdata->instance;
                        }

                        break;
                    }
                    case LUA_TLIGHTUSERDATA:
                        pointer = lua_touserdata(L, index);
                        break;
                    default:
                        luaL_error(L, "Can't convert %s to KKPInstanceUserdata.", luaL_typename(L, index));
                        break;
                }
                break;
            }
            default:
                if (lua_islightuserdata(L, index)) {
                    pointer = lua_touserdata(L, index);
                } else {
                    free(value);
                    luaL_error(L, "Converstion from %s to Objective-c not implemented.", typeDescription);
                }
        }
        
        if (pointer) {
            memcpy(value, &pointer, sizeof(void *));
        }
    } else {
        NSString* error = [NSString stringWithFormat:@"type %s in not support !", typeDescription];
        KKP_ERROR(L, error.UTF8String);
        return NULL;
    }
    return value;
}

int kkp_toLuaObject(lua_State *L, id object)
{
    return kkp_safeInLuaStack(L, ^int{
        if ([object isKindOfClass:[NSString class]]) {
            lua_pushstring(L, [object UTF8String]);
        } else if ([object isKindOfClass:[NSNumber class]]) {
            lua_pushnumber(L, [object doubleValue]);
        } else if ([object isKindOfClass:[NSArray class]]) {
            lua_newtable(L);
            for (NSInteger i = 0; i < [object count]; i++) {
                lua_pushnumber(L, i+1);
                kkp_toLuaObject(L, object[i]);
                lua_settable(L, -3);
            }
        } else if ([object isKindOfClass:[NSDictionary class]]) {
            lua_newtable(L);
            [object enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                kkp_toLuaObject(L, key);
                kkp_toLuaObject(L, obj);
                lua_settable(L, -3);
            }];
        } else {
            kkp_instance_create_userdata(L, object);
        }
        return 1;
    });
}

#define NUMBER_TO_KKP_CONVERT(T) else if (type[0] == @encode(T)[0]) { lua_pushnumber(L, *(T *)buffer); }
int kkp_toLuaObjectWithBuffer(lua_State *L, const char * typeDescription, void *buffer)
{
    // buffer 是指针的指针
    return kkp_safeInLuaStack(L, ^int{
        const char * type = kkp_removeProtocolEncodings(typeDescription);
        
        // http://developer.apple.com/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
        if (type[0] == _C_VOID) {// 没有返回值
            lua_pushnil(L);
        } else if (type[0] == _C_PTR) {// 返回值是 指针 类型
            lua_pushlightuserdata(L, *(void **)buffer);
        }
        
        NUMBER_TO_KKP_CONVERT(char)
        NUMBER_TO_KKP_CONVERT(unsigned char)
        NUMBER_TO_KKP_CONVERT(int)
        NUMBER_TO_KKP_CONVERT(short)
        NUMBER_TO_KKP_CONVERT(long)
        NUMBER_TO_KKP_CONVERT(long long)
        NUMBER_TO_KKP_CONVERT(unsigned int)
        NUMBER_TO_KKP_CONVERT(unsigned short)
        NUMBER_TO_KKP_CONVERT(unsigned long)
        NUMBER_TO_KKP_CONVERT(unsigned long long)
        NUMBER_TO_KKP_CONVERT(float)
        NUMBER_TO_KKP_CONVERT(double)
        
        else if (type[0] == _C_BOOL) {// 返回值是 布尔 类型
            lua_pushboolean(L, *(bool *)buffer);
        } else if (type[0] == _C_CHARPTR) {// 返回值是 字符串 类型
            lua_pushstring(L, *(char **)buffer);
        } else if (type[0] == _C_SEL) {// 返回值是 选择器 类型
            lua_pushstring(L, sel_getName(*(SEL *)buffer));
        } else if (type[0] == _C_ID) {// 返回值是 OC 对象 类型
            /**
             A bridged cast is a C-style cast annotated with one of three keywords:

             (__bridge T) op casts the operand to the destination type T. If T is a retainable object pointer type, then op must have a non-retainable pointer type. If T is a non-retainable pointer type, then op must have a retainable object pointer type. Otherwise the cast is ill-formed. There is no transfer of ownership, and ARC inserts no retain operations.
             (__bridge_retained T) op casts the operand, which must have retainable object pointer type, to the destination type, which must be a non-retainable pointer type. ARC retains the value, subject to the usual optimizations on local values, and the recipient is responsible for balancing that +1.
             (__bridge_transfer T) op casts the operand, which must have non-retainable pointer type, to the destination type, which must be a retainable object pointer type. ARC will release the value at the end of the enclosing full-expression, subject to the usual optimizations on local values.
             
             __bridge 转换Objective-C 和 Core Foundation 指针，不移交持有权.
             __bridge_retained 或 CFBridgingRetain 转换 Objective-C 指针到Core Foundation 指针并移交持有权.
             你要负责调用 CFRelease 或一个相关的函数来释放对象.
             __bridge_transfer 或 CFBridgingRelease 传递一个非Objective-C 指针到 Objective-C 指针并移交持有权给ARC. ARC负责释放对象.
             
             */

            // id instance = *((__unsafe_unretained id *)buffer); 这种写法也可以
            __unsafe_unretained id instance;
            instance = (__bridge id)(*(void **)buffer);
            
            kkp_toLuaObject(L, instance);
        } else if (type[0] == _C_CLASS) {// 返回值是 class 类型
            __unsafe_unretained id instance;
            instance = (__bridge id)(*(void **)buffer);
            
            kkp_class_create_userdata(L, NSStringFromClass(instance).UTF8String);
        } else if (type[0] == _C_STRUCT_B) {// 返回值是 结构体 类型
            toLuaTableFromStruct(L, typeDescription, buffer);
        }
        else {
            NSString* error = [NSString stringWithFormat:@"Unable to convert Obj-C type with type description '%s'", typeDescription];
            KKP_ERROR(L, error.UTF8String);
            return 0;
        }
        
        return 1;
    });
}
