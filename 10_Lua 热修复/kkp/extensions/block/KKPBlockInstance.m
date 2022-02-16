//
//  KKPBlockInstance.m
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import "KKPBlockInstance.h"
#import "lauxlib.h"
#import "kkp.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_instance.h"
#import "kkp_converter.h"
#import "KKPDynamicBlock.h"

@implementation KKPBlockInstance

/// 返回一个 没有参数且没有返回值的 oc block 给到原生
- (void (^)(void))voidBlock
{
    return ^() {
        /// 原生调用 oc block 时，block 包裹的 lua 函数，在这里被实际调用
        lua_State* L = kkp_currentLuaState();
        kkp_safeInLuaStack(L, ^int{
            /// 获取 实例 user data 并压栈
            luaL_getmetatable(L, KKP_INSTANCE_USER_DATA_LIST_TABLE);
            lua_pushlightuserdata(L, (__bridge void *)(self));
            lua_rawget(L, -2);
            lua_remove(L, -2); // remove userdataTable
            
            // 获取 实例 userdata 的关联表，并压栈
            lua_getuservalue(L, -1);
            // 压入key
            lua_pushstring(L, "f");
            // 获取 key 对应的 lua 函数，并压栈
            lua_rawget(L, -2);
            
            if (!lua_isnil(L, -1) && lua_type(L, -1) == LUA_TFUNCTION) {
                if(lua_pcall(L, 0, 0, 0) != 0){
                NSString* log = [NSString stringWithFormat:@"[KKP] PANIC: unprotected error in call to Lua API (%s)\n", lua_tostring(L, -1)];
                NSLog(@"%@", log);
                if (kkp_getSwizzleCallback()) {
                    kkp_getSwizzleCallback()(NO, log);
                }
                NSCAssert(NO, log);
                }
            }
            return 0;
        });
    };
}

/// 返回一个 有参数或者有返回值的 oc block 给到原生
- (id)blockWithParamsTypeArray:(NSArray *)paramsTypeArray returnType:(NSString *)returnType
{
    KKPDynamicBlock* __autoreleasing blk = [[KKPDynamicBlock alloc] initWithArgsTypes:paramsTypeArray retType:returnType replaceBlock:^void *(void **args) {
        
        /// 原生调用 oc block 时，block 包裹的 lua 函数，在这里被实际调用
        
        __block void *returnBuffer = nil;
        
        lua_State* L = kkp_currentLuaState();
        kkp_safeInLuaStack(L, ^int{
            
            luaL_getmetatable(L, KKP_INSTANCE_USER_DATA_LIST_TABLE);
            lua_pushlightuserdata(L, (__bridge void *)(self));
            lua_rawget(L, -2);
            lua_remove(L, -2); // remove userdataTable
            
            // 获取 实例 userdata 的关联表，并压栈
            lua_getuservalue(L, -1);
            // 压入key
            lua_pushstring(L, "f");
            // 获取 key 对应的 lua 函数，并压栈
            lua_rawget(L, -2);
           
            if (lua_isnil(L, -1) || lua_type(L, -1) != LUA_TFUNCTION) {
                return 0;
            }
            
            // push args
            [paramsTypeArray enumerateObjectsUsingBlock:^(NSString*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                // 根据参数类型，把 oc 参数转换成 lua 参数，并压栈
                const char *typeDescription = obj.UTF8String;
                kkp_toLuaObjectWithBuffer(L, typeDescription, args[idx+1]);
            }];
            
            NSUInteger paramNum = [paramsTypeArray count];
            
            if (returnType == nil) {
                if(lua_pcall(L, (int)paramNum, 0, 0) != 0){
                    NSString* log = [NSString stringWithFormat:@"[KKP] PANIC: unprotected error in call to Lua API (%s)\n", lua_tostring(L, -1)];
                    NSLog(@"%@", log);
                    if (kkp_getSwizzleCallback()) {
                        kkp_getSwizzleCallback()(NO, log);
                    }
                    NSCAssert(NO, log);
                }

            } else {
                if (lua_pcall(L, (int)paramNum, 1, 0) != 0){
                    NSString* log = [NSString stringWithFormat:@"[KKP] PANIC: unprotected error in call to Lua API (%s)\n", lua_tostring(L, -1)];
                    NSLog(@"%@", log);
                    if (kkp_getSwizzleCallback()) {
                        kkp_getSwizzleCallback()(NO, log);
                    }
                    NSCAssert(NO, log);
                }
                returnBuffer = kkp_toOCObject(L, returnType.UTF8String, -1);
            }
            
            return 0;
        });
        // 返回 lua 函数调用的结果 给到 原生
        return returnBuffer;
    }];
    return blk.invokeBlock;
}

@end
