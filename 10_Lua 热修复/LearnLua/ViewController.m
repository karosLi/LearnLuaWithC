//
//  ViewController.m
//  LearnLua
//
//  Created by karos li on 2022/1/17.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self doSomeThing];
//    [ViewController printHello];
}

- (void)doSomeThing {
    NSLog(@"ViewController 原始调用 doSomeThing");
}

- (NSString *)getHello {
    return @"ViewController Hello World!";
}

+ (void)printHello {
    NSLog(@"ViewController print in OC %@", @"Hello World!");
}

+ (void)testStatic {
    NSLog(@"ViewController testStatic in OC %@", @"testStatic");
}

@end
