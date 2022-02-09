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
#import "kkp_instance.h"
#import "KKPBlockInstance.h"

#define KKP_LUA_NUMBER_CONVERT(T) else if (type == @encode(T)[0]) { lua_pushnumber(L, *(T *)buffer); }

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
            luaL_error(L, "[SPA] create %c number class failed !", type);
            return NULL;
        }
        
        objc_registerClassPair(klass);
    }
    id __autoreleasing object = [[klass alloc] init];
    [object setValue:value forKey:@"key"];
    void* p = (__bridge void *)object;
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
                
                kkp_safeInLuaStack(L, ^int{
//                    lua_getfenv(L, index);
                    
                    // get return type
                    lua_getfield(L, -1, "return_type");
                    
                    const char* return_type = lua_tostring(L, -1);
                    if (return_type) {
                        returnType = [NSString stringWithUTF8String:return_type];
                    }
                    // get params type
                    lua_getfield(L, -2, "args_type");
                    
                    if (!lua_isnil(L, -1)) {
                        lua_pushnil(L);
                        while (lua_next(L, -2)) {
                            int type = lua_type(L, -1);
                            if (type == LUA_TSTRING) {
                                const char * arg_type = lua_tostring(L, -1);
                                if (arg_type) {
                                    [argsType addObject:[NSString stringWithUTF8String:arg_type]];
                                }
                                lua_pop(L, 1);
                            }
                        }
                    }
                    
                    return 0;
                });
                
                kkp_instance_create_userdata(L, instance);
                
                // set lua function to env
                lua_newtable(L);
                lua_pushstring(L, "f");
                lua_pushvalue(L, index);
                lua_settable(L, -3);
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

int kkp_toLuaObjectWithType(lua_State *L, const char * typeDescription, void *buffer)
{
    return kkp_safeInLuaStack(L, ^int{
        char type = kkp_removeProtocolEncodings(typeDescription);
        if (type == @encode(bool)[0]) {
            lua_pushboolean(L, *(bool *)buffer);
        } else if (type == @encode(char *)[0] || type == @encode(SEL)[0]) {
            lua_pushstring(L, *(char **)buffer);
        } else if (type == @encode(char)[0]) {
            char s[2];
            s[0] = *(char *)buffer;
            s[1] = '\0';
            lua_pushstring(L, s);
        } else if (type == _C_STRUCT_B) {
            toLuaTableFromStruct(L, typeDescription, buffer);
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
        else {
            NSString* error = [NSString stringWithFormat:@"type %s in not support !", typeDescription];
            KKP_ERROR(L, error.UTF8String);
            return 0;
        }
        return 1;
    });
}
