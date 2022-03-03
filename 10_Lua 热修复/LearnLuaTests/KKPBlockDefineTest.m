//
//  KKPFunctionTest.m
//  LearnLuaTests
//
//  Created by karos li on 2022/3/2.
//

#import <XCTest/XCTest.h>
#import <kkp/kkp.h>
#import "KKPXCTestCase.h"

@interface Person4 : NSObject

@property (nonatomic) NSString* name;
@property (nonatomic) NSNumber* age;

@end

@implementation Person4

@end

typedef struct XPoint4 {
    int x;
    int y;
} XPoint4;


/**
 测试在 lua 定义 block 返回给原生
 */
@interface KKPBlockDefineTest : KKPXCTestCase

@property (nonatomic) char vChar;
@property (nonatomic) int vInt;
@property (nonatomic) short vShort;
@property (nonatomic) long vLong;
@property (nonatomic) long long vLongLong;
@property (nonatomic) float vFloat;
@property (nonatomic) double vDouble;
@property (nonatomic) double vCGFloat;
@property (nonatomic) bool vBool;
@property (nonatomic) char* vCharX;
@property (nonatomic) NSString* vNSString;
@property (nonatomic) NSNumber* vNSNumber;
@property (nonatomic) NSDictionary* vNSDictionary;
@property (nonatomic) NSArray* vNSArray;
@property (nonatomic) Person4* vPerson;
@property (nonatomic) XPoint4 vP;
@property (nonatomic) CGRect rect;
@property (nonatomic) SEL vSel;

@end

@implementation KKPBlockDefineTest

- (void(^)(void))blkVoidVoid
{
    return nil;
}

- (void(^)(int))blkVoidOne
{
    return nil;
}

- (int(^)(void))blkOneVoid
{
    return nil;
}

- (void(^)(char, int, short, long, long long, float, double, CGFloat, bool, char*, NSString*, NSNumber*, NSDictionary*, NSArray*, Person4*))blkVoidTotal
{
    return nil;
}

- (void(^)(XPoint4))blkVoidStruct
{
    return nil;
}

- (void(^)(XPoint4, CGRect))blkVoidStruct2
{
    return nil;
}

- (void)testExample {
    /// 返回 无参无结果 block
    [self restartKKP];
    NSString *script =
    @KKP_LUA(
             kkp_class({"KKPBlockDefineTest"},
             function(_ENV)
                 function blkVoidVoid()
                       return kkp_block(function()
                                            self:setVInt_(1)
                                        end, "void,void")
                 end
             end)
             );
    
    kkp_runLuaString(script);
    [self blkVoidVoid]();
    XCTAssert(self.vInt == 1);
    
    
    /// 返回 一个入参无结果 block
    [self restartKKP];
    script =
    @KKP_LUA(
             kkp_class({"KKPBlockDefineTest"},
             function(_ENV)
                 function blkVoidOne()
                       return kkp_block(function(i)
                                            self:setVInt_(i)
                                        end, "void,int")
                 end
             end)
             );
    
    kkp_runLuaString(script);
    [self blkVoidOne](2);
    XCTAssert(self.vInt == 2);
    
    
    /// 返回 无参一个结果 block
    [self restartKKP];
    script =
    @KKP_LUA(
             kkp_class({"KKPBlockDefineTest"},
             function(_ENV)
                 function blkOneVoid()
                       return kkp_block(function()
                                            return 5
                                        end, "int,void")
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([self blkOneVoid]() == 5);
}

- (void)testTotal {
    /// 返回 多入参无结果 block
    [self restartKKP];
    NSString *script =
    @KKP_LUA(
             kkp_class({"KKPBlockDefineTest"},
             function(_ENV)
                 function blkVoidTotal()
                       return kkp_block(function(c, i, s, l, q, f, d, g, B, ss, ns_string, ns_number, ns_dict, ns_array, person)
                                        self:setVChar_(c)
                                        self:setVInt_(i)
                                        self:setVShort_(s)
                                        self:setVLong_(l)
                                        self:setVLongLong_(q)
                                        self:setVFloat_(f)
                                        self:setVDouble_(d)
                                        self:setVCGFloat_(g)
                                        self:setVBool_(B)
                                        self:setVCharX_(ss)
                                        self:setVNSString_(ns_string)
                                        self:setVNSNumber_(ns_number)
                                        self:setVNSDictionary_(ns_dict)
                                        self:setVNSArray_(ns_array)
                                        self:setVPerson_(person)
                                        end, "void,char,int,short,long,long long,float,double,CGFloat,bool,char *,NSString *,NSNumber *,NSDictionary *,NSArray *,@")
                 end
             end)
             );
    
    Person4 *p = [[Person4 alloc] init];
    p.name = @"kk";
    p.age = @99;
    
    kkp_runLuaString(script);
    [self blkVoidTotal]('o', 1, 2, 3, 4, 5.5f, 5.5, 5.7, true, "bbq", @"nsstring", @9, @{@"key1":@1, @"key2":@2}, @[@1, @2], p);
    XCTAssert(self.vChar == 'o');
    XCTAssert(self.vInt == 1);
    XCTAssert(self.vShort == 2);
    XCTAssert(self.vLong == 3);
    XCTAssert(self.vLongLong == 4);
    XCTAssert(self.vFloat == 5.5f);
    XCTAssert(self.vDouble == 5.5);
    XCTAssert(self.vCGFloat == (CGFloat)5.7);
    XCTAssert(self.vBool == true);
    XCTAssert(strcmp(self.vCharX, "bbq") == 0);
    XCTAssert([self.vNSString isEqualToString:@"nsstring"]);
    XCTAssert([self.vNSNumber isEqualToNumber:@9]);
    id dict = @{@"key1":@1, @"key2":@2};
    XCTAssert([self.vNSDictionary isEqualToDictionary:dict]);
    id array = @[@1, @2];
    XCTAssert([self.vNSArray isEqualToArray:array]);
    XCTAssert([self.vPerson.name isEqualToString:@"kk"]);
    XCTAssert([self.vPerson.age isEqualToNumber:@99]);
}




@end
