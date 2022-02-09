-- function func(class_name)
--     local a = {self = class_name}

--     setmetatable(a, {

--     })

--     setfenv(2, a)

--     print(self)
-- end
-- func("ddd")

-- 定义两个不同的环境
local newEnv = {
    _G = _G;
    val1 = 1024;
}

local newEnv2 = {
    _G = _G;
    val2 = 256;
}

-- 先查看一下这两个新环境值和全局环境有什么不同
print("\n_G =", _G);

print("newEnv =", newEnv);

print("newEnv2 =", newEnv2);

function test_level(level)
    local ret_env =getfenv(level); -- 获得环境
    -- 输出环境中的值
    print("\nenvironment level", level, ret_env)
    print("ret_env.val1 =", ret_env.val1);
    print("ret_env.val2 =", ret_env.val2);
end

function show_level(level)
    _G.setfenv(1, newEnv2); -- 设置环境
    _G.test_level(level);
end

function display_level(level)
    _G.setfenv(1, newEnv); -- 设置环境
    _G.show_level(level);
end

-- 测试level参数第一组
display_level(1)

-- 测试level参数第二组
display_level(2)

-- 测试level参数第三组
display_level(3)