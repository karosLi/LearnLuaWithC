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
extern NSString *kkp_create_real_method_signature(NSString *signatureStr, bool isBlock);

/// 根据 Class 字符串拼接的参数签名, 构造真实参数签名。目前用于构造结构体的真实参数签名
/// @param signatureStr 字符串参数类型 例'CGFloat,CGFloat'
extern NSString *kkp_create_real_argument_signature(NSString *signatureStr);

extern void * kkp_toOCObject(lua_State *L, const char * typeDescription, int index);
extern int kkp_toLuaObject(lua_State *L, id object);
extern int kkp_toLuaObjectWithBuffer(lua_State *L, const char * typeDescription, void *buffer);

/// 根据类型描述，计算出结构体占用的字节大小
extern int kkp_sizeOfStructTypes(const char *typeDescription);
/// 把结构体字典里的数据往结构体指针指向的内存里填充
extern void kkp_getStructDataOfDict(void *structData, NSDictionary *structDict, NSDictionary *structDefine);
/// 把结构体字指针指向的内存数据转换成字典
extern NSDictionary *kkp_getDictOfStructData(void *structData, NSDictionary *structDefine);
