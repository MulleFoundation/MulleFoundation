<!-- keywords: foundation, patterns, instanceWith, dealloc, mulle_array -->
# MulleFoundation patterns

## Minimal class skeleton

```objc
// MulleFoo.h
#import "import.h"

@interface MulleFoo : NSObject
{
   char       *_nameUTF8String;
   CGFloat     _value;
}

+ (instancetype) instanceWithNameUTF8String:(char *) name;

@end


// MulleFoo.m
#import "import-private.h"

@implementation MulleFoo

+ (instancetype) instanceWithNameUTF8String:(char *) name
{
   MulleFoo   *obj;

   obj = [[[self alloc] init] autorelease];
   [obj setNameUTF8String:name];
   return( obj);
}

- (void) setNameUTF8String:(char *) s
{
   MulleObjCObjectSetDuplicatedUTF8String( self, &_nameUTF8String, s);
}

- (void) dealloc
{
   MulleObjCInstanceDeallocateMemory( self, _nameUTF8String);
   [super dealloc];
}

@end
```

## mulle_array pattern

```objc
mulle_array_init( &_items, 0, &_MulleObjCContainerCopyCStringKeyCallback,
                  MulleObjCInstanceGetAllocator( self));
```

