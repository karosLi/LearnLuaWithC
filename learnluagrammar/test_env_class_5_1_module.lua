
function class(class_name)
    local data = {class_name = class_name}
    print("self", self)
    local _M = {self = data}
    
    setmetatable(_M, {
        __newindex = function(self, key, value)
            data[key] = value
        end,
        
        __index = function(self, key)
            return data[key] or _G[key]
        end,
    })
  
    setfenv(2, _M)
    return data
  end