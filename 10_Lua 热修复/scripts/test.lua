-- 准备 hook 的类名
_ENV = kkp_class("ViewController")

-- 替换实例方法
function doSomeThing()
    -- 设置/获取 lua 属性
    self.aa = "hh"
    print("获取 lua 属性 aa", self.aa)
    -- 设置原生属性
    self.age = 18
    -- 调用实例方法
    print("print in lua", self:getHello())
    -- 调用当前类的静态方法
    ViewController:printHello()
    self:view():setBackgroundColor_(UIColor:redColor())
    -- 调用原始方法
    self:ORIGdoSomeThing()
    -- 调用父类方法
    self:SUPERdoSomeThing()
end

-- 替换静态方法
function STATICprintHello()
    ViewController:testStatic()
end
