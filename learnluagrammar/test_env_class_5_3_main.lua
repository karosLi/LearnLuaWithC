require("test_env_class_5_3_module")

print("_G", _G)
print("_ENV", _ENV)
local data,scope = class("main")
local _ENV = scope
print("_ENV", _ENV)
b = 1 -- 全局变量在 _ENV 里，因为前面修改了 _ENV 环境
local c = 2 -- 局部变量不在 _ENV 和 _G 里

function a() -- 全局函数在 _ENV 里，因为前面修改了 _ENV 环境
  print("a")
end

print("class_name", self.class_name)
print("======")
print("a", a) -- a == _ENV.a
print("_ENV.a", _ENV.a)
print("_G.a", _G.a)
print("======")
print("b", b) -- b == _ENV.b
print("_ENV.b", _ENV.b)
print("_G.b", _G.b)
print("======")
print("c", c) -- c != _ENV.c 且 c != _G.c 
print("_ENV.c", _ENV.c)
print("_G.c", _G.c)
print("======")
