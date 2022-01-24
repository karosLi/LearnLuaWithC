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

char const* script = R"(
function helloworld()
    print('hello world!')
end
helloworld()
)";

int main(int argc, char * argv[]) {
    lua_State* state = luaL_newstate();
    luaL_openlibs(state);
    {
        auto rst = luaL_loadbuffer(state, script, strlen(script), "helloworld");
        if (rst != 0)
        {
            if (lua_isstring(state, -1))// 栈顶是否是字符串
            {
                auto msg = lua_tostring(state, -1);
                printf("load script failed: %s\n", msg);
                lua_pop(state, 1);
            }

            return -1;
        }
        
        if (lua_pcall(state, 0, 0, 0))
        {
            if (lua_isstring(state, -1))// 栈顶是否是字符串
            {
                auto msg = lua_tostring(state, -1);
                printf("call function failed: %s\n", msg);
                lua_pop(state, 1);
            }

            return -1;
        }
    }
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
