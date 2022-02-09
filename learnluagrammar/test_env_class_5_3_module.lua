
local function setfenv(fn, env)
    local i = 1
    while true do
      local name = debug.getupvalue(fn, i)
      if name == "_ENV" then
        debug.upvaluejoin(fn, i, (function()
          return env
        end), 1)
        break
      elseif not name then
        break
      end
  
      i = i + 1
    end
  
    return fn
  end

function class(class_name)
    local data = {class_name = class_name}
    local scope = {self = data}
    
    setmetatable(scope, {
        -- 当有新的 key 存在时，比如新定义的变量，方法，都会触发 __newindex
        __newindex = function(self, key, value)
            print("==== __newindex", self, key, value)
            data[key] = value
        end,
        
        -- 当获取 key 不存在与 scope 时，就会触发 __index
        __index = function(self, key)
            -- print("==== __index", self, key)
            return data[key] or _G[key]
        end,
    })
  
    -- setfenv(class, _M)
    
    -- 修改函数内部的 _ENV 并不会改变外部函数的 _ENV，因为每个函数（也可以是脚本文件） chunk 都有自己的独立的 _ENV
    -- _ENV = {print = print}
    print("_ENV", _ENV)
    return data,scope
  end