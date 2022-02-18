kkp_protocol("CustomTableViewProtocol", {
    refreshView = "void,void",
    STATICrefreshData_ = "void,NSDictionary*"
})

_ENV = kkp_class({"CustomTableViewController", "UIViewController", protocols={"CustomTableViewProtocol", "UITableViewDataSource"}})

function init()
    self.super.init()
    print("【LUA】CustomTableViewController init", self)
    self.trends = {}
    self.aa = 0;
    
    return self
end

function viewDidLoad()
    print("【LUA】CustomTableViewController viewDidLoad", self.aa)
    self:view():setBackgroundColor_(UIColor:blueColor())
    
    CustomTableViewController:refreshData_({key = "value", key1 = "value1"})
end

function refreshView()
    print("【LUA】CustomTableViewController refreshView", self.aa)
end

function STATICrefreshData_(data)
    print("【LUA】CustomTableViewController STATICrefreshData", data)
    for k,v in pairs(data) do
        print("【LUA】CustomTableViewController STATICrefreshData", k, v)
    end
end

function dealloc()
    print("【LUA】CustomTableViewController dalloc")
end

-- DataSource
-------------
function numberOfSectionsInTableView_(tableView)
  return 1
end

