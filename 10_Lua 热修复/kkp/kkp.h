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

#pragma mark - 错误处理
/// 设置 lua error 处理器
extern void kkp_setLuaErrorHandler(KKPLuaErrorHanlder handler);
/// 获取 lua error  处理器
extern KKPLuaErrorHanlder kkp_getLuaErrorHandler(void);

#pragma mark - 安装和运行
/// 配置外部库函数
extern void kkp_setExtensionCLib(KKPCLibFunction extensionCLibFunction);

/// 启动 kkp
extern void kkp_start(void);

/// 停止 kkp
extern void kkp_end(void);

/// 重启 kkp
extern void kkp_restart(void);

/// 获取当前状态机
extern lua_State *kkp_currentLuaState(void);

/// 运行 lua 脚本字符串
extern void kkp_runLuaString(NSString *script);

/// 运行 lua 脚本文件
extern void kkp_runLuaFile(NSString *fname);

/// 运行 lua 脚本字节码
extern void kkp_runLuaByteCode(NSData *data, NSString *name);

#pragma mark - 类型 hook 清理

/// 获取 lua error  处理器
extern void kkp_cleanAllClass(void);

/// 获取 lua error  处理器
extern void kkp_cleanClass(NSString *className);
