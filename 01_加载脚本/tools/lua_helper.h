//
//  lua_helper.h
//  LearnLua
//
//  Created by karos li on 2022/1/18.
//

/**
 LUA C API 手册
 
 https://www.cnblogs.com/jadeshu/articles/10663547.html
 http://cloudwu.github.io/lua53doc/manual.html
 */

#ifndef lua_helper_h
#define lua_helper_h

#include "lua.hpp"

static inline void stackDump(lua_State *L)
{
    printf("stackDump start\n");
    int i;
    int top = lua_gettop(L);
    for (i = 1; i <= top; i++) {
        int t = lua_type(L, i);
        switch (t) {
            case LUA_TSTRING:// 字符串
            {
                printf("%s", lua_tostring(L, i));
                break;
            }
            case LUA_TBOOLEAN:// 布尔
            {
                printf("%s", lua_toboolean(L, i) ? "true" : "false");
                break;
            }
            case LUA_TNUMBER:// 数字
            {
                printf("%g", lua_tonumber(L, i));
                break;
            }
            default:// 其他类型
            {
                printf("%s", lua_typename(L, i));
                break;
            }
        }
        printf(" ");// 打印空格分隔符
    }
    printf("stackDump end\n");
    printf("\n");
}

#endif /* lua_helper_h */
