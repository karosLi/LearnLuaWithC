//
//  ViewController.m
//  LearnLua
//
//  Created by karos li on 2022/1/17.
//

#import "ViewController.h"
#import <objc/runtime.h>

@interface ViewController () {
    NSInteger _aInteger;
}

@property(nonatomic, assign) NSInteger age;
@property(nonatomic, strong) UIButton *gotoButton;

@property (nonatomic) int index;

@end

@implementation ViewController

- (instancetype)init {
    self = [super init];
    _aInteger = 0;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setup];
    [self doSomeThing:@"做饭"];
    NSLog(@"ViewController 年龄 %zd", self.age);
    
    [self blockOneArg:^int(int i) {
        return i;
    }];
    NSLog(@"ViewController blockOneArg 期望的 index 是 12，目前 index 是 %d", self.index);
    NSLog(@"ViewController 私有变量 _aInteger %ld", _aInteger);
    
    NSString *value = [self blockReturnBoolWithString](@"xxx");
    NSLog(@"");
}

- (void)setup {
    _gotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_gotoButton setTitle:@"跳转" forState:UIControlStateNormal];
    [_gotoButton addTarget:self action:@selector(onClickGotoButton) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.gotoButton];
    self.gotoButton.frame = CGRectMake(100, 200, 100, 40);
}

- (void)doSomeThing:(NSString *)thingName {
    NSLog(@"ViewController 原始调用 doSomeThing %@", thingName);
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

- (void)onClickGotoButton {
}

/// lua 脚本 hook 这个方法
- (void)blockOneArg:(int(^)(int i))block {
     self.index = block(11);
}

/// lua 脚本 hook 这个方法，并由 lua 返回 一个 oc block
- (NSString *(^)(NSString *))blockReturnBoolWithString {
    return ^(NSString *arg1){
        return @"hh";
    };
}

@end
