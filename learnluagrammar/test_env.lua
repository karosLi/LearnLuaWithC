local local_var = "local_var"           -- 该变量为该模块的局部变量
global_var = "global_var"               -- 该变量为全局变量注册在 _G 中
-- print("_ENV.local_var:", _ENV.local_var)     -- 这句证明 local 变量不存在于 _ENV 中

test_env = {}       -- 如果这里设为 local 则不能在 require 一次后在其他文件中直接调用 test_env 后面会说明
setmetatable(test_env, {__index = _G})  -- 设置 _G 是为了使用 print 函数还有验证上面的 global_var
_ENV = test_env                         -- 改变当前环境

local env_local_var = "env_local_var"
env_globar_var = "env_global_var"       -- 注意这里不是存在 _G 而是在 _ENV

print("local_var:",             local_var)
print("global_var:",            global_var)

print("env_local_var:",         env_local_var)
print("env_global_var:",        env_global_var)

print("test_env:",              test_env)
print("_G:",                    _G)

print("_G.local_var         = nil           result:", _G.local_var)
print("_G.global_var        = global_var    result:", _G.global_var)
print("_G.test_env          = test_env(addr) result:", _G.test_env)
print("_G.env_local_var     = nil           result:", _G.env_local_var)         -- 该变量为局部变量所以 _G 中没有
print("_G.env_global_var    = nil           result:", _G.env_global_var)        -- 该变量在 _ENV 中

print("_ENV._G              = _G(addr)      result:", _ENV._G)
print("_ENV.local_var       = nil           result:", _G.local_var)
print("_ENV.env_local_var   = nil           result:", _ENV.env_local_var)
print("_ENV.env_global_var  = env_global_var result:", _ENV.env_global_var)

-- print("===环境ENV===")
-- local env = require("test_env")

-- print("env:             ", env)
-- print("test_env:        ", test_env)
-- print("_G.test_env:     ", _G.test_env)

-- print("env.local_var            = nil           result:", env.local_var)
-- print("env.global_var           = global_var    result:", env.global_var)       -- 这里的 global_var 其实是 _G.global_var

-- print("_G.global_var            = global_var    result:", _G.global_var)

-- print("_G.env_local_var        = nil           result:", _G.env_local_var)
-- print("_G.env_global_var       = nil           result:", _G.env_global_var)

-- print("test_env.env_local_var   = nil           result:", test_env.env_local_var)           -- 这里是 _G.test_env.env_local_var
-- print("test_env.env_global_var  = env_global_var result:", test_env.env_global_var)         -- 这里是 _G.test_env.env_local_var  如果test_env.lua中 test_env 变量前面加上 local 这里就不能这么用


return test_env

