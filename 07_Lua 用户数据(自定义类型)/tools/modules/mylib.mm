//
//  mylib.m
//  LearnLua
//
//  Created by karos li on 2022/1/20.
//

#import "mylib.h"

#include <dirent.h>
#include <errno.h>
#include "lua_helper.h"

/**
 
 提供给 lua 调用的 c 函数原型
 Type for C functions registered with Lua

 typedef int (*lua_CFunction) (lua_State *L);
 */

/// 提供给 lua 调用的 l_f c 函数
/// 输入两个double，返回两个double
static int l_f(lua_State *L)
{
    double arg1 = luaL_checknumber(L, 1);// 获取栈中索引1位置的值，如果获取失败内部会把错误信息压入栈顶
    double arg2 = luaL_checknumber(L, 2);// 获取栈中索引2位置的值，如果获取失败内部会把错误信息压入栈顶
    double r1 = pow(arg1, 2);
    double r2 = arg1 + arg2;
    
    lua_pushnumber(L, r1);// 把结果压入栈顶
    lua_pushnumber(L, r2);// 把结果压入栈顶
    
    return 2;// 返回结果的数量
}

/// 提供给 lua 调用的 l_dir c 函数
/// 输入一个path参数，返回一个table，如果有错误时，返回nil和错误消息
static int l_dir(lua_State *L)
{
    DIR *dir;
    struct dirent *entry;
    int i;
    const char *path = luaL_checkstring(L, 1);
    
    // 打开目录
    dir = opendir(path);
    if (dir == NULL) {// 打开失败
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;// 返回结果的数量
    }
    
    // 创建空表并压入栈顶
    lua_newtable(L);
    i = 1;
    while ((entry = readdir(dir)) != NULL) {
        lua_pushnumber(L, i++);// 压入key
        lua_pushstring(L, entry->d_name);// 压入value
        lua_settable(L, -3);// 给指定索引上的table设置key，value，设置完成后，弹出 key 和 value，最后就是 table 在栈顶上
    }
    
    closedir(dir);
    return 1;// 返回结果的数量
}

/// 提供给 lua 调用的 l_map c 函数
/// 输入table普通数组和map函数，返回0个结果
static int l_map(lua_State *L)
{
    int i,n;
    // 第一个参数必须是table
    luaL_checktype(L, 1, LUA_TTABLE);
    // 第二个参数必须是函数
    luaL_checktype(L, 2, LUA_TFUNCTION);
    
    // 获取table的长度
    n = (int)lua_rawlen(L, 1);
    
    for (i = 1; i <= n; i++) {
        // 再次压入函数，因为调用完后函数和参数都出出栈，如果直接调用函数，那就找不到传入的函数了
        lua_pushvalue(L, 2);
        // 因为是普通数组table，所以键都是整形（从1开始），这里是获取table中的值 t[i] 并压入栈顶
        lua_rawgeti(L, 1, i);
        // lua_call 与 lua_pcall 的区别是，不能设置错误处理函数
        // 因为map函数入参是1个，返回也是1个，调用完后，函数和入参会出栈，结果会放入栈顶
        lua_call(L, 1, 1);
        // 把栈顶的结果更新到table数组里，并把结果弹出栈
        lua_rawseti(L, 1, i);
    }
    
    return 0;
}

/// 提供给 lua 调用的 l_foo c 函数
/// 输入多个浮点型参数，返回2个结果，结果1是所有入参相加后的平均数，结果2是所有入参的和
static int l_foo(lua_State *L)
{
   int n = lua_gettop(L);    /* 参数的个数 */
   lua_Number sum = 0.0;
   int i;
   for (i = 1; i <= n; i++) {
       if (!lua_isnumber(L, i)) {
           lua_pushliteral(L, "incorrect argument");// 压入一个错误字面量
           lua_error(L);// 以栈顶的值作为错误对象，抛出一个 Lua 错误
       }
       sum += lua_tonumber(L, i);
   }
   lua_pushnumber(L, sum/n);        /* 第一个返回值 */
   lua_pushnumber(L, sum);         /* 第二个返回值 */
   return 2;                   /* 返回值的个数 */
}

/// 提供给 lua 调用的 l_str_upper c 函数
/// 输入一个字符串，返回全部是大写的字符串
static int l_str_upper(lua_State *L)
{
    size_t l, i;
    luaL_Buffer b;// lua 提供给 c 使用的字符串缓冲
    
    // 获取入参字符串和字符串长度
    const char *s = luaL_checklstring(L, 1, &l);
//    luaL_buffinit(L, &b); // 不知道字符串长度
    luaL_buffinitsize(L, &b, l);// 知道字符串长度
    for (i = 0; i < l; i++) {
        luaL_addchar(&b, toupper(s[i]));
    }
    
//    luaL_pushresult(&b);// 不知道字符串长度
    luaL_pushresultsize(&b, l);// 知道字符串长度
    
    return 1;
}

/// 提供给 lua 调用的 l_str_split c 函数，用于分割字符串
/// 输入两个字符串，第一个是源字符串，第二个是分隔符
static int l_str_split(lua_State *L)
{
    const char *s = luaL_checkstring(L, 1);
    const char *sep = luaL_checkstring(L, 2);
    const char *e;// 保存查找到分隔符的字符指针
    int i = 1;// 普通数组的键值就是从1开始的数字
    
    lua_newtable(L); // 创建空表并压入栈顶
    
    // 遍历所有分隔符
    while ((e = strchr(s, *sep)) != NULL) {
        size_t l = e - s;// 两个字符指针保存的字符地址相减，得到的就是分隔符之前的字符长度
        lua_pushlstring(L, s, l);// 压入子串
        lua_rawseti(L, -2, i++);// 把子串设置到table里
        s = e + 1; // 跳过分隔符
    }
    
    // 压入最后一个子串
    lua_pushstring(L, s);
    lua_rawseti(L, -2, i);// 把子串设置到table里
    
    return 1;// 现在栈顶是table，返回结果数量只有一个
}

/// 声明 计数器 函数
static int counter(lua_State *L)
{
    // 获取 upvalue 索引
    int upvalue_index = lua_upvalueindex(1);
    // 获取 upvalue
    lua_Integer val = lua_tointeger(L, upvalue_index);
    // 压入 新值
    lua_pushinteger(L, ++val);
    // 复制新值到栈顶，因为 replace 会把栈顶出栈，所以这里需要复制
    lua_pushvalue(L, -1);
    // 把栈顶的值放入 upvalue 索引，这样 upvalue 就被更新了。
    lua_replace(L, upvalue_index);
    
    return 1;// 返回的结果数量
}

/// upvalue 作用：用于在多个闭包间共享数据
/// upvalue 规则：比如在压入闭包之前，先压入值，然后再压入闭包的时候，需要指定 upvalue 的数量
/// 函数和闭包的区别：函数就是不会捕获变量的方法。闭包就是会捕获变量的方法
static int l_newCounter(lua_State *L)
{
    lua_pushinteger(L , 0); // 把 0 压入栈顶，0 是作为 upvalue 的初始值
    lua_pushcclosure(L, counter, 1);  // 压入闭包， 第二个参数是函数地址，第三个参数是upvalue的数量，也就是需要捕获到的变量数量
    return 1; // 栈顶是函数，所以返回结果是1
}

/// 用 upvalue 来实现元组，用于获取元组中对应索引的值
static int tuple(lua_State *L)
{
    lua_Integer op = luaL_optinteger(L, 1, 0); // 获取第一个入参的整形值，如果没有，就使用默认值 0
    
    if (op == 0) {// 说明没有参数
        int i;
        // 将所有合法的 upvalue 压入栈中
        for (i = 1; !lua_isnone(L, lua_upvalueindex(i)); i++) {
            lua_pushvalue(L, lua_upvalueindex(i));
        }
        
        return i - 1; // 返回栈中值的数量
    } else {// 获取 op 字段
        luaL_argcheck(L, 0 < op, 1, "index out of range");// 检查第一个参数是否有效，无效就报错。报错格式 bad argument #arg to 'funcname' (extramsg)
        
        if (lua_isnone(L, lua_upvalueindex((int)op))) {// 没有此字段
            return 0;
        }
        
        lua_pushvalue(L, lua_upvalueindex((int)op));// 把 op 指定的 upvalue 压入栈中，作为返回结果
        return 1;
    }
}

/// 创建元组
static int l_newTuble(lua_State *L)
{
    // 把所有入参的数量当做upvalue的数量
    lua_pushcclosure(L, tuple, lua_gettop(L));
    return 1;
}

static const struct luaL_Reg mylib[] = {
    {"c_f", l_f},
    {"c_dir", l_dir},
    {"c_map", l_map},
    {"c_foo", l_foo},
    {"c_upper", l_str_upper},
    {"c_split", l_str_split},
    {"c_newCounter", l_newCounter},
    {"c_newTuple", l_newTuble},
    {NULL, NULL}
};

/// lua c 标准库提供了统一注册 c 函数的方法
/// // 函数名必须为luaopen_xxx，其中xxx表示library名称。Lua代码require "xxx"需要与之对应。
LUAMOD_API int luaopen_mylib(lua_State *L)
{
    luaL_newlib(L, mylib);// 1、创建空table并压入栈顶 2、把所有函数都设置到栈顶的table里
//    const char* libName = "mylib";
    
    // 方法1，把栈顶table设置为名字为 mylib 全局变量，这样的话 mylib 模块不需要require也可以使用，不是真的按需加载，更好的方式是设置 package.preload["mylib"] = table
//    lua_setglobal(L,libName);
    
    // 方法2，没有起作用
//    lua_getglobal(L, "package");// 把 package 压入栈顶
//    lua_getfield(L, -1, "preload");// 把 preload 压入栈顶
//    int preloadIdx = lua_gettop(L);
//    lua_pushvalue(L, -3);// 压入value：table
//    lua_setfield(L, preloadIdx, libName);
//    stackDump(L);
//    lua_pop(L, 2);
    
    return 1;
}
