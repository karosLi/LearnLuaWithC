//
//  kkp_define.h
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#ifndef kkp_define_h
#define kkp_define_h

/// 自定义用户数据，类 和 实例对象都会用到
typedef struct _KKPInstanceUserdata {
    __weak id instance;// 如果是类用户数据，代表的是 class；如果是实例用户数据，代表的是 实例
    bool isClass;
    bool isSuper;// 是否调用父类方法
    bool isBlock;
} KKPInstanceUserdata;

#define KKP_ENV_SCOPE @"_SCOPE" // 用于保存 lua 中的 _ENV 当前环境
#define KKP_ENV_SCOPE_SELF @"self"// 用于在 lua 函数中，使用 self 关键字
#define KKP_SUPER_KEYWORD @"super"
#define KKP_ORIGIN_KEYWORD @"origin"

#define KKP_ORIGIN_PREFIX @"ORIG"
#define KKP_SUPER_PREFIX @"SUPER"
#define KKP_STATIC_PREFIX @"STATIC"
#define KKP_ORIGIN_FORWARD_INVOCATION_SELECTOR_NAME @"__kkp_origin_forwardInvocation:"


#endif /* kkp_define_h */
