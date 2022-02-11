//
//  KKPBlockInstance.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import <Foundation/Foundation.h>
#import "lua.h"

@interface KKPBlockInstance : NSObject

-(void (^)(void))voidBlock;
- (id)blockWithParamsTypeArray:(NSArray *)paramsTypeArray returnType:(NSString *)returnType;

@end
