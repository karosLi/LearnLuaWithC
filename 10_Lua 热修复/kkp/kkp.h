//
//  kkp.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import <Foundation/Foundation.h>
#import "lua.h"

#define KKP_VERSION 0.01
#define KKP @"kkp"

typedef void (*kkp_CLibFunction) (lua_State *L);
typedef void (^kkp_log_block_t)(NSString *log);
typedef void (^kkp_complete_block_t)(BOOL complete, NSString *log);

/// 获取当前状态机
extern lua_State *kkp_currentLuaState(void);

/// 设置日志回调
extern void kkp_setLogCallback(kkp_log_block_t callback);
/// 获取日志回调
extern kkp_log_block_t kkp_getLogCallback(void);

/// 设置方法交换的回调
extern void kkp_setSwizzleCallback(kkp_complete_block_t callback);
/// 获取方法交换的回调
extern kkp_complete_block_t kkp_getSwizzleCallback(void);

/// 设置完成回调
extern void kkp_setCompleteCallback(kkp_complete_block_t callback);
/// 获取完成回调
extern kkp_complete_block_t kkp_getCompleteCallback(void);

/// 启动 kkp
extern void kkp_start(kkp_CLibFunction extensionCLibFunction);

/// 运行 lua 脚本字符串
extern void kkp_runLuaString(const char *script);

/// 运行 lua 脚本文件
extern void kkp_runLuaFile(const char *fname);

/// 运行 lua 脚本字节码
extern void kkp_runLuaByteCode(NSData *data, NSString *name);
