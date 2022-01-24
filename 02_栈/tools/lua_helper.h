//
//  lua_helper.h
//  LearnLua
//
//  Created by karos li on 2022/1/18.
//

/**
 LUA C API 手册
 
 http://cloudwu.github.io/lua53doc/manual.html
 */

#ifndef lua_helper_h
#define lua_helper_h

#include "lua.hpp"

/// 打印错误信息
static inline void error(lua_State *L, const char *fmt...)
{
    va_list args;
    va_start(args, fmt);// 从 fmt 后面开始就是 args 可变参数
    vfprintf(stderr, fmt, args);
    va_end(args);
    lua_close(L);
    exit(EXIT_FAILURE);
}

/// 加载lua配置脚本文件
static inline void loadConfig(lua_State* L, const char *fname, int *w, int *h)
{
    /// 1、加载脚本文件，把编译好的代码块压入栈顶
    /// 2、调用栈顶的代码块
    /// 3、如果过程中有任何错误，则把错误信息压入到栈顶
    if (luaL_loadfile(L, fname) || lua_pcall(L, 0, 0, 0)) {
        /// 把栈顶信息转成字符串并打印出来
        error(L, "cannot run config. file: %s", lua_tostring(L, -1));
    }
    
    lua_getglobal(L, "width");// 把全局变量 width 里的值压栈
    lua_getglobal(L, "height");// 把全局变量 height 里的值压栈
    
    /// 栈：width(索引-2) height(索引-1)
    if (!lua_isnumber(L, -2)) {// 宽度是否是数字
        error(L, "width should be a number\n");
    }
    
    if (!lua_isnumber(L, -1)) {// 高度是否是数字
        error(L, "height should be a number\n");
    }
    
    *w = (int)lua_tointeger(L, -2);
    *h = (int)lua_tointeger(L, -1);
}

/// dump 栈
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
            case LUA_TNIL:// 空
            {
                printf("nil");
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
    printf("\n");
    printf("stackDump end\n");
    printf("\n");
}

#endif /* lua_helper_h */
