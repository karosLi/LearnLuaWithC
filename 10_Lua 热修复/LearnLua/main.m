//
//  main.m
//  LearnLua
//
//  Created by karos li on 2022/1/17.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#include "kkp.h"

int main(int argc, char * argv[]) {
    // 启动
    kkp_start(nil);
    
    // 执行测试脚本
    kkp_runLuaFile("test.lua");
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
