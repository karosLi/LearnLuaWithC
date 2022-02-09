local M = {}
do
	local globaltbl = _G
	local newenv = setmetatable({}, {
		__index = function (t, k)
            -- 由于环境改变了，像 print 这样的全局函数在 newenv 中是找不到的，需要从 _G 表中找
			local v = M[k]
			if v == nil then return globaltbl[k] end
			return v
		end,
		__newindex = M,-- 因为环境改变了，所有下面声明的函数都会插入到 M中
	})
	if setfenv then
		setfenv(1, newenv) -- for 5.1
	else
		_ENV = newenv -- for 5.2
	end
end

local function private()
    print("in private function")
end

function foo()
    print("Hello World!")
end

function bar()
    private()
    foo()
end

return M