//
//  BaseViewController.swift
//  LearnLua
//
//  Created by karos li on 2022/3/7.
//

import UIKit

/**
 使用 kkp_class() 覆盖 Swift 类时，类名应为 项目名.原类名，例如项目 demo 里用 Swift 定义了 ViewController 类，在 JS 覆盖这个类方法时要这样写：

 kkp_class({"demo.ViewController"})
 对于调用已在 swift 定义好的类，也是一样：

 kkp_class_index("demo.ViewController")
 需要注意几点：

 只支持调用继承自 NSObject 的 Swift 类
 继承自 NSObject 的 Swift 类，其继承自父类的方法和属性可以在 JS 调用，其他自定义方法和属性同样需要加 dynamic 关键字才行。
 若方法的参数/属性类型为 Swift 特有(如 Character / Tuple)，则此方法和属性无法通过 JS 调用。
 Swift 项目在 JSPatch 新增类与 OC 无异，可以正常使用。
 
 https://mp.weixin.qq.com/s?__biz=MzUxMzcxMzE5Ng==&mid=2247488491&idx=1&sn=a5364eacd752f455837179681f4a774c&source=41#wechat_redirect
 }
 */

class ViewController1: BaseViewController {
    dynamic var a = "a"
    dynamic private var pa = "pa"
    
    override func viewDidLoad() {
        print("ORIG title:\(self.title!)")
        print("ORIG a:\(a)")
        print("ORIG pa:\(pa)")
        
        super.viewDidLoad()
        view.backgroundColor = .yellow
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
