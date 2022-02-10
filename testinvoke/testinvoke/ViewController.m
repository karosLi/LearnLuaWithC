//
//  ViewController.m
//  testinvoke
//
//  Created by karos li on 2022/2/10.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import "AAViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    printf("=== %c", @encode(char)[0]);
//    self.navigationController
    id a = [super performSelector:NSSelectorFromString(@"navigationController")];
    id bb = self.navigationController;
    
//    UICollectionView *cc = [[UICollectionView alloc] init];
    
    Class klass = object_getClass(self);
    SEL sel = NSSelectorFromString(@"navigationController");
    NSMethodSignature *signature = [klass instanceMethodSignatureForSelector:sel];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = self;
    invocation.selector = sel;
    [invocation invoke];
    
    
//     id object = nil;
//    [invocation getReturnValue:&object];
    
    void *buffer = calloc(1, 1);
    [invocation getReturnValue:buffer];
    NSLog(@"");
    
    [self.navigationController pushViewController:[AAViewController new] animated:YES];
}


@end
