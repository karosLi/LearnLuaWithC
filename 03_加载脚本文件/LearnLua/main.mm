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
    changeCurDirToBundlePath();
    
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    
    int w;
    int h;
    loadConfig(L, "config.lua", &w, &h);
    lua_close(L);
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
