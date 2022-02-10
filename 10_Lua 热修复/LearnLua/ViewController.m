//
//  ViewController.m
//  LearnLua
//
//  Created by karos li on 2022/1/17.
//

#import "ViewController.h"
#import <objc/runtime.h>

@interface ViewController ()

@property(nonatomic, assign) NSInteger age;
@property(nonatomic, strong) UIButton *gotoButton;

@end

@implementation ViewController

- (instancetype)init {
    self = [super init];
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self.navigationController pushViewController:[UIViewController new] animated:YES];
    
    [self setup];
    [self doSomeThing];
//    [ViewController printHello];
    NSLog(@"ViewController 年龄 %zd", self.age);
}

- (void)setup {
    _gotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_gotoButton setTitle:@"跳转" forState:UIControlStateNormal];
    [_gotoButton addTarget:self action:@selector(onClickGotoButton) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.gotoButton];
    self.gotoButton.frame = CGRectMake(100, 200, 100, 40);
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

- (void)onClickGotoButton {
//    self.navigationController
    
//    self.view
}

@end
