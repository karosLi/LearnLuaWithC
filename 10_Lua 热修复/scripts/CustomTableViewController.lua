kkp_protocol("CustomTableViewProtocol", {
    refreshView = "void,void",
},{
    refreshData_ = "void,NSDictionary*"
})

kkp_class({"CustomTableViewController", "UIViewController", protocols={"CustomTableViewProtocol", "UITableViewDataSource"}},
function(_ENV)

    function init()
        self.super.init()
        print("【LUA】CustomTableViewController init", self)
        self.trends = {}
        self.aa = 1111;
        
        local size = CGSize({width = 22.0, height = 33.0})
        local copySize = size:copy()
        size.width = 45.0
        print("【LUA】CGSize", size.width)
        size.height = 56.0
        print("【LUA】CGSize", size)
        print("【LUA】copy CGSize", copySize)
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

    function dealloc()
        print("【LUA】CustomTableViewController dalloc")
    end

    -- DataSource
    -------------
    function numberOfSectionsInTableView_(tableView)
      return 1
    end

end,
function(_ENV)

    function refreshData_(data)
        print("【LUA】CustomTableViewController STATICrefreshData", data)
        for k,v in pairs(data) do
            print("【LUA】CustomTableViewController STATICrefreshData", k, v)
        end
    end

end)


