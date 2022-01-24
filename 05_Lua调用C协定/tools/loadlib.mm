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
        luaL_requiref(L, lib->name, lib->func, 0);
        lua_pop(L, 1);  /* remove lib */
    }
}
