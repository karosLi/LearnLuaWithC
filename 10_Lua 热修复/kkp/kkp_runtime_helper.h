//
//  kkp_runtime_helper.h
//  LearnLua
//
//  Created by karos li on 2022/1/28.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

extern void kkp_runtime_swizzleForwardInvocation(Class klass, IMP imp);

extern BOOL kkp_runtime_isMsgForwardIMP(IMP impl);

extern IMP kkp_runtime_getMsgForwardIMP(Class kClass, SEL selector);

extern SEL kkp_runtime_originForSelector(SEL sel);

extern BOOL kkp_runtime_isReplaceByKKP(Class klass, SEL sel);

extern NSString *kkp_runtime_methodTypesInProtocol(NSString *protocolName, NSString *selectorName, BOOL isInstanceMethod, BOOL isRequired);
