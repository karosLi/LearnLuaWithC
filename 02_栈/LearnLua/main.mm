//
//  main.m
//  LearnLua
//
//  Created by karos li on 2022/1/17.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

#include <cstdio>
#include <cstring>
#include "lua.hpp"
#include "lua_helper.h"

int main(int argc, char * argv[]) {
    lua_State *L = luaL_newstate();
    {
        lua_pushboolean(L, 1);
        lua_pushnumber(L, 10);
        lua_pushnil(L);
        lua_pushstring(L, "hello");
        stackDump(L);// true 10 nil hello
        
        lua_pushvalue(L, -4);// 拷贝指定索引的元素，并放到栈顶
        stackDump(L);// true 10 nil hello true
        
        lua_replace(L, 3);// 弹出栈顶的元素，替换到指定索引上
        stackDump(L);// true 10 true hello
        
        lua_settop(L, 6);// 把栈顶设置到指定索引上
        stackDump(L);// true 10 true hello nil nil
        
        lua_remove(L, -3);// 删除指定索引的元素，该索引之上的元素都会下移
        stackDump(L);// true 10 true nil nil
        
        lua_close(L);
    }
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
