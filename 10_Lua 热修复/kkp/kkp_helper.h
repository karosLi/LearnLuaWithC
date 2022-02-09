//
//  kkp_helper.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import <Foundation/Foundation.h>
#import "lua.h"

#define KKP_ERROR(L, err) luaL_error(L, "[KKP] error %s line %d %s: %s", __FILE__, __LINE__, __FUNCTION__, err);

#define KKP_PROTOCOL_TYPE_CONST 'r'
#define KKP_PROTOCOL_TYPE_IN 'n'
#define KKP_PROTOCOL_TYPE_INOUT 'N'
#define KKP_PROTOCOL_TYPE_OUT 'o'
#define KKP_PROTOCOL_TYPE_BYCOPY 'O'
#define KKP_PROTOCOL_TYPE_BYREF 'R'
#define KKP_PROTOCOL_TYPE_ONEWAY 'V'

typedef int (^kkp_lua_stack_safe_block_t)(void);
typedef int (^kkp_lua_lock_safe_block_t)(void);

extern int kkp_safeInLuaStack(lua_State *L, kkp_lua_stack_safe_block_t block);

extern int kkp_performLocked(kkp_lua_lock_safe_block_t block);

extern void kkp_stackDump(lua_State *L);

extern char kkp_removeProtocolEncodings(const char *typeDescription);

extern const char* kkp_toObjcSel(const char *luaFuncName);

extern char* kkp_toObjcPropertySel(const char *prop);

extern const char* kkp_toLuaFuncName(const char *objcSel);

extern SEL kkp_originForSelector(SEL sel);

extern bool kkp_isBlock(id object);

extern int kkp_callBlock(lua_State *L);

extern int kkp_invoke(lua_State *L);

extern NSArray* kkp_parseStructFromTypeDescription(NSString *typeDes);


