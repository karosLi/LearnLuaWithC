//
//  kkp_global_util.m
//  LearnLua
//
//  Created by karos li on 2022/2/25.
//

#import "kkp_global_util.h"
#import "lualib.h"
#import "lauxlib.h"
#import "kkp_define.h"
#import "kkp_helper.h"
#import "kkp_converter.h"

int kkp_global_isNull(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        void **ud = (void **)lua_touserdata(L, -1);
        if (ud == NULL || *ud == NULL) {
            lua_pushboolean(L, 1);
            return 1;
        } else {
            lua_pushboolean(L, 0);
            return 1;
        }
    });
}

int kkp_global_print(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        NSLog(@"%s", luaL_checkstring(L, 1));//only NSLog can show log in console when not debug
        return 0;
    });
}

int kkp_global_root(lua_State *L)
{
    return kkp_safeInLuaStack(L, ^int{
        luaL_Buffer b;
        luaL_buffinit(L, &b);
        luaL_addstring(&b, KKP_LUA_SCRIPTS_DIR);
        
        for (int i = 1; i <= lua_gettop(L); i++) {
            luaL_addstring(&b, "/");
            luaL_addstring(&b, luaL_checkstring(L, i));
        }

        luaL_pushresult(&b);
                           
        return 1;
    });
}

int kkp_global_exitApp(lua_State *L)
{
    exit(0);
    return 0;
}

