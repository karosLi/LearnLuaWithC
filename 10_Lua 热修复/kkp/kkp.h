//
//  kkp.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import <Foundation/Foundation.h>
#import "lua.h"

#define KKP_VERSION 0.01
#define KKP "kkp"

typedef void (*KKPCLibFunction) (lua_State *L);
typedef void (^KKPLuaErrorHanlder)(NSString *error);

#pragma mark - 安装和运行
/// 启动 kkp
extern void kkp_start(KKPCLibFunction extensionCLibFunction);

/// 获取当前状态机
extern lua_State *kkp_currentLuaState(void);

/// 运行 lua 脚本字符串
extern void kkp_runLuaString(const char *script);

/// 运行 lua 脚本文件
extern void kkp_runLuaFile(const char *fname);

/// 运行 lua 脚本字节码
extern void kkp_runLuaByteCode(NSData *data, NSString *name);

#pragma mark - 错误处理
/// 设置 lua runtime 处理器
extern void kkp_setLuaErrorHandler(KKPLuaErrorHanlder handler);
/// 获取 lua runtime  处理器
extern KKPLuaErrorHanlder kkp_getLuaErrorHandler(void);
