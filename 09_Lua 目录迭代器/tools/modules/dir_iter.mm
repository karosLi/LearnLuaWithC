//
//  dir_iter.m
//  LearnLua
//
//  Created by karos li on 2022/1/24.
//

#import "dir_iter.h"

#include <dirent.h>
#include <errno.h>
#include "lua_helper.h"

/// 目录迭代器实际函数
static int dir_iter(lua_State *L)
{
    DIR *d = *(DIR **)lua_touserdata(L, lua_upvalueindex(1));
    struct dirent *entry;
    if ((entry = readdir(d)) != NULL) {
        // 返回当前迭代的目录名称
        lua_pushstring(L, entry->d_name);
        return 1;
    } else {
        return 0;// 没有返回值
    }
}

/// 关闭目录
static int dir_gc(lua_State *L)
{
    void **p = (void **)lua_touserdata(L, lua_upvalueindex(1));
    if (p) {
        DIR *d = *(DIR **)p;
        if (d) {
            closedir(d);
        }
    }
    
    return 0;
}

/// 目录迭代器
static int l_dir_iter(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    
    // 创建一个userdata，用于保存DIR的地址
    DIR **d = (DIR **)lua_newuserdata(L, sizeof(DIR *));
    
    // 设置元表
    luaL_getmetatable(L, "Dir.iter");
    lua_setmetatable(L, -2);
    
    // 打开目录
    *d = opendir(path);
    if (*d == NULL) {// 打开失败
        luaL_error(L, "can not open %s: %s", path, strerror(errno));
    }
    
    // 创建并返回迭代器，他唯一的upvalue就是目录userdata，此时位于栈顶
    lua_pushcclosure(L, dir_iter, 1);
    
    return 1;
}

LUAMOD_API int luaopen_diriter(lua_State *L)
{
    luaL_newmetatable(L, "Dir.iter"); //新建一个元表,并注册到注册表中
    // 设置元表的 __gc 字段
    lua_pushcfunction(L, dir_gc);
    lua_setfield(L, -2, "__gc");
    
    // 注册函数
    lua_pushcfunction(L, l_dir_iter);
    lua_setglobal(L, "dir");
    
    return 1;
}
