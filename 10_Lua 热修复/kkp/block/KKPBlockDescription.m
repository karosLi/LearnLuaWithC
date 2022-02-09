//
//  KKPBlockDescription.m
//  LearnLua
//
//  Created by karos li on 2022/1/25.
//

#import "KKPBlockDescription.h"

@implementation KKPBlockDescription

- (id)initWithBlock:(id)block
{
    if (self = [super init]) {
        _block = block;
        
        struct CTBlockLiteral *blockRef = (__bridge struct CTBlockLiteral *)block;
        _flags = blockRef->flags;
        _size = blockRef->descriptor->size;
        
        if (_flags & CTBlockDescriptionFlagsHasSignature) {
            void *signatureLocation = blockRef->descriptor;
            signatureLocation += sizeof(unsigned long int);
            signatureLocation += sizeof(unsigned long int);
            
            if (_flags & CTBlockDescriptionFlagsHasCopyDispose) {
                signatureLocation += sizeof(void(*)(void *dst, void *src));
                signatureLocation += sizeof(void (*)(void *src));
            }
            
            const char *signature = (*(const char **)signatureLocation);
            _blockSignature = [NSMethodSignature signatureWithObjCTypes:signature];
        }
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: %@", [super description], _blockSignature.description];
}

@end
