//
//  KKPFunctionTest.m
//  LearnLuaTests
//
//  Created by karos li on 2022/3/2.
//

#import <XCTest/XCTest.h>
#import <kkp/kkp.h>
#import "KKPXCTestCase.h"

@interface Person : NSObject

@property (nonatomic) NSString* name;
@property (nonatomic) NSNumber* age;

@end

@implementation Person

@end

typedef struct _XPoint
{
    int x;
    int y;
}XPoint;


/**
 测试数据转换
 */
@interface KKPConvertTest : KKPXCTestCase

@property (nonatomic) char vChar;
@property (nonatomic) int vInt;
@property (nonatomic) short vShort;
@property (nonatomic) long vLong;
@property (nonatomic) long long vLongLong;
@property (nonatomic) float vFloat;
@property (nonatomic) double vDouble;
@property (nonatomic) bool vBool;
@property (nonatomic) char* vCharX;
@property (nonatomic) NSString* vNSString;
@property (nonatomic) NSNumber* vNSNumber;
@property (nonatomic) NSDictionary* vNSDictionary;
@property (nonatomic) NSArray* vNSArray;
@property (nonatomic) Person* vPerson;
@property (nonatomic) XPoint vP;
@property (nonatomic) SEL vSel;

@end

@implementation KKPConvertTest

- (char)argInChar:(char)vChar
{
    return vChar;
}

- (int)argInInt:(int)vInt
{
    return vInt;
}

- (short)argInShort:(short)vShort
{
    return vShort;
}

- (long)argInLong:(long)vLong
{
    return vLong;
}

- (long long)argInLongLong:(long long)vLongLong
{
    return vLongLong;
}

- (float)argInFloat:(float)vFloat
{
    return vFloat;
}

- (double)argInDouble:(double)vDouble
{
    return vDouble;
}

- (bool)argInBool:(bool)vBool
{
    return vBool;
}

- (char *)argInCharX:(char *)vCharX
{
    return vCharX;
}

- (NSString *)argInString:(NSString *)vNSString
{
    return vNSString;
}

- (NSNumber *)argInNSNumber:(NSNumber *)vNSNumber
{
    return vNSNumber;
}

- (NSArray *)argInNSArray:(NSArray *)vNSArray
{
    return vNSArray;
}

- (NSDictionary *)argInNSDictionary:(NSDictionary *)vNSDictionary
{
    return vNSDictionary;
}

- (Person *)argInPerson:(Person *)vPerson
{
    return vPerson;
}

- (XPoint)argInXPoint:(XPoint)vXPoint
{
    return vXPoint;
}

- (SEL)argInSel:(SEL)vSel
{
    return vSel;
}

- (void)testChar {
    [self restartKKP];
    XCTAssert([self argInChar:'a'] == 'a');
    NSString *script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInChar_(a)
                       self:setVChar_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([self argInChar:'a'] == 'a');
    XCTAssert(self.vChar == 'a');
}

- (void)testNumber {
    /// int
    [self restartKKP];
    XCTAssert([self argInInt:9] == 9);
    NSString *script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInInt_(a)
                       self:setVInt_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    // 测试方法调用返回值
    XCTAssert([self argInInt:9] == 9);
    // 测试属性设置
    XCTAssert(self.vInt == 9);
    
    
    /// short
    [self restartKKP];
    XCTAssert([self argInShort:10] == 10);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInShort_(a)
                       self:setVShort_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([self argInShort:10] == 10);
    XCTAssert(self.vShort == 10);
    
    
    /// long
    [self restartKKP];
    XCTAssert([self argInLong:0x100060000277e000] == 0x100060000277e000);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInLong_(a)
                       self:setVLong_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([self argInLong:0x100060000277e000] == 0x100060000277e000);
    XCTAssert(self.vLong == 0x100060000277e000);
    
    
    /// float
    [self restartKKP];
    XCTAssert([self argInFloat:3.14f] == 3.14f);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInFloat_(a)
                       self:setVFloat_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([self argInFloat:3.14f] == 3.14f);
    XCTAssert(self.vFloat == 3.14f);
    
    
    /// double
    [self restartKKP];
    XCTAssert([self argInDouble:4E+38] == 4E+38);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInDouble_(a)
                       self:setVDouble_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([self argInDouble:4E+38] == 4E+38);
    XCTAssert(self.vDouble == 4E+38);
    
    
    /// bool
    [self restartKKP];
    XCTAssert([self argInBool:true] == true);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInBool_(a)
                       self:setVBool_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([self argInBool:true] == true);
    XCTAssert(self.vBool == true);
}

- (void)testPtr {
    /// char *
    [self restartKKP];
    XCTAssert(strcmp([self argInCharX:"abc"], "abc") == 0);
    NSString *script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInCharX_(a)
                       self:setVCharX_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert(strcmp([self argInCharX:"abc"], "abc") == 0);
    XCTAssert(strcmp(self.vCharX, "abc") == 0);
}

- (void)testObject {
    /// Person *
    [self restartKKP];
    Person *person = [[Person alloc] init];
    person.name = @"blue";
    person.age = @18;
    Person *r = [self argInPerson:person];
    XCTAssert([r.name isEqualToString:@"blue"] && [r.age isEqualToNumber:@18]);
    NSString *script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInPerson_(a)
                       self:setVPerson_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    r = [self argInPerson:person];
    XCTAssert([r.name isEqualToString:@"blue"] && [r.age isEqualToNumber:@18]);
    XCTAssert([self.vPerson.name isEqualToString:@"blue"] && [self.vPerson.age isEqualToNumber:@18]);
    
    
    /// NSString *
    [self restartKKP];
    XCTAssert([[self argInString:@"abc"] isEqualToString:@"abc"]);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInString_(a)
                       self:setVNSString_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([[self argInString:@"abc"] isEqualToString:@"abc"]);
    XCTAssert([self.vNSString isEqualToString:@"abc"]);
    
    
    /// NSNumber *
    [self restartKKP];
    XCTAssert([[self argInNSNumber:@1024] isEqualToNumber:@1024]);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInNSNumber_(a)
                       self:setVNSNumber_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([[self argInNSNumber:@1024] isEqualToNumber:@1024]);
    XCTAssert([self.vNSNumber isEqualToNumber:@1024]);
    
    
    /// NSArray *
    [self restartKKP];
    BOOL b = [[[self argInNSArray:@[@1, @2]] objectAtIndex:0] isEqualToNumber:@1];
    XCTAssert(b);
    b = [[[self argInNSArray:@[@1, @2]] objectAtIndex:1] isEqualToNumber:@2];
    XCTAssert(b);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInNSArray_(a)
                       local l = #a
                       self:setVNSArray_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    b = [[[self argInNSArray:@[@1, @2]] objectAtIndex:0] isEqualToNumber:@1];
    XCTAssert(b);
    b = [[[self argInNSArray:@[@1, @2]] objectAtIndex:1] isEqualToNumber:@2];
    XCTAssert(b);
    b = [[self.vNSArray objectAtIndex:0] isEqualToNumber:@1];
    XCTAssert(b);
    b = [[self.vNSArray objectAtIndex:1] isEqualToNumber:@2];
    XCTAssert(b);
    
    
    /// NSDictionary *
    [self restartKKP];
    b = [[[self argInNSDictionary:@{@"key1":@1, @"key2":@2}] objectForKey:@"key1"] isEqualToNumber:@1];
    XCTAssert(b);
    b = [[[self argInNSDictionary:@{@"key1":@1, @"key2":@2}] objectForKey:@"key2"] isEqualToNumber:@2];
    XCTAssert(b);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInNSDictionary_(a)
                       local l = #a
                       self:setVNSDictionary_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    b = [[[self argInNSDictionary:@{@"key1":@1, @"key2":@2}] objectForKey:@"key1"] isEqualToNumber:@1];
    XCTAssert(b);
    b = [[[self argInNSDictionary:@{@"key1":@1, @"key2":@2}] objectForKey:@"key2"] isEqualToNumber:@2];
    XCTAssert(b);
    b = [[self.vNSDictionary objectForKey:@"key1"] isEqualToNumber:@1];
    XCTAssert(b);
    b = [[self.vNSDictionary objectForKey:@"key2"] isEqualToNumber:@2];
    XCTAssert(b);
    
    
    /// SEL
    [self restartKKP];
    XCTAssert([self argInSel:@selector(argInSel:)] == @selector(argInSel:));
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInSel_(a)
                       self:setVSel_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    XCTAssert([self argInSel:@selector(argInSel:)] == @selector(argInSel:));
    XCTAssert(self.vSel == @selector(argInSel:));
    
    
    /// XPoint 结构体从 原生 传入到 lua, 并从 lua 返回给 原生
    [self restartKKP];
    XPoint xp;
    xp.x = 3;
    xp.y = 4;
    XPoint p = [self argInXPoint:xp];
    XCTAssert(p.x == 3 && p.y == 4);
    script =
    @KKP_LUA(
             kkp_class({"KKPConvertTest"},
             function(_ENV)
                 function argInXPoint_(a)
                       self:setVP_(a)
                       return a
                 end
             end)
             );
    
    kkp_runLuaString(script);
    p = [self argInXPoint:xp];
    XCTAssert(p.x == 3 && p.y == 4);
    XCTAssert(self.vP.x == 3 && self.vP.y == 4);
}

@end
