//
//  loadlib.m
//  LearnLua
//
//  Created by karos li on 2022/1/21.
//

#import "loadlib.h"
#import "mylib.h"

static const luaL_Reg loadedstdlibs[] = {
    {"mylib.util", luaopen_mylib},
    {NULL, NULL}
};

LUALIB_API void load_stdlibs(lua_State *L) {
    const luaL_Reg *lib;
    /* "require" functions from 'loadedstdlibs' and dont set results to global table */
    for (lib = loadedstdlibs; lib->func; lib++) {
        /**
         执行完后，package.loaded 新增一个字段
         package.loaded[libname] = lib {
            注册的函数名：注册函数指针
            其他函数
         }
         
         并且 全局注册表中的loaded表新增一个字段，因为 lua 安装 package 标准库的时候，就已经设置了 register["loaded"] = package.loaded
         register["loaded"] = {
            libname: lib,
            其他库
         }
         
         最后一个参数表示是否需要设置成全局标量，如果为1，表示就是全局变量,
         相当于 _G[libname] = lib，那么在 lua 脚本中也不需要 require 就可以直接使用这个模块
         */
        luaL_requiref(L, lib->name, lib->func, 0);
        lua_pop(L, 1);  /* remove lib */
    }
}
