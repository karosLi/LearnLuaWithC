//
//  lua_test.h
//  LearnLua
//
//  Created by karos li on 2022/1/21.
//

#ifndef lua_test_h
#define lua_test_h

#include <iostream>
#include "lua.hpp"

/// 测试全局注册表
static inline void test_registry(lua_State *L)
{
    // 全局注册表，类似于c语言的静态变量，用于在多个模块间共享数据
    // 保存一个字符串到全局注册表中
    static char key = 'k';
    lua_pushlightuserdata(L, (void *)&key);// 压入地址
    lua_pushstring(L, "bbb"); // 压入值
    lua_settable(L, LUA_REGISTRYINDEX);// 全局注册表 registry[&key]=bbb
    // 从全局注册表中获取一个字符串
    lua_pushlightuserdata(L, (void *)&key);// 压入地址
    lua_gettable(L, LUA_REGISTRYINDEX);// 全局注册表 registry[&key]，把获取到的值压入栈顶
    const char *value_from_register = lua_tostring(L, -1);
    printf("value_from_register %s\n", value_from_register);
    
    // 通过引用的方式来关联一个值，并放入到全局注册表中
    lua_pushstring(L, "ccc"); // 压入值
    int ref_key = luaL_ref(L, LUA_REGISTRYINDEX);// 针对栈顶值生成一个在全局注册表中的唯一引用 key，相当于 registry[ref_key]=ccc
    // 取值
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref_key);
    const char *value_from_register1 = lua_tostring(L, -1);
    printf("value_from_register1 %s\n", value_from_register1);
    
    
    // 环境table，用于在一个模块内，多个函数间共享数据; 默认每个函数的函数环境是全局环境_G表，Lua 5.2 后，只有lua 函数才有环境，c 函数不在有环境了
}

#endif /* lua_test_h */
