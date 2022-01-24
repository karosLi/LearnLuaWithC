print("===table===")
local tab1 = { key1 = "val1", key2 = "val2"}
for k, v in pairs(tab1) do
    print(k .. " - " .. v)
end

tab1.key1 = nil
for k, v in pairs(tab1) do
    print("update " .. k .. " - " .. v)
end

-- 不同于其他语言的数组把 0 作为数组的初始索引，在 Lua 里表的默认初始索引一般以 1 开始。
local tbl = {"apple", "pear", "orange", "grape"}
for key, val in pairs(tbl) do
    print("Key", key)
end

print("===数据类型===")
print(type(true))
print(type(false))
print(type(nil)=="nil")

if false or nil then
    print("至少有一个是 true")
else
    print("false 和 nil 都为 false")
end

if 0 then
    print("数字 0 是 true")
else
    print("数字 0 为 false")
end
len = "www.runoob.com"
print("字符串长度" .. #len)


print("===函数===")
-- 函数作为参数
function testFun(tab,fun)
  for k ,v in pairs(tab) do
      print(fun(k,v));
  end
end

local tab={key1="val1",key2="val2"};
testFun(tab, function(key,val)--匿名函数
    return key.."="..val;
  end
);

--[[ 函数返回两个值的最大值 --]]
function max(num1, num2)

   if (num1 > num2) then
      result = num1;
   else
      result = num2;
   end

   return result;
end
-- 调用函数
print("两值比较最大值为 ",max(10,4))
print("两值比较最大值为 ",max(5,6))

-- 返回多值
function maximum (a)
    local mi = 1             -- 最大值索引
    local m = a[mi]          -- 最大值
    for i,val in ipairs(a) do
       if val > m then
           mi = i
           m = val
       end
    end
    return m, mi
end
local r1,r2 = maximum({8,10,23,12,5})
print("返回多值", r1, r2)

--变长参数
function add(...)
local s = 0
  for i, v in ipairs{...} do   --> {...} 表示一个由所有变长参数构成的table
    s = s + v
  end
  return s
end
print(add(3,4,5,6,7))  --->25

-- 将可变参数赋值给一个变量
function average(...)
   result = 0
   local arg={...}    --> arg 为一个表，局部变量
   for i,v in ipairs(arg) do
      result = result + v
   end
   print("总共传入 " .. #arg .. " 个数")
   return result/#arg
end
print("平均值为",average(10,5,3,4,5,6))

-- 固定的参数+可变参数
function fwrite(fmt, ...)  ---> 固定的参数fmt
    return io.write(string.format(fmt, ...))    
end
fwrite("runoob\n")       --->fmt = "runoob", 没有变长参数。
fwrite("%d%d\n", 1, 2)   --->fmt = "%d%d", 变长参数为 1 和 2

-- select('#', ...) 返回可变参数的长度。
-- select(n, ...) 用于返回从起点 n 开始到结束位置的所有参数列表。
-- arg = select(n, ...) 只是接收了第一个参数，因为一个变量对应多返回值时，只取第一个返回值
function f(...)
    a = select(3,...)  -->从第三个位置开始，变量 a 对应右边变量列表的第一个参数
    print (a)
    print (select(3,...)) -->打印所有列表参数
end
f(0,1,2,3,4,5)


print("===变量===")
local x, y = 1, 2
x, y = y, x
print("x", x)
print("y", y)

print("===流程控制===")
--[ 0 为 true ]
if(0)
then
    print("0 为 true")
end

print("===字符串===")
-- string.gsub(mainString,findString,replaceString,num)
-- 在字符串中替换。
-- mainString 为要操作的字符串， findString 为被替换的字符，replaceString 要替换的字符，num 替换次数（可以忽略，则全部替换），如：
print(string.gsub("aaaa","a","z",3));

for word in string.gmatch("Hello Lua user", "%a+") do print(word) end

print(string.match("I have 2 questions for you.", "%d+ %a+"))


print("===数组===")
array = {"Lua", "Tutorial"}

for i= 0, 2 do
   print(array[i])
end

-- 以负数为数组索引值
array = {}

for i= -2, 2 do
   array[i] = i *2
end

for i = -2,2 do
   print(array[i])
end

-- 不同索引键的三行三列阵列多维数组：
-- 初始化数组
array = {}
maxRows = 3
maxColumns = 3
for row=1,maxRows do
   for col=1,maxColumns do
      array[row*maxColumns +col] = row*col
   end
end

-- 访问数组
for row=1,maxRows do
   for col=1,maxColumns do
      print(array[row*maxColumns +col])
   end
end

print("===迭代器===")
array = {"Google", "Runoob"}
for key,value in ipairs(array)
do
   print(key, "=",value)
end
-- 无状态的迭代器
function square(iteratorMaxCount,currentNumber)
   if currentNumber<iteratorMaxCount
   then
      currentNumber = currentNumber+1
   return currentNumber, currentNumber*currentNumber
   end
end
for i,n in square,3,0
do
   print("无状态的迭代器", i,n)
end

-- 当 Lua 调用 ipairs(a) 开始循环时，他获取三个值：迭代函数 iter、状态常量 a、控制变量初始值 0；然后 Lua 调用 iter(a,0) 返回 1, a[1]（除非 a[1]=nil）；第二次迭代调用 iter(a,1) 返回 2, a[2]……直到第一个 nil 元素。
function iter (a, i)
    i = i + 1
    local v = a[i]
    if v then
       return i, v
    end
end
function ipairs1 (a)
    return iter, a, 0
end
array = {"Google", "Runoob"}
for i, v in ipairs1(array)
do
  print("迭代器的通用实现", i,v)
end

-- 多状态的迭代器
array = {"Google", "Runoob"}
function elementIterator (collection)
   local index = 0
   local count = #collection
   -- 闭包函数
   return function ()
      index = index + 1
      if index <= count
      then
         --  返回迭代器的当前元素
         return collection[index]
      end
   end
end

for element in elementIterator(array)
do
   print("多状态的迭代器", element)
end

print("===模块===")
require("module")
print("模块", module.constant)
module.func3()
-- 别名变量 m
local m = require("module")
print("模块", m.constant)
m.func3()

print("===错误处理===")
local function add(a,b)
   assert(type(a) == "number", "a 不是一个数字")
   assert(type(b) == "number", "b 不是一个数字")
   return a+b
end
-- add(10)

print("===垃圾回收===")
-- collectgarbage("collect"): 做一次完整的垃圾收集循环。通过参数 opt 它提供了一组不同的功能：

-- collectgarbage("count"): 以 K 字节数为单位返回 Lua 使用的总内存数。 这个值有小数部分，所以只需要乘上 1024 就能得到 Lua 使用的准确字节数（除非溢出）。

-- collectgarbage("restart"): 重启垃圾收集器的自动运行。

-- collectgarbage("setpause"): 将 arg 设为收集器的 间歇率。 返回 间歇率 的前一个值。

-- collectgarbage("setstepmul"): 返回 步进倍率 的前一个值。

-- collectgarbage("step"): 单步运行垃圾收集器。 步长"大小"由 arg 控制。 传入 0 时，收集器步进（不可分割的）一步。 传入非 0 值， 收集器收集相当于 Lua 分配这些多（K 字节）内存的工作。 如果收集器结束一个循环将返回 true 。

-- collectgarbage("stop"): 停止垃圾收集器的运行。 在调用重启前，收集器只会因显式的调用运行。
mytable = {"apple", "orange", "banana"}

print(collectgarbage("count"))

mytable = nil

print(collectgarbage("count"))

print(collectgarbage("collect"))

print(collectgarbage("count"))


print("===面向对象===")
-- 这个定义创建了一个新的函数，并且保存在Account对象的withdraw域内，下面我们可以这样调用：
Account = {balance = 0}
function Account.withdraw (v)
    Account.balance = Account.balance - v
end
Account.withdraw(100.00)
print("面向对象", Account.balance)

-- Lua 查找一个表元素时的规则，其实就是如下 3 个步骤:
-- 1.在表中查找，如果找到，返回该元素，找不到则继续
-- 2.判断该表是否有元表，如果没有元表，返回 nil，有元表则继续。
-- 3.判断元表有没有 __index 方法，如果 __index 方法为 nil，则返回 nil；如果 __index 方法是一个表，则重复 1、2、3；如果 __index 方法是一个函数，则返回该函数的返回值。

-- 元类
Rectangle = {area = 0, length = 0, breadth = 0}
-- 派生类的方法 new
function Rectangle:new (o,length,breadth)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  self.length = length or 0
  self.breadth = breadth or 0
  self.area = length*breadth;
  return o
end
-- 派生类的方法 printArea
function Rectangle:printArea ()
  print("矩形面积为 ",self.area)
end
r = Rectangle:new(nil,10,20)
print("面向对象", r.length)
r:printArea()

print("===面向对象-继承===")
-- Meta class
Shape = {area = 0}
-- 基础类方法 new
function Shape:new (o,side)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  side = side or 0
  self.area = side*side;
  return o
end
-- 基础类方法 printArea
function Shape:printArea ()
  print("面积为 ",self.area)
end

-- 创建对象
myshape = Shape:new(nil,10)
myshape:printArea()

Square = Shape:new()
-- 派生类方法 new
function Square:new (o,side)
  o = o or Shape:new(o,side)
  setmetatable(o, self)
  self.__index = self
  return o
end

-- 派生类方法 printArea，重写
function Square:printArea ()
  print("正方形面积为 ",self.area)
end

-- 创建对象
mysquare = Square:new(nil,10)
mysquare:printArea()

Rectangle = Shape:new()
-- 派生类方法 new
function Rectangle:new (o,length,breadth)
  o = o or Shape:new(o)
  setmetatable(o, self)
  self.__index = self
  self.area = length * breadth
  return o
end

-- 派生类方法 printArea
function Rectangle:printArea ()
  print("矩形面积为 ",self.area)
end

-- 创建对象
myrectangle = Rectangle:new(nil,10,20)
myrectangle:printArea()

print("===环境ENV===")
local env = require("test_env")

print("env:             ", env)
print("test_env:        ", test_env)
print("_G.test_env:     ", _G.test_env)

print("env.local_var            = nil           result:", env.local_var)
print("env.global_var           = global_var    result:", env.global_var)       -- 这里的 global_var 其实是 _G.global_var

print("_G.global_var            = global_var    result:", _G.global_var)

print("_G.env_local_var        = nil           result:", _G.env_local_var)
print("_G.env_global_var       = nil           result:", _G.env_global_var)

print("test_env.env_local_var   = nil           result:", test_env.env_local_var)           -- 这里是 _G.test_env.env_local_var
print("test_env.env_global_var  = env_global_var result:", test_env.env_global_var)         -- 这里是 _G.test_env.env_local_var  如果test_env.lua中 test_env 变量前面加上 local 这里就不能这么用
