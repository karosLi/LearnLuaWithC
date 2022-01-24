//
//  loadlib.h
//  LearnLua
//
//  Created by karos li on 2022/1/21.
//

#import <Foundation/Foundation.h>

#include "lua.hpp"

LUALIB_API void load_stdlibs(lua_State *L);
