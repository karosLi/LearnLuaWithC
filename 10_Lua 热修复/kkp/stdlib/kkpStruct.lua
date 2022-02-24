local kkp_structN = require("kkp.struct")

-- 预注册通用结构体
kkp_structN.registerStruct({name = "CGSize", types = "CGFloat,CGFloat", keys = "width,height"})
kkp_structN.registerStruct({name = "CGPoint", types = "CGFloat,CGFloat", keys = "x,y"})
kkp_structN.registerStruct({name = "UIEdgeInsets", types = "CGFloat,CGFloat,CGFloat,CGFloat", keys = "top,left,bottom,right"})
kkp_structN.registerStruct({name = "CGRect", types = "CGFloat,CGFloat,CGFloat,CGFloat", keys = "x,y,width,height"})
kkp_structN.registerStruct({name = "NSRange", types = "NSUInteger,NSUInteger", keys = "location,length"})
kkp_structN.registerStruct({name = "_NSRange", types = "NSUInteger,NSUInteger", keys = "location,length"})--typedef _NSRange to NSRange
kkp_structN.registerStruct({name = "CLLocationCoordinate2D", types = "CGFloat,CGFloat", keys = "latitude,longitude"})
kkp_structN.registerStruct({name = "MKCoordinateSpan", types = "CGFloat,CGFloat", keys = "latitudeDelta,longitudeDelta"})
kkp_structN.registerStruct({name = "MKCoordinateRegion", types = "CGFloat,CGFloat,CGFloat,CGFloat", keys = "latitude,longitude,latitudeDelta,longitudeDelta"})
kkp_structN.registerStruct({name = "CGAffineTransform", types = "CGFloat,CGFloat,CGFloat,CGFloat,CGFloat,CGFloat", keys = "a,b,c,d,tx,ty"})
kkp_structN.registerStruct({name = "UIOffset", types = "CGFloat,CGFloat", keys = "horizontal,vertical"})
