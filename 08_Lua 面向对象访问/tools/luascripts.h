//
//  luascripts.h
//  LearnLua
//
//  Created by karos li on 2022/1/24.
//

#ifndef luascripts_h
#define luascripts_h
// 一些工具宏方法

#if LUA_VERSION_NUM >= 502
#ifndef LUA_COMPAT_ALL
#ifndef LUA_COMPAT_MODULE
#define luaL_register(L, libname, l) (luaL_newlib(L, l), lua_pushvalue(L, -1), lua_setglobal(L, libname))
#endif
#undef lua_equal
#define lua_equal(L, i1, i2) lua_compare(L, (i1), (i2), LUA_OPEQ)
#endif
#endif

#endif /* luascripts_h */
