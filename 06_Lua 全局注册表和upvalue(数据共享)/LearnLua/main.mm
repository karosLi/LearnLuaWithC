//
//  main.m
//  LearnLua
//
//  Created by karos li on 2022/1/17.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

#include "lua.hpp"
#include "lua_helper.h"
#include "lua_test.h"
#import "loadlib.h"


/**
 int lua_pcall (lua_State *L, int nargs, int nresults, int msgh);
 调用一个函数。

 在C中调用函数需要遵循以下协议：
 1、首先，要调用的函数应该被压入栈；
 2、接着，把需要传递给这个函数的参数按正序压栈； 这是指第一个参数首先压栈。
 3、最后调用一下 lua_pcall 进行实际调用； nargs 是你压入栈的参数个数。 当函数调用完毕后，所有的参数以及函数本身都会出栈。 而函数的返回值这时则被压栈。 返回值的个数将被调整为 nresults 个， 除非 nresults 被设置成 LUA_MULTRET。 在这种情况下，所有的返回值都被压入堆栈中。 Lua 会保证返回值都放入栈空间中。 错误处理函数的索引值必须要在函数压栈之前压入，函数返回值将按正序压栈（第一个返回值首先压栈）， 因此在调用结束后，最后一个返回值将被放在栈顶。
 4、将调用结果从栈中弹出

 */

int main(int argc, char * argv[]) {
    changeCurDirToBundlePath();
    
    lua_State *L = luaL_newstate();
    // 加载lua标准库
    luaL_openlibs(L);
    
    // 加载自己的标准库
    load_stdlibs(L);
    
    // 先加载 lua 配置脚本
    int w,h;
    loadConfig(L, "config.lua", &w, &h);
    
    // 加载 lua 脚本文件
    loadLuaFile(L, "myfunction.lua");
    
    // 通过通用方法，调用 lua 方函数方法
    double r1, r2;
    call_va(L, "f", "dd>dd", 2.0,5.0, &r1, &r2);
    printf("call f function r1:%f r2:%f\n", r1, r2);
    
    // 测试全局注册表
    test_registry(L);
    
    lua_close(L);
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
