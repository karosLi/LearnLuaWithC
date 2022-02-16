_ENV = kkp_class{"CustomTableViewController", "UIViewController", protocols={"UITableViewDelegate"}}

function init()
    self.super.init()
    print("CustomTableViewController init", self)
    self.trends = {}
    self.aa = 0;
    
    return self
end

function viewDidLoad()
    print("CustomTableViewController viewDidLoad", self.aa)
    self:view():setBackgroundColor_(UIColor:blueColor())
end

function dealloc()
    print("CustomTableViewController dalloc")
end
