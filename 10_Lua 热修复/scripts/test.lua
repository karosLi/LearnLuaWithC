require "CustomTableViewController"

-- 准备 hook 的类名
_ENV = kkp_class{"ViewController"}

-- 替换实例方法
function doSomeThing()
    -- 设置/获取 lua 属性
    self.aa = "hh"
    print("获取 lua 属性 aa", self.aa)
    -- 设置/获取 原生 属性
    self:setAge_(18)
    print("获取 原生 属性 age", self:age())
    -- 动态添加 设置/获取 原生 属性
    self:setSex_("男")
    print("获取 动态 原生 属性 sex", self:sex())
    -- 调用实例方法
    print("print in lua", self:getHello())
    -- 调用当前类的静态方法
    ViewController:printHello()
    self:view():setBackgroundColor_(UIColor:redColor())
    -- 调用原始方法
    self.origin:doSomeThing()
    -- 调用父类方法
    self.super:doSomeThing()
end

function onClickGotoButton()
    local controller = CustomTableViewController:alloc():init()
    controller.aa = 10
    print("lua create CustomTableViewController", controller)
    self:navigationController():pushViewController_animated_(controller, true)
end


-- 替换静态方法
function STATICprintHello()
    ViewController:testStatic()
end
