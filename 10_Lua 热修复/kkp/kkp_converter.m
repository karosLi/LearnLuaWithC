//
//  kkp_converter.m
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import "kkp_converter.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>
#import "lauxlib.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_class.h"
#import "kkp_instance.h"
#import "KKPBlockInstance.h"

typedef void (^kkp_hoder_free_block_t)(void);

@interface KKPHoderHelper : NSObject

@property (nonatomic, copy) kkp_hoder_free_block_t block;

@end

@implementation KKPHoderHelper

- (instancetype)init:(kkp_hoder_free_block_t)block
{
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

- (void)dealloc
{
    if (self.block) {
        self.block();
    }
}

@end

static void *createOneKeyHoderObjectPtr(lua_State *L, const char type, id value)
{
    if (value == nil) {
        return NULL;
    }
    
    BOOL success = YES;
    NSString* className = [NSString stringWithFormat:@"KKPHolderClass_%c", type];
    Class klass = objc_allocateClassPair([NSObject class], className.UTF8String, 0);
    if (klass == nil) {
        klass = NSClassFromString(className);
    } else {
        NSUInteger size;
        NSUInteger alingment;
        NSGetSizeAndAlignment(&type, &size, &alingment);
        success = class_addIvar(klass, "key", size, log2(alingment), &type);
        
        if (!success) {
            luaL_error(L, "[KKP] create %c number class failed !", type);
            return NULL;
        }
        
        objc_registerClassPair(klass);
    }
    id __autoreleasing object = [[klass alloc] init];
    [object setValue:value forKey:@"key"];
    void* p = (__bridge void *)object;
    /// isa 指针 + 指针长度 得到就是 第一个 实例变量的地址
    p = p + sizeof(void *);
    return p;
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

void * kkp_toOCObject(lua_State *L, const char * typeDescription, int index)
{
    char type = kkp_removeProtocolEncodings(typeDescription);
    
    if (type == @encode(void)[0]) {
        return NULL;
    }
    if (type == @encode(char *)[0]) {
        const char* string = lua_tostring(L, index);
        void* p = malloc(strlen(string) + 1);
        memset(p, 0, strlen(string) + 1);
        strcpy(p, string);
        struct S {
            char *p;
        };
        struct S* s = malloc(sizeof(struct S));
        s->p = p;
        __unused KKPHoderHelper* __autoreleasing sh = [[KKPHoderHelper alloc] init:^void{
            free(p);
            free(s);
        }];
        return s;
    } else if (type == @encode(SEL)[0]) {
        const char* string = lua_tostring(L, index);
        struct S {
            SEL p;
        };
        struct S* s = malloc(sizeof(struct S));
        s->p = NSSelectorFromString([NSString stringWithUTF8String:string]);
        __unused KKPHoderHelper* __autoreleasing sh = [[KKPHoderHelper alloc] init:^void{
            free(s);
        }];
        return s;
    } else if (type == @encode(char)[0]) {
        char c = lua_tostring(L, index)[0];
        return createOneKeyHoderObjectPtr(L, type, @(c));
    } else if (type == @encode(bool)[0]) {
        return createOneKeyHoderObjectPtr(L, type, @(lua_toboolean(L, index)));
    } else if (type == @encode(id)[0]) {
        switch (lua_type(L, index)) {
            case LUA_TNIL:
            case LUA_TNONE:
                return NULL;
            case LUA_TBOOLEAN:
                return createOneKeyHoderObjectPtr(L, type, @(lua_toboolean(L, index)));
            case LUA_TNUMBER:
                return createOneKeyHoderObjectPtr(L, type, @(lua_tonumber(L, index)));
            case LUA_TSTRING:
            {
                id string = [NSString stringWithUTF8String:lua_tostring(L, index)];
                return createOneKeyHoderObjectPtr(L, type, string);
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
                    }
                    else {
                        lua_pop(L, 1);
                    }
                }
                
                id instance = nil;
                if (dictionary) {
                    instance = [NSMutableDictionary dictionary];
                    lua_pushnil(L);  /* first key */
                    while (lua_next(L, -2)) {
                        struct S
                        {
                            id instance;
                        };
                        id key = ((struct S*)kkp_toOCObject(L, "@", -2))->instance;
                        id object = ((struct S*)kkp_toOCObject(L, "@", -1))->instance;
                        [instance setObject:object forKey:key];
                        lua_pop(L, 1); // Pop off the value
                    }
                } else {
                    instance = [NSMutableArray array];
                    lua_pushnil(L);  /* first key */
                    while (lua_next(L, -2)) {
                        int index = lua_tonumber(L, -2) - 1;
                        struct S
                        {
                            id instance;
                        };
                        struct S* s = (struct S*)kkp_toOCObject(L, "@", -1);
                        [instance insertObject:s->instance atIndex:index];
                        lua_pop(L, 1);
                    }
                }
                lua_pop(L, 1); // Pop the table reference off
                return createOneKeyHoderObjectPtr(L, type, instance);
            }
            case LUA_TUSERDATA:
            {
                KKPInstanceUserdata* userdata = lua_touserdata(L, index);
                if (userdata && userdata->instance) {
                    return createOneKeyHoderObjectPtr(L, type, userdata->instance);
                } else {
                    return NULL;
                }
            }
            case LUA_TFUNCTION:
            {
                __block NSString* returnType = nil;
                NSMutableArray* argsType = [NSMutableArray array];
                
                KKPBlockInstance* instance = [[KKPBlockInstance alloc] init];
//                kkp_stackDump(L);
//                kkp_safeInLuaStack(L, ^int{
////                    lua_getfenv(L, index);
//
//                    // get return type
//                    lua_getfield(L, -1, "return_type");
//
//                    const char* return_type = lua_tostring(L, -1);
//                    if (return_type) {
//                        returnType = [NSString stringWithUTF8String:return_type];
//                    }
//                    // get params type
//                    lua_getfield(L, -2, "args_type");
//
//                    if (!lua_isnil(L, -1)) {
//                        lua_pushnil(L);
//                        while (lua_next(L, -2)) {
//                            int type = lua_type(L, -1);
//                            if (type == LUA_TSTRING) {
//                                const char * arg_type = lua_tostring(L, -1);
//                                if (arg_type) {
//                                    [argsType addObject:[NSString stringWithUTF8String:arg_type]];
//                                }
//                                lua_pop(L, 1);
//                            }
//                        }
//                    }
//
//                    return 0;
//                });
                
                kkp_instance_create_userdata(L, instance);
                
                /// 设置 lua 函数到 实例 user data 的 关联表 里
                // 获取 实例 userdata 的关联表，并压栈
                lua_getuservalue(L, -1);
                // 压入key
                lua_pushstring(L, "function");
                // 把函数压栈
                lua_pushvalue(L, index);
                // 把函数保存到关联表里，相当于 associated_table["_SCOPE"] = scope
                lua_rawset(L, -3);
                // pop 关联表
                lua_pop(L, 1);
                
//                // 设置 lua 函数到 新表里，然后把 新表 设置到 实例 user data 的 关联表 里
//                lua_newtable(L);
//                lua_pushstring(L, "f");
//                lua_pushvalue(L, index);
//                lua_settable(L, -3);
//                lua_setfenv(L, -2);
                
                if (returnType.length == 0 && argsType.count == 0) {
                    return createOneKeyHoderObjectPtr(L, type, [instance voidBlock]);
                } else {
                    return createOneKeyHoderObjectPtr(L, type, [instance blockWithParamsTypeArray:argsType returnType:returnType]);
                }
            }
            default:
            {
                NSString* error = [NSString stringWithFormat:@"type %s in not support !", typeDescription];
                KKP_ERROR(L, error.UTF8String);
                return NULL;
            }
        }
    } else if (type == _C_STRUCT_B) {
        return toStruct(L, typeDescription, index);
    } else if (type == @encode(int)[0] ||
               type == @encode(short)[0] ||
               type == @encode(long)[0] ||
               type == @encode(long long)[0] ||
               type == @encode(unsigned int)[0] ||
               type == @encode(unsigned short)[0] ||
               type == @encode(unsigned long)[0] ||
               type == @encode(unsigned long long)[0] ||
               type == @encode(float)[0] ||
               type == @encode(double)[0]) {
        return createOneKeyHoderObjectPtr(L, type, @(lua_tonumber(L, index)));
    } else {
        NSString* error = [NSString stringWithFormat:@"type %s in not support !", typeDescription];
        KKP_ERROR(L, error.UTF8String);
        return NULL;
    }
    return NULL;
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

#define KKP_LUA_NUMBER_CONVERT(T) else if (type == @encode(T)[0]) { lua_pushnumber(L, *(T *)buffer); }
int kkp_toLuaObjectWithBuffer(lua_State *L, const char * typeDescription, void *buffer)
{
    return kkp_safeInLuaStack(L, ^int{
        char type = kkp_removeProtocolEncodings(typeDescription);
        
        // http://developer.apple.com/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
        if (type == _C_VOID) {// 没有返回值
            lua_pushnil(L);
        } else if (type == _C_PTR) {// 返回值是 指针 类型
            lua_pushlightuserdata(L, *(void **)buffer);
        }
        
        KKP_LUA_NUMBER_CONVERT(char)
        KKP_LUA_NUMBER_CONVERT(unsigned char)
        KKP_LUA_NUMBER_CONVERT(int)
        KKP_LUA_NUMBER_CONVERT(short)
        KKP_LUA_NUMBER_CONVERT(long)
        KKP_LUA_NUMBER_CONVERT(long long)
        KKP_LUA_NUMBER_CONVERT(unsigned int)
        KKP_LUA_NUMBER_CONVERT(unsigned long)
        KKP_LUA_NUMBER_CONVERT(unsigned long long)
        KKP_LUA_NUMBER_CONVERT(float)
        KKP_LUA_NUMBER_CONVERT(double)
        
        else if (type == _C_BOOL) {// 返回值是 布尔 类型
            lua_pushboolean(L, *(bool *)buffer);
        } else if (type == _C_CHARPTR) {// 返回值是 字符串 类型
            lua_pushstring(L, *(char **)buffer);
        } else if (type == _C_SEL) {// 返回值是 选择器 类型
            lua_pushstring(L, sel_getName(*(SEL *)buffer));
        } else if (type == _C_ID) {// 返回值是 OC 对象 类型
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
            
            id instance = *((__unsafe_unretained id *)buffer);
            kkp_toLuaObject(L, instance);
        } else if (type == _C_CLASS) {// 返回值是 class 类型
            id instance = *((__unsafe_unretained id *)buffer);
            kkp_class_create_userdata(L, NSStringFromClass(instance).UTF8String);
        } else if (type == _C_STRUCT_B) {// 返回值是 结构体 类型
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
