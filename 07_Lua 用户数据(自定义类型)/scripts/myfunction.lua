-- require 的搜索路径
-- cannot run config. file: myfunction.lua:10: module 'mylib' not found:
--     no field package.preload['mylib']
--     no file '/usr/local/share/lua/5.4/mylib.lua'
--     no file '/usr/local/share/lua/5.4/mylib/init.lua'
--     no file '/usr/local/lib/lua/5.4/mylib.lua'
--     no file '/usr/local/lib/lua/5.4/mylib/init.lua'
--     no file './mylib.lua'
--     no file './mylib/init.lua'
--     no file '/usr/local/lib/lua/5.4/mylib.so'
--     no file '/usr/local/lib/lua/5.4/loadall.so'
--     no file './mylib.so'

function print_table(table)
    for k, v in pairs(table) do
        print(k .. " - " .. v)
    end
end

require("config")
print("background color", background.r, background.g, background.b)

-- 提供lua函数给到c调用
-- f 函数用于计算 x,y 并返回两个值
function f(x, y)
    local r1 = x^2
    local r2 = x + 7
    return r1, r2
end

-- lua函数调用c函数
local util = require("mylib.util")
local r1,r2 = util.c_f(2.0, 5.0);
print("调用c函数util.c_f", r1,r2)

local str = "abcd"
local upper_str = util.c_upper(str)
print("调用c函数util.c_upper", upper_str)

local str1 = "ab.cd.r"
local split_array = util.c_split(str1, ".")
print("调用c函数util.c_split后")
print_table(split_array)

local array = {"1", "2", "3", "4"}
util.c_map(array, function(e)
    return "map " .. e
end
)
print("调用c函数util.c_map调用后")
print_table(array)

-- 创建2个计数器闭包
local counter_closure1 = util.c_newCounter()
local counter_closure2 = util.c_newCounter()
print("调用c函数counter_closure1", counter_closure1())
print("调用c函数counter_closure1", counter_closure1())
print("调用c函数counter_closure2", counter_closure2())
print("调用c函数counter_closure1", counter_closure1())
print("调用c函数counter_closure2", counter_closure2())


-- 元组
local tuple = util.c_newTuple(10, "dd", 3.0)
print("调用c函数c_newTuple tuple(1)", tuple(1))
print("调用c函数c_newTuple tuple(2)", tuple(2))
print("调用c函数c_newTuple tuple(3)", tuple(3))
print("调用c函数c_newTuple tuple()", tuple())


-- 自定义类型bitarray
local bit_array = require("mylib.bitarray")
local array_a = bit_array.new(1000)
bit_array.set(array_a, 10, true)
print("调用c函数mylib.bitarray相关方法", bit_array.get(array_a, 10))
