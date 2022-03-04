//
//  kkp_converter.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import <Foundation/Foundation.h>
#import "lua.h"

/// 根据类型的可读性字符串签名, 构造真实签名
/// @param signatureStr 字符串参数类型 例'void,NSString*'
/// @param isAllArg 是否所有类型都是参数类型，不是的话，就需要把第一个类型当做返回值类型
/// @param isBlock 是否构造block签名
extern NSString *kkp_create_real_signature(NSString *signatureStr, BOOL isAllArg, BOOL isBlock);

/// 根据原生结构体的类型签名转成数组 [结构体名字，真实签名]
/// 比如：{CGSize=dd} 转成 CGSize=dd
/// 比如：嵌套 {XRect={XPoint=ii}ff} 转成  XRect=iiff
NSString * kkp_parseStructFromTypeDescription(NSString *typeDes, BOOL needStructName, NSString *replaceRightBracket);

extern void * kkp_toOCObject(lua_State *L, const char * typeDescription, int index);
extern int kkp_toLuaObject(lua_State *L, id object);
extern int kkp_toLuaObjectWithBuffer(lua_State *L, const char * typeDescription, void *buffer);

/// 根据类型描述，计算出结构体占用的字节大小
extern int kkp_sizeOfStructTypes(const char *typeDescription);
/// 把结构体字典里的数据往结构体指针指向的内存里填充
extern void kkp_getStructDataOfDict(void *structData, NSDictionary *structDict, NSDictionary *structDefine);
/// 把结构体字指针指向的内存数据转换成字典
extern NSDictionary *kkp_getDictOfStructData(void *structData, NSDictionary *structDefine);
