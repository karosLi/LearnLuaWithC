//
//  kkp_converter.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import <Foundation/Foundation.h>
#import "lua.h"

/// 根据 Class 字符串拼接的方法签名, 构造真实方法签名
/// @param signatureStr 字符串参数类型 例'void,NSString*'
/// @param isBlock 是否构造block签名
extern NSString *kkp_create_real_signature(NSString *signatureStr, bool isBlock);

extern void * kkp_toOCObject(lua_State *L, const char * typeDescription, int index);
extern int kkp_toLuaObject(lua_State *L, id object);
extern int kkp_toLuaObjectWithBuffer(lua_State *L, const char * typeDescription, void *buffer);
