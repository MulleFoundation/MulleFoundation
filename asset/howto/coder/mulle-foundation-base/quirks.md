<!-- Keywords: pitfalls, invariants, restrictions, differences, caveats -->
# Quirks

## Global restrictions

- **No dot-syntax** — always use explicit message sends: `[obj method]` not `obj.method`.
- **No blocks** — do not use `^` block syntax under any circumstance.
- **No `-release`** except in `-dealloc`.
- **No `+alloc`/`-init`/`-autorelease`** in application code; use factory methods.
- **No `NSRegularExpression` class** exists — use `NSString(Regex)` category methods.
- **`unichar` is UTF-32** (`mulle_utf32_t`), not 16-bit. Strings store internally as
  ASCII (7-bit), UTF-16 (15-bit only, no surrogate pairs), or UTF-32. UTF-8 is
  the external exchange format.
- **`NSValue` removed** from this amalgamation — `NSNumber` inherits from `NSValue`
  but the base `NSValue` class is provided by the runtime, not this library.
- **Returned `char *` from `UTF8String` is borrowed** — do not free it, and do not
  assume it outlives the string object.
- **Mutable containers are not thread-safe** — access from a single thread only.
  `MulleGenerateUUIDBytes` is the only explicitly thread-safe API.
- **`@mixin` keyword** is used for `MulleObjCPropertyListPrinting` and
  `MulleObjCOutputStream` — this is a Mulle-ObjC extension, not standard ObjC.

## NSString quirks

- `mulleFastGetUTF8Data:` returns raw pointers into private storage. The returned
  data may not be zero-terminated. It is only valid as long as the string's
  backing store is not mutated.
- `mulleGetUTF8String:bufferSize:` stores a zero terminator in `buf[size - 1]`.
- For filesystem paths, use `-fileSystemRepresentation` (provided by a higher
  layer), not `UTF8String` or `cString`.
- String search option values above `0xFFF` intrude into `MulleObjCPatternOptions`
  space — do not use raw numeric values above that boundary.

## NSNumber quirks

- `-NaN` input to `+numberWithDouble:` is converted to `Nan` (matching Apple
  Foundation behavior).
- `long double` support is conditional on `_C_LNG_DBL` being defined.
- `NSNUMBER_DEFINED` preprocessor macro is set for use by dependent code.

## NSData quirks

- `initWithBytesNoCopy:length:freeWhenDone:` and `mulleInitWithBytesNoCopy:length:sharingObject:`
  transfer memory ownership. The `sharingObject:` variant ties lifetime to another
  object.
- `mulleDataWithCData:` bridges from C `struct mulle_data` to NSData.

## Container quirks

- **NSArray** superclass is `MulleObjCContainer`, not `NSObject` directly.
- **NSDictionary keys** must conform to `<NSObject, MulleObjCImmutableCopying>`.
  Keys are copied; values are retained (`mulleInitWithRetainedObjects:copiedKeys:count:`).
- `initWithArray:copyItems:` and `initWithDictionary:copyItems:` support deep
  copying.
- `setArray:`, `setDictionary:`, `setSet:` perform shallow copies, not deep.
- **NSArray subclass** must implement `objectAtIndex:`, `getObjects:range:`.
  The shortcut `:(NSUInteger)index` is equivalent to `objectAtIndex:`.
- **NSSet subclass** must override `count`, `member:`, `objectEnumerator`,
  `countByEnumeratingWithState:objects:count:`.
- `mulleForEachObjectCallFunction:argument:preempt:` uses an `enum MullePreempt`
  for early termination control.
- `mulleInitWithRetainedObjects:count:` and `mulleInitWithRetainedObjectStorage:count:size:`
  are the designated initializers for NSArray placeholders.
- The `_NSSetPlaceholder` pattern uses `mulleInitForCoderWithCapacity:` for
  `NSCoder`-based initialization.

## NSError quirks

- The thread-local error model (`[NSError mulleExtract]`, `mulleSetErrorCode:domain:userInfo:`)
  is the preferred entry point for recoverable errors.
- Error domain registration (`+registerErrorDomain:errorStringFunction:`) must
  happen during `+load` or `+initialize`.
- `recoveryAttempter` can return something thread-unsafe — `NSError` is therefore
  not considered a value type.
- Standalone C functions exist: `MulleObjCSetErrorCode`, `MulleObjCExtractError`,
  `MulleObjCClearError`, etc.

## NSException quirks

- `+raise:` is **not** marked `MULLE_C_NO_RETURN` because when `self` is nil,
  sending `raise` does return.
- Named exception strings are global `NSString *` constants:
  `NSInternalInconsistencyException`, `NSGenericException`,
  `NSInvalidArgumentException`, `NSMallocException`, `NSRangeException`,
  `NSParseErrorException`.

## NSDate quirks

- `compare:` on nil returns `NSOrderedSame` — a deliberate design choice for
  symmetry between `[date compare:nil]` and `[nil compare:date]`.
- `+date` is marked as **obsolete** in favor of `+object`.
- `NSTimeInterval` is a separate import header (`NSTimeInterval.h`).

## NSTimer quirks

- Dual use: can be used with `NSRunLoop` or `UIApplication` (which doesn't use
  a runloop).
- When using absolute/fire-time-based timers, you must add the timer to a runloop
  or UIApplication immediately to avoid skew.
- Two interval types: `mulle_relativetime_t` (monotonic) and `NSTimeInterval`
  (wall-clock/calendar).
- Callback modes: `NSInvocation`, `target+selector`, or `NSTimerCallback_t`
  (C function pointer).
- The `fireUsesUserInfoAsArgument:` flag determines whether `userInfo` is passed
  as the argument to the selector.
- Minimum time interval: `_NSTIMER_MIN_TIMEINTERVAL` = 0.0001s.

## NSNotificationCenter quirks

- Implements `MulleObjCSingleton` and `MulleObjCThreadSafe` protocols.
- Uses `mulle_thread_mutex_t` for internal locking.
- Currently app-wide (not thread-local), which enables `+load` plugin setup
  but can cause cross-thread notification delivery.

## Property list quirks

- Parsing always returns **mutable** containers (`NSMutableArray`,
  `NSMutableDictionary`), regardless of mutability option.
- Supported formats: `NSPropertyListOpenStepFormat` (1),
  `MullePropertyListLooseFormat` (2, with Mulle extensions),
  `MullePropertyListPBXFormat` (3, Apple PBX extensions),
  `MullePropertyListJSONFormat` (6), `NSPropertyListXMLFormat_v1_0` (100),
  `NSPropertyListBinaryFormat_v1_0` (200 — no write support).
- Pass `MullePropertyListLooseFormat` as the format hint to enable parsing of
  numbers, dates, and `NSNull` (`__NSNULL__`).
- Always initialize the format variable to zero before passing as `&format` to
  avoid a random format preference.
- Error handling is still mixed between NSError and NSException (noted as TODO
  in the header).

## Archiver quirks

- An `NSCoder` instance supports either keyed or unkeyed archiving, not both.
- Use `-allowsKeyedCoding` to detect the mode.
- `MulleObjCArchiver` / `MulleObjCUnarchiver` are the concrete base archivers.
  `NSArchiver` and `NSUnarchiver` are convenience wrappers.
- `NSKeyedArchiver` / `NSKeyedUnarchiver` provide keyed archiving with
  `encodeObject:forKey:` / `decodeObjectForKey:`.
- Objects being archived should implement `-encodeWithCoder:`.
- `NSObject+NSCoder.h` provides `NSCoding` protocol support.

## Regex quirks

- No `NSRegularExpression` class. Use `NSString(Regex)` category methods.
- Wildcard modes: `MulleObjCWildcards` (greedy) and `MulleObjCWildcardsShortestPath`
  (non-greedy). `MulleObjCWildcards` with `a*c` on `abcabc` matches the full
  string; `MulleObjCWildcardsShortestPath` on `abcabc` matches only `abc`.
- `MulleObjCSedPattern` uses `\(` instead of `(` for grouping.
- Pattern options extend `NSStringCompareOptions` — values above `0xFFF` are
  allocated to pattern options.

## NSUUID quirks

- `NSUUID` is a subclass of `NSData` with exactly 16 bytes (`MulleUUIDBytesLength`).
- `UUIDString` format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` (version 4, variant 1).
- `MulleUUIDBytesToUTF8String` requires a destination buffer of at least 37 bytes
  (`MulleUUIDStringLength`), including the null terminator.
- `MulleUTF8StringToUUIDBytes` returns -1 on incompatible input; it requires
  strictly the same format as produced by `UUIDString`.

## Math quirks

- Math is provided as `NSNumber` categories. Constants like `MulleMath_PI`,
  `MulleMath_E` are available.
- Trigonometric functions (`sin`, `cos`, `tan`, etc.) work on `NSNumber` instances.
