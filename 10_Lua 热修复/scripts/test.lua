require "CustomTableViewController"

-- 准备 hook 的类名
_ENV = kkp_class{"ViewController"}

-- hook 实例方法
function doSomeThing_(thingName)
    -- 打印原生入参
    print("打印原生入参 thingName", thingName)
    -- 设置/获取 lua 属性
    self.aa = "hh"
    print("获取 lua 属性 aa", self.aa)
    -- 设置/获取 原生 属性
    self:setAge_(18)
    print("获取 原生 属性 age", self:age())
    -- 动态添加 设置/获取 原生 属性
    self:setSex_("男")
    print("获取 动态 原生 属性 sex", self:sex())
    -- 设置/获取 原生 私有 变量
    self:setIvar_withInteger_("_aInteger", 666)
    print("获取 原生 私有变量 _aInteger", self:getIvarInteger_("_aInteger"))
    -- 调用实例方法
    print("print in lua", self:getHello())
    -- 调用当前类的静态方法
    ViewController:printHello()
    self:view():setBackgroundColor_(UIColor:redColor())
    -- 调用原始方法
    self.origin:doSomeThing_(thingName)
    -- 调用父类方法
    self.super:doSomeThing_(thingName)
end

-- 添加新类
function onClickGotoButton()
    local controller = CustomTableViewController:alloc():init()
    controller.aa = 10
    print("lua create CustomTableViewController", controller)
    self:navigationController():pushViewController_animated_(controller, true)
end

-- hook 带有 oc block 参数的实例方法
function blockOneArg_(block)
    -- 调用原生 block
    self:setIndex_(block(12))
end

-- hook 返回值是 oc block 的实例方法，block 带参数和返回值
function blockReturnBoolWithString()
    -- 把 lua 函数包装成一个 oc block，原生在实际调用 oc block 时，会触发包裹的 lua 函数代码
    return kkp_block(function(string) print("原生调用 lua 提供的 oc block 参数是", string) return "哈哈" end, "NSString*,NSString*")
end

-- hook 静态方法
function STATICprintHello()
    ViewController:testStatic()
end
