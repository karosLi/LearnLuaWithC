//
//  kkp_converter.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import <Foundation/Foundation.h>
#import "lua.h"

extern void * kkp_toOCObject(lua_State *L, const char * typeDescription, int index);
extern int kkp_toLuaObject(lua_State *L, id object);
extern int kkp_toLuaObjectWithType(lua_State *L, const char * typeDescription, void *buffer);
