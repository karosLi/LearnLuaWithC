//
//  BitArray.m
//  LearnLua
//
//  Created by karos li on 2022/1/24.
//

#import "bit_array.h"
#include<limits.h>

#define BITS_PER_WORD (CHAR_BIT * sizeof(unsigned int)) //unsigned int 的位长
#define I_WORD(i) ((unsigned int) (i) / BITS_PER_WORD) //计算需要的word数
#define I_BIT(i) (1 << ((unsigned int)(i) % BITS_PER_WORD)) //得到访问某个位的mask
#define checkarray(L) (BitArray *)luaL_checkudata(L, 1, "BooleanArray") //从注册表中得到元表,并和栈上元素的元表做对比

typedef struct BitArray {
  int size;
  unsigned int values [1];
} BitArray;

static int newarray (lua_State *L) {
  int i;
  size_t nbytes;
  BitArray *a;

  int n = (int)luaL_checkinteger(L, 1);
  luaL_argcheck(L, n >= 1, 1, "invalid size"); //参数检测
  nbytes = sizeof(BitArray) + I_WORD(n - 1) * sizeof(unsigned int); //需要的字节数
  a = (BitArray*)lua_newuserdata(L, nbytes); //新建userdata

  a->size = n;
    for (i = 0; i <= I_WORD(n - 1); i++)
      a->values[i] = 0; //初始化为0

  /**
     给userdata设置元表的目的是为了做一个标记，防止 lua 脚本传入其他的userdata指针
  */
  luaL_getmetatable(L, "BooleanArray"); //从注册表获取元表，并压栈
  lua_setmetatable(L, -2); //给userdata对象设置元表

  return 1; //userdata已经在栈上了
}

static unsigned int *getindex (lua_State *L, unsigned int *mask) {
  BitArray *a = checkarray(L);
  int index = (int)luaL_checkinteger(L, 2) - 1;//获取index
  luaL_argcheck(L, 0 <= index && index < a->size, 2, "index out of range");// 参数检查

  *mask = I_BIT(index); //获取mask
  return &a->values[I_WORD(index)]; //返回数组索引
}

static int setarray (lua_State *L) {
  unsigned int mask;
  unsigned int *entry = getindex(L, &mask);
  luaL_checkany(L, 3);
  if (lua_toboolean(L, 3))
    *entry |= mask;
  else
    *entry &= ~mask;
  return 0;
}

static int getarray (lua_State *L) {
  unsigned int mask;
  unsigned int *entry = getindex(L, &mask);
  lua_pushboolean(L, *entry & mask);
  return 1;
}

static int getsize(lua_State *L) {
  BitArray *a = checkarray(L);
  lua_pushinteger(L, a->size);
  return 1;
}

static int array2string (lua_State *L) {
  BitArray * a = checkarray(L);
  lua_pushfstring(L, "array(%d)", a->size);
  return 1;
}

static const struct luaL_Reg arraylib_f [] = {
    {"new", newarray},
    {"set", setarray},
    {"get", getarray},
    {"size", getsize},
    {NULL, NULL},
};

LUAMOD_API int luaopen_array (lua_State *L) {
  luaL_newmetatable(L, "BooleanArray"); //新建一个元表,并注册到注册表中
  luaL_newlib(L, arraylib_f); //新建库
  return 1;
}

