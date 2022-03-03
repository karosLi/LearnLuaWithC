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
#import "kkp.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_class.h"
#import "kkp_instance.h"
#import "kkp_struct.h"
#import "KKPBlockWrapper.h"

#if CGFLOAT_IS_DOUBLE
#define CGFloatValue doubleValue
#else
#define CGFloatValue floatValue
#endif


/// 根据 Class 字符串拼接的方法签名, 构造真实方法签名
/// @param signatureStr 字符串参数类型 例'void,NSString*'
/// @param isBlock 是否构造block签名
NSString *kkp_create_real_method_signature(NSString *signatureStr, bool isBlock) {
    static NSMutableDictionary *typeSignatureDict;
    if (!typeSignatureDict) {
        //        https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100
        typeSignatureDict =
            [NSMutableDictionary dictionaryWithObject:@[[NSString stringWithUTF8String:@encode(dispatch_block_t)], @(sizeof(dispatch_block_t))]
                                               forKey:@"?"];
#define KKP_DEFINE_TYPE_SIGNATURE(_type) \
    [typeSignatureDict setObject:@[[NSString stringWithUTF8String:@encode(_type)], @(sizeof(_type))] forKey:kkp_removeAllWhiteSpace(@ #_type)];

        KKP_DEFINE_TYPE_SIGNATURE(id);
        KKP_DEFINE_TYPE_SIGNATURE(BOOL);
        KKP_DEFINE_TYPE_SIGNATURE(int);
        KKP_DEFINE_TYPE_SIGNATURE(void);
        KKP_DEFINE_TYPE_SIGNATURE(char);
        KKP_DEFINE_TYPE_SIGNATURE(char *);
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
     * 比如 block 签名：i12@?0i8
     * 比如 非 block 签名 i16@0:8i12
     */
    NSMutableString *funcSignature = [[NSMutableString alloc] initWithString:isBlock ? @"@?0" : @"@0:8"];
    NSInteger size = isBlock ? sizeof(void *) : sizeof(void *) + sizeof(SEL);
    
    /// 先处理参数类型
    for (NSInteger i = 1; i < lt.count; i++) {
        // 去掉两边空格
        NSString *inputType = kkp_removeAllWhiteSpace(lt[i]);
        NSArray *typeWithSize = typeSignatureDict[typeSignatureDict[inputType] ? inputType : @"id"];
        NSString *outputType = typeWithSize[0];
        NSInteger outputSize = [typeWithSize[1] integerValue];
        
        if (!isBlock && [outputType isEqualToString:[NSString stringWithUTF8String:@encode(void)]]) {// 如果是方法，遇到 void 就跳过
            continue;
        }
        
        [funcSignature appendFormat:@"%@%zd", outputType, size];
        size += outputSize;
    }
    
    /// 最后处理返回类型
    NSString *inputType = [lt[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *typeWithSize = typeSignatureDict[typeSignatureDict[inputType] ? inputType : @"id"];
    NSString *outputType = typeWithSize[0];
    [funcSignature insertString:[NSString stringWithFormat:@"%@%zd", outputType, size] atIndex:0];

    return funcSignature;
}

/// 根据 Class 字符串拼接的参数签名, 构造真实参数签名。目前用于构造结构体的真实参数签名
/// @param signatureStr 字符串参数类型 例'CGFloat,CGFloat'
NSString *kkp_create_real_argument_signature(NSString *signatureStr) {
    static NSMutableDictionary *typeSignatureDict;
    if (!typeSignatureDict) {
        //    https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100
        typeSignatureDict =
            [NSMutableDictionary dictionary];
#define KKP_DEFINE_ARG_TYPE_SIGNATURE(_type) \
    [typeSignatureDict setObject:[NSString stringWithUTF8String:@encode(_type)] forKey:kkp_removeAllWhiteSpace(@ #_type)];

        KKP_DEFINE_ARG_TYPE_SIGNATURE(id);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(BOOL);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(int);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(void);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(char);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(char *);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(short);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(unsigned short);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(unsigned int);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(long);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(unsigned long);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(long long);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(unsigned long long);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(float);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(double);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(bool);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(size_t);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(CGFloat);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(CGSize);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(CGRect);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(CGPoint);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(CGVector);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(NSRange);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(NSInteger);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(Class);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(SEL);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(void *);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(NSString *);
        KKP_DEFINE_ARG_TYPE_SIGNATURE(NSNumber *);
    }
    NSArray *lt = [signatureStr componentsSeparatedByString:@","];
    
    NSMutableString *funcSignature = [NSMutableString new];
    for (NSInteger i = 0; i < lt.count; i++) {
        // 去掉两边空格
        NSString *t = kkp_removeAllWhiteSpace(lt[i]);
        NSString *tpe = typeSignatureDict[typeSignatureDict[t] ? t : @"id"];
        [funcSignature appendString:tpe];
    }

    return funcSignature;
}

/// 根据原生结构体的类型签名转成数组 [结构体名字，真实签名]
/// 比如："{CGSize=dd}" 转成 ["CGSize","dd"]
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
    
    NSMutableString* rdes = [NSMutableString string];
    for (int i = 0; i < des.length; i++) {
        char c = [des characterAtIndex:i];
        [rdes appendString:[NSString stringWithFormat:@"%c", c]];
    }
    
    if (klass.length > 0 && rdes.length > 0) {
        return @[klass, rdes];
    } else {
        return nil;
    }
}

/// 把原生结构体转成 struct user data
int kkp_createStructUserDataWithBuffer(lua_State *L, const char * typeDescription, void *buffer)
{
    // create object
    NSArray *class2des = kkp_parseStructFromTypeDescription([NSString stringWithUTF8String:typeDescription]);
    if (class2des.count > 1) {
        NSString *structName = class2des.firstObject;
        NSString *typeString = class2des.lastObject;
        
        NSDictionary *structDefine = kkp_struct_registeredStructs()[structName];
        if (!structDefine) {
            KKP_ERROR(L, @"Must register struct type in lua before using");
        }
        NSString *keys = structDefine[@"keys"];
        kkp_struct_create_userdata(L, structName.UTF8String, typeString.UTF8String, keys.UTF8String, buffer);
    } else {
        KKP_ERROR(L, @"Parsing struct type description failed");
    }
    
    return 1;
}

/// 把 lua 栈的数据转换成 oc 对象
/// 根据 oc 参数或者返回值类型签名，转成 oc 对象的指针
/// 如果是基本数据类型，则返回基本数据类型的指针，比如 type 是 int，则返回的是 int *
/// 如果是指针数据类型，则返回指针数据类型的指针，比如 type 是 void *，则返回的是 void **
void * kkp_toOCObject(lua_State *L, const char * typeDescription, int index)
{
    void *value = NULL;
    const char *type = kkp_removeProtocolEncodings(typeDescription);
    
    if (type[0] == _C_VOID) {
        return NULL;
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
    
#define KKP_TO_NUMBER_CONVERT(T) else if (type[0] == @encode(T)[0]) { value = malloc(sizeof(T)); *((T *)value) = (T)lua_tonumber(L, index); }
    
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
                    instance = userdata->instance;
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
                
                /// 目前 block 指针会走这里
                /// [block blockPtr]
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
                KKP_ERROR(L, error);
                return NULL;
            }
        }
    } else if (type[0] == _C_STRUCT_B) {
        KKPStructUserdata *structUserdata = (KKPStructUserdata *)luaL_checkudata(L, index, KKP_STRUCT_USER_DATA_META_TABLE);
        value = malloc(structUserdata->size);
        memcpy(value, structUserdata->data, structUserdata->size);
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
                    default: {
                        NSString *error = [NSString stringWithFormat:@"Can't convert %s to KKPInstanceUserdata.", luaL_typename(L, index)];
                        KKP_ERROR(L, error);
                        break;
                    }
                }
                break;
            }
            default:
                if (lua_islightuserdata(L, index)) {
                    pointer = lua_touserdata(L, index);
                } else {
                    free(value);
                    NSString *error = [NSString stringWithFormat:@"Converstion from %s to Objective-c not implemented.", typeDescription];
                    KKP_ERROR(L, error);
                }
        }
        
        if (pointer) {
            memcpy(value, &pointer, sizeof(void *));
        }
    } else {
        NSString* error = [NSString stringWithFormat:@"type %s in not support !", typeDescription];
        KKP_ERROR(L, error);
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
            /// oc block 或者其他 oc 对象都会走这里去创建 实例 user data
            /// 如果是 block 话，创建出来的 block user data 在 lua 脚本里可以通过 block_user_data() 的形式，来触发 LUserData_kkp_instance__call 调用，然后通过 kkp_callBlock 来调用实际 oc block
            kkp_instance_create_userdata(L, object);
        }
        return 1;
    });
}

/// 根据类型签名，把 buffer 数据转换成 lua 类型数据并压栈
int kkp_toLuaObjectWithBuffer(lua_State *L, const char * typeDescription, void *buffer)
{
    return kkp_safeInLuaStack(L, ^int{
        const char * type = kkp_removeProtocolEncodings(typeDescription);
        
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100
        if (type[0] == _C_VOID) {// 没有返回值
            lua_pushnil(L);
        } else if (type[0] == _C_PTR) {// 返回值是 指针 类型
            lua_pushlightuserdata(L, *(void **)buffer);
        }
        
#define NUMBER_TO_KKP_CONVERT(T) else if (type[0] == @encode(T)[0]) { lua_pushnumber(L, *(T *)buffer); }
        
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
            
            /// 创建 实例 user data
            kkp_toLuaObject(L, instance);
        } else if (type[0] == _C_CLASS) {// 返回值是 class 类型
            __unsafe_unretained id instance;
            instance = (__bridge id)(*(void **)buffer);
            
            /// 创建 类 user data
            kkp_class_create_userdata(L, instance);
        } else if (type[0] == _C_STRUCT_B) {// 返回值是 结构体 类型
            kkp_createStructUserDataWithBuffer(L, typeDescription, buffer);
        }
        else {
            NSString* error = [NSString stringWithFormat:@"Unable to convert Obj-C type with type description '%s'", typeDescription];
            KKP_ERROR(L, error);
            return 0;
        }
        
        return 1;
    });
}

/// 根据类型描述，计算出结构体占用的字节大小
int kkp_sizeOfStructTypes(const char *typeDescription)
{
    NSString *typeString = [NSString stringWithUTF8String:typeDescription];
    int index = 0;
    int size = 0;
    while (typeDescription[index]) {
        switch (typeDescription[index]) {
            #define KKP_STRUCT_SIZE_CASE(_typeChar, _type)   \
            case _typeChar: \
                size += sizeof(_type);  \
                break;
                
            KKP_STRUCT_SIZE_CASE('c', char)
            KKP_STRUCT_SIZE_CASE('C', unsigned char)
            KKP_STRUCT_SIZE_CASE('s', short)
            KKP_STRUCT_SIZE_CASE('S', unsigned short)
            KKP_STRUCT_SIZE_CASE('i', int)
            KKP_STRUCT_SIZE_CASE('I', unsigned int)
            KKP_STRUCT_SIZE_CASE('l', long)
            KKP_STRUCT_SIZE_CASE('L', unsigned long)
            KKP_STRUCT_SIZE_CASE('q', long long)
            KKP_STRUCT_SIZE_CASE('Q', unsigned long long)
            KKP_STRUCT_SIZE_CASE('f', float)
            KKP_STRUCT_SIZE_CASE('F', CGFloat)
            KKP_STRUCT_SIZE_CASE('N', NSInteger)
            KKP_STRUCT_SIZE_CASE('U', NSUInteger)
            KKP_STRUCT_SIZE_CASE('d', double)
            KKP_STRUCT_SIZE_CASE('B', BOOL)
            KKP_STRUCT_SIZE_CASE('*', void *)
            KKP_STRUCT_SIZE_CASE('^', void *)
            
            case '{': {// 结构体嵌套
                NSString *structTypeStr = [typeString substringFromIndex:index];
                NSUInteger end = [structTypeStr rangeOfString:@"}"].location;
                if (end != NSNotFound) {
                    NSString *subStructName = [structTypeStr substringWithRange:NSMakeRange(1, end - 1)];
                    NSDictionary *subStructDefine = kkp_struct_registeredStructs()[subStructName];
                    size += kkp_sizeOfStructTypes([subStructDefine[@"types"] UTF8String]);
                    index += (int)end;
                    break;
                }
            }
            
            default:
                break;
        }
        index ++;
    }
    return size;
}

/// 把结构体字典里的数据往结构体指针指向的内存里填充
void kkp_getStructDataOfDict(void *structData, NSDictionary *structDict, NSDictionary *structDefine)
{
    NSArray *itemKeys = [structDefine[@"keys"] componentsSeparatedByString:@","];
    const char *structTypes = [structDefine[@"types"] UTF8String];
    
    int position = 0;
    for (NSString *itemKey in itemKeys) {
        switch(*structTypes) {
            #define KKP_STRUCT_DATA_CASE(_typeStr, _type, _transMethod) \
            case _typeStr: { \
                int size = sizeof(_type);    \
                _type val = [structDict[itemKey] _transMethod];   \
                memcpy(structData + position, &val, size);  \
                position += size;    \
                break;  \
            }
                
            KKP_STRUCT_DATA_CASE('c', char, charValue)
            KKP_STRUCT_DATA_CASE('C', unsigned char, unsignedCharValue)
            KKP_STRUCT_DATA_CASE('s', short, shortValue)
            KKP_STRUCT_DATA_CASE('S', unsigned short, unsignedShortValue)
            KKP_STRUCT_DATA_CASE('i', int, intValue)
            KKP_STRUCT_DATA_CASE('I', unsigned int, unsignedIntValue)
            KKP_STRUCT_DATA_CASE('l', long, longValue)
            KKP_STRUCT_DATA_CASE('L', unsigned long, unsignedLongValue)
            KKP_STRUCT_DATA_CASE('q', long long, longLongValue)
            KKP_STRUCT_DATA_CASE('Q', unsigned long long, unsignedLongLongValue)
            KKP_STRUCT_DATA_CASE('f', float, floatValue)
            KKP_STRUCT_DATA_CASE('F', CGFloat, CGFloatValue)
            KKP_STRUCT_DATA_CASE('d', double, doubleValue)
            KKP_STRUCT_DATA_CASE('B', BOOL, boolValue)
            KKP_STRUCT_DATA_CASE('N', NSInteger, integerValue)
            KKP_STRUCT_DATA_CASE('U', NSUInteger, unsignedIntegerValue)
            
            case '*':
            case '^': {
                int size = sizeof(void *);
                void *val = (__bridge void *)(structDict[itemKey]);
                memcpy(structData + position, &val, size);
                break;
            }
            case '{': {// 处理结构体嵌套场景
                NSString *subStructName = [NSString stringWithCString:structTypes encoding:NSASCIIStringEncoding];
                NSUInteger end = [subStructName rangeOfString:@"}"].location;
                if (end != NSNotFound) {
                    subStructName = [subStructName substringWithRange:NSMakeRange(1, end - 1)];
                    NSDictionary *subStructDefine = kkp_struct_registeredStructs()[subStructName];
                    NSDictionary *subDict = structDict[itemKey];
                    int size = kkp_sizeOfStructTypes([subStructDefine[@"types"] UTF8String]);
                    kkp_getStructDataOfDict(structData + position, subDict, subStructDefine);
                    position += size;
                    structTypes += end;
                    break;
                }
            }
            default:
                break;
            
        }
        structTypes ++;
    }
}

/// 把结构体字指针指向的内存数据转换成字典
NSDictionary *kkp_getDictOfStructData(void *structData, NSDictionary *structDefine)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSArray *itemKeys = [structDefine[@"keys"] componentsSeparatedByString:@","];
    const char *structTypes = [structDefine[@"types"] UTF8String];
    int position = 0;
    
    for (NSString *itemKey in itemKeys) {
        switch(*structTypes) {
            #define KKP_STRUCT_DICT_CASE(_typeName, _type)   \
            case _typeName: { \
                size_t size = sizeof(_type); \
                _type *val = malloc(size);   \
                memcpy(val, structData + position, size);   \
                [dict setObject:@(*val) forKey:itemKey];    \
                free(val);  \
                position += size;   \
                break;  \
            }
            KKP_STRUCT_DICT_CASE('c', char)
            KKP_STRUCT_DICT_CASE('C', unsigned char)
            KKP_STRUCT_DICT_CASE('s', short)
            KKP_STRUCT_DICT_CASE('S', unsigned short)
            KKP_STRUCT_DICT_CASE('i', int)
            KKP_STRUCT_DICT_CASE('I', unsigned int)
            KKP_STRUCT_DICT_CASE('l', long)
            KKP_STRUCT_DICT_CASE('L', unsigned long)
            KKP_STRUCT_DICT_CASE('q', long long)
            KKP_STRUCT_DICT_CASE('Q', unsigned long long)
            KKP_STRUCT_DICT_CASE('f', float)
            KKP_STRUCT_DICT_CASE('F', CGFloat)
            KKP_STRUCT_DICT_CASE('N', NSInteger)
            KKP_STRUCT_DICT_CASE('U', NSUInteger)
            KKP_STRUCT_DICT_CASE('d', double)
            KKP_STRUCT_DICT_CASE('B', BOOL)
            
            case '*':
            case '^': {
                size_t size = sizeof(void *);
                void *val = malloc(size);
                memcpy(val, structData + position, size);
                [dict setObject:(__bridge id _Nonnull)(val) forKey:itemKey];
                position += size;
                break;
            }
            case '{': {// 处理结构体嵌套场景
                NSString *subStructName = [NSString stringWithCString:structTypes encoding:NSASCIIStringEncoding];
                NSUInteger end = [subStructName rangeOfString:@"}"].location;
                if (end != NSNotFound) {
                    subStructName = [subStructName substringWithRange:NSMakeRange(1, end - 1)];
                    NSDictionary *subStructDefine = kkp_struct_registeredStructs()[subStructName];;
                    int size = kkp_sizeOfStructTypes([subStructDefine[@"types"] UTF8String]);
                    NSDictionary *subDict = kkp_getDictOfStructData(structData + position, subStructDefine);
                    [dict setObject:subDict forKey:itemKey];
                    position += size;
                    structTypes += end;
                    break;
                }
            }
        }
        structTypes ++;
    }
    return dict;
}
