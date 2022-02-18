local kkp_classN = require("kkp.class")

function kkp_class(options)
    -- 类名，字符串
    local class_name = options[1]
    -- 父类名，字符串
    local super_class_name = options[2]
    
    -- 判断协议合理性
    if options.protocols then
        if type(options.protocols) ~= "table" then options.protocols = {options.protocols} end
        if #options.protocols == 0 then error("\nEmpty protocol table for class " .. className .. ".\n Make sure you are defining your protocols with a string and not a variable. \n ex. protocols = {\"UITableViewDelegate\"}\n\n") end
        
    end

    -- 基于要 hook 的类名，创建 class user data
    local class_userdata = kkp_classN(class_name, super_class_name, options.protocols)

    -- class 作为 key，这样在函数里就可以使用 class 关键字了，这里 class 不是变量，只是单纯的 key
    local scope = {class = class_userdata}
    
    -- 设置 scope 元表
    setmetatable(scope, {
        -- 当有新的 key 存在时，比如 lua 文件中新定义的函数，都会触发 __newindex
        __newindex = function(scope, key, value)
            -- print("【LUA】", class_name, "==== __newindex", scope, key, value)
            class_userdata[key] = value
        end,
        
        -- 当获取 key 不存在 scope 时，就会触发 __index
        __index = function(scope, key)
            -- print("【LUA】", class_name, "==== __index", scope, key)
            -- 当检索的是 其他原生类 时，比如 UIColor，那么就会先去创建 UIColor 的 class user data
            -- 当检索的是 当前类原生 静态方法时，就去 class_userdata 的元方法里检索 key 对应的静态方法
            -- 如果以上都不是，那就需要从 全局 _G 表中找，比如 要找 print lua 函数
            return kkp_classN.findUserData(key) or class_userdata[key] or _G[key]
        end,
    })
    
    -- 把环境保存到 class_userdata 里，方便原生在调用 lua 函数时，给 scope 添加 self 关键字
    class_userdata._SCOPE = scope
    
    return scope
end

-- 定义一个 原生 block，arg1 是 lua 函数，arg2 是 返回类型，arg3 是参数类型
function kkp_block(func, type_encoding)
    return kkp_classN.defineBlock(func, type_encoding)
end

-- 定义一个 原生 协议，arg1 是 协议名，arg2 是 方法声明的 table 字典
function kkp_protocol(protocol_name, protocol_function_table)
    return kkp_classN.defineProtocol(protocol_name, protocol_function_table)
end
