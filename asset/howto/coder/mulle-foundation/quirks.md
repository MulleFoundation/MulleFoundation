<!-- keywords: foundation, quirks, utf8string, mulle_array, oldschool-objc -->
# MulleFoundation quirks

## Headers are minimal

Headers include only:

```objc
#import "import.h"
```

## Strings are `char *`

Name them `*UTF8String` and manage ownership with mulle-objc helpers.

## Collections use mulle containers

Prefer `struct mulle_array` over Foundation collection classes in public model
code when following existing project patterns.

## No modern ObjC sugar

- no dot syntax
- no blocks
- no generics
- no class extensions

## Ivars belong in `@interface`

Do not declare instance variables in `@implementation`.

