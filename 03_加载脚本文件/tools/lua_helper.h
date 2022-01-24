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

#include <iostream>
#include "lua.hpp"

#define MAX_COLORS 255

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

/// 获取字段的值，假设 table 位于栈顶
static inline int getField(lua_State *L, const char *key) {
    int result;
    
    /// 方法一
//    lua_pushstring(L, key);
//    lua_gettable(L, -2);// 把 t[k] 的值压栈， 这里的 t 是指索引指向的值， 而 k 则是栈顶放的值。
//    if (!lua_isnumber(L, -1)) {
//        error(L, "invalid component in background. msg: %s", lua_tostring(L, -1));
//    }
//    result = (int)(lua_tonumber(L, -1) * MAX_COLORS);
    
    /// 方法二 更优
    lua_getfield(L, -1, key);// 把 t[k] 的值压栈。t 就是索引指向的元素，这里指的是第二个参数，k 是第三个参数。
    if (!lua_isnumber(L, -1)) {
        error(L, "invalid component in table. msg: %s", lua_tostring(L, -1));
    }
    result = (int)(lua_tonumber(L, -1) * MAX_COLORS);
    lua_pop(L, 1);// 删除栈顶数字
    
    return result;
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
    
    lua_getglobal(L, "background");// 把全局变量 background 里的值压栈
    if (!lua_istable(L, -1)) {// background是否是表
        error(L, "background is not a table\n");
    }
    
    /// 获取table中的字段值
    int red = getField(L, "r");
    int green = getField(L, "g");
    int blue = getField(L, "b");
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

/// 获取 iOS 的bundle 路径
static inline std::string getiOSBundlePath()
{
    NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
    return std::string([bundlePath UTF8String]);
}

/// 设置 Lua 虚拟机的加载路径
static inline int setLuaPackagePath(lua_State* L, const char* path)
{
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "path"); // get field "path" from table at top of stack (-1)
    std::string cur_path = lua_tostring(L, -1); // grab path string from top of stack
    cur_path.append(";"); // do your path magic here
    cur_path.append(path);
    lua_pop(L, 1); // get rid of the string on the stack we just pushed on line 5
    lua_pushstring(L, cur_path.c_str()); // push the new one
    lua_setfield(L, -2, "path"); // set the field "path" in table at -2 with value at top of stack
    lua_pop(L, 1); // get rid of package table from top of stack
    return 0; // all done!
}

/// 配置应用的加载lua路径
static inline void setApplicationPath(lua_State* L)
{
    std::string bundlePath = getiOSBundlePath();
    bundlePath.append("/?.lua");
    setLuaPackagePath(L, bundlePath.c_str());
}

/// 改变当前目录为bundle目录
static inline void changeCurDirToBundlePath()
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];
}

#endif /* lua_helper_h */
