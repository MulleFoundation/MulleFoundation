<!-- Keywords: factory, convenience, container, KVC, archiver, plist, regex, UUID, math, error -->
# Patterns

## Value classes — factory over alloc/init

```objc
NSString   *s    = [NSString stringWithUTF8String:"hello"];
NSNumber   *n    = [NSNumber numberWithInteger:42];
NSData     *data = [NSData dataWithBytes:buf length:len];
```

Never call `+alloc`/`-init`/`-autorelease`. Factory methods are the preferred entry
point. For mutable variants use `+string`, `+array`, `+dictionary`, `+set`,
`+data`, `+date` typed to the mutable class when needed.

## Strings — UTF-8 centric I/O, unichar is UTF-32

```objc
// UTF-8 output (borrowed pointer — do not free)
char   *utf8 = [s UTF8String];

// Fast internal access (raw, possibly non-null-terminated)
struct mulle_utf8data  space;
if( [s mulleFastGetUTF8Data:&space])
{
   // use space.characters / space.length
}

// No-copy string from external buffer
NSString   *nocopy;
nocopy = [NSString mulleStringWithUTF8CharactersNoCopy:buf
                                                length:len
                                             allocator:allocator];
```

For class-cluster subclasses, implement the `@optional` methods:
`characterAtIndex:`, `length`, `getCharacters:range:`,
`mulleGetUTF8Characters:maxLength:`.

## Containers — class clusters with designated initializers

```objc
NSArray   *a  = [NSArray arrayWithObjects:@"a", @"b", @"c", nil];
NSArray   *a2 = [NSArray arrayWithArray:other];

NSDictionary   *d;
d = [NSDictionary dictionaryWithObjectsAndKeys:val, @"key", nil];

NSSet   *s = [NSSet setWithObjects:obj1, obj2, nil];
```

Mutable variants:

```objc
NSMutableArray   *ma = [NSMutableArray arrayWithCapacity:10];
[ma addObject:obj];
[ma removeObjectAtIndex:i];

NSMutableDictionary   *md = [NSMutableDictionary dictionaryWithCapacity:4];
[md setObject:val forKey:key];

NSMutableSet   *ms = [NSMutableSet setWithCapacity:8];
[ms addObject:obj];
```

Designated initializers (for subclassing NSArray/NSDictionary/NSSet):
`mulleInitWithRetainedObjects:count:`, `mulleInitWithRetainedObjectKeyStorage:count:size:`.
Dictionary keys must conform to `<NSObject, MulleObjCImmutableCopying>`.

## Enumeration — fast iteration or NSEnumerator

```objc
// Fast enumeration (preferred)
for( id obj in array) { ... }

// NSEnumerator
NSEnumerator   *rover = [dict keyEnumerator];
id             key;
while( (key = [rover nextObject]))
{
   id   val = [dict objectForKey:key];
}
```

## KVC — key-value coding

```objc
// Read
id   name = [obj valueForKey:@"name"];
id   avg  = [records valueForKeyPath:@"@avg.value"];

// Write
[obj setValue:newName forKey:@"name"];
[obj setValue:newName forKeyPath:@"department.name"];

// Bulk
NSDictionary   *vals = [obj dictionaryWithValuesForKeys:keys];
[obj takeValuesFromDictionary:plistDict];
```

The `takeValue:forKey:` and `takeStoredValue:forKey:` methods are the
older KVC entry points; prefer `setValue:forKey:` (modern) in new code.

## Error handling — two patterns

### Recoverable errors with NSError (mulle thread-local pattern)

```objc
// Producer side
[MulleErrnoErrorDomain mulleSetErrorDomain];  // or custom domain
[MulleObjCSetErrorCode(code, domain, userInfo)];

// Consumer side
NSError   *error = [NSError mulleExtract];
if( error)
{
   NSLog( @"%@", [error localizedDescription]);
}
```

### Fatal errors with NSException

```objc
[NSException raise:NSInvalidArgumentException
            format:@"Value must not be nil, got: %@", name];

// Try/catch
@try
{
   // risky code
}
@catch( NSException *localException)
{
   NSLog( @"Caught: %@", localException);
}
```

The `NS_DURING`/`NS_HANDLER`/`NS_ENDHANDLER` macros map to `@try`/`@catch`.

## Property List serialization

```objc
NSData   *plistData;
plistData = [NSPropertyListSerialization dataWithPropertyList:dict
                                                       format:NSPropertyListOpenStepFormat
                                                      options:0
                                                        error:&error];

id   restored;
restored = [NSPropertyListSerialization propertyListWithData:plistData
                                                     options:0
                                                      format:NULL
                                                       error:&error];
```

For JSON output use `MullePropertyListJSONFormat`. Parsing always returns
mutable containers (`NSMutableArray` / `NSMutableDictionary`).

## Object archiving

```objc
// Encode
NSData   *data = [NSArchiver archivedDataWithRootObject:myObject];

// Decode
id   obj = [NSUnarchiver unarchiveObjectWithData:data];
```

For keyed archiving use `NSKeyedArchiver` / `NSKeyedUnarchiver`.
The archiver encodes to `NSMutableData` internally.

## Regex and wildcard matching

```objc
// Pattern match (returns NSRange)
NSRange   r;
r = [text mulleRangeOfPattern:@"b*wn"
                      options:MulleObjCWildcards
                        range:NSMakeRange(0, [text length])];

// Replace
NSString   *result;
result = [text mulleStringByReplacingPattern:@"foo"
                                  withString:@"bar"
                                     options:MulleObjCWildcards
                                       range:NSMakeRange(0, [text length])];
```

Use `MulleObjCWildcards` (greedy) or `MulleObjCWildcardsShortestPath` (non-greedy).
Use `MulleObjCSedPattern` for sed-like grouping (`\(` instead of `(`).

No separate `NSRegularExpression` class exists; everything is on `NSString(Regex)`.

## UUID generation

```objc
NSUUID      *uuid = [NSUUID UUID];
NSString    *str  = [uuid UUIDString];  // "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

// C-level (avoids object allocation)
unsigned char  bytes[16];
char           buf[37];
MulleGenerateUUIDBytes(bytes);
MulleUUIDBytesToUTF8String(bytes, buf);
```

`MulleGenerateUUIDBytes` is thread-safe. NSUUID is a subclass of NSData
with exactly 16 bytes.

## Math on NSNumber

NSNumber categories provide math operations:

```objc
NSNumber   *a = [NSNumber numberWithDouble:2.0];
NSNumber   *b = [NSNumber numberWithDouble:3.0];
// a sin, cos, tan, sqrt, pow:b, etc.
```

Use `+numberWithDouble:` for floating-point numbers.
Note that `-NaN` input is converted to `NaN` during construction.
