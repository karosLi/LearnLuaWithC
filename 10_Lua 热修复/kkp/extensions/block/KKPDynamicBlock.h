//
//  KKPDynamicBlock.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import <Foundation/Foundation.h>

extern NSString* DyVoidType;
extern NSString* DyCharType;
extern NSString* DyIntType;
extern NSString* DyShortType;
extern NSString* DyLongType;
extern NSString* DyLongLongType;
extern NSString* DyFloatType;
extern NSString* DyDoubleType;
extern NSString* DyBoolType;
extern NSString* DyIdType;
extern NSString* DyPtrType;
extern NSString* DySELType;
extern NSString* DyCGFloatType;

@interface KKPDynamicBlock : NSObject

@property (nonatomic, readonly, copy) id invokeBlock;

- (id)initWithArgsTypes:(NSArray<NSString *> *)types retType:(NSString *)retType replaceBlock:(void *(^)(void** args))replaceBlock;

@end
