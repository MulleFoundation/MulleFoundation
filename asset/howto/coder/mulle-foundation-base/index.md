<!-- Keywords: Objective-C, amalgamation, value, container, error, KVC, archiver, plist, regex, uuid, math, time -->
# mulle-foundation-base

Use this topic when writing code for a project that depends on
`MulleFoundation`. This amalgamated library provides 11 platform-independent
Objective-C foundation libraries in a single link target.

## Understand first

```bash
mulle-sde api apropos foundation
mulle-sde api cat NSString
mulle-sde api cat NSArray
mulle-sde api cat NSError
```

## Local references

- **Umbrella header:** `src/MulleFoundation.h` — imports all 11 constituents.
- **Export registry:** `src/reflect/_MulleFoundation-export.h` — full public API list.
- **TOC/doc:** `asset/dox/TOC.md` — detailed API reference.
- **Constituent sources:** `src/MulleObjC{Value,Container,Standard,Time,Unicode,UUID,KVC,Math,Plist,Regex,Archiver}Foundation/`

## Import

```objc
#import <MulleFoundation/MulleFoundation.h>
```

Individual constituent imports (e.g. `#import <MulleObjCValueFoundation/NSString.h>`) also work.

## Dominant API families

| Family | Key classes | Primary headers |
|--------|-------------|-----------------|
| **Value** | NSString, NSNumber, NSData | `src/MulleObjCValueFoundation/NSString.h`, `NSNumber.h`, `NSData.h` |
| **Container** | NSArray, NSDictionary, NSSet, NSEnumerator, NSMutable variants | `src/MulleObjCContainerFoundation/NSArray.h`, `NSDictionary.h`, `NSSet.h` |
| **Standard** | NSError, NSException, NSNotification, NSCharacterSet, NSCalendarDate, NSSortDescriptor | `src/MulleObjCStandardFoundation/NSError.h`, `NSException.h`, `NSNotificationCenter.h` |
| **Time** | NSDate, NSTimer | `src/MulleObjCTimeFoundation/NSDate.h`, `NSTimer.h` |
| **KVC** | NSObject(KeyValueCoding) | `src/MulleObjCKVCFoundation/NSObject+KeyValueCoding.h` |
| **Plist** | NSPropertyListSerialization, MulleObjCPropertyListPrinting, streams | `src/MulleObjCPlistFoundation/NSPropertyListSerialization.h` |
| **Archiver** | NSCoder, MulleObjCArchiver, MulleObjCUnarchiver, NSKeyedArchiver | `src/MulleObjCArchiverFoundation/NSCoder.h` |
| **Regex** | NSString(Regex) | `src/MulleObjCRegexFoundation/NSString+Regex.h` |
| **UUID** | NSUUID, C-level uuid functions | `src/MulleObjCUUIDFoundation/NSUUID.h` |
| **Math** | NSNumber( Math) | `src/MulleObjCMathFoundation/` |

## Workflow

1. Import the umbrella header.
2. Choose value or container factory methods (never `+alloc`/`-init`/`-autorelease`).
3. Use explicit message sends, never dot-syntax.
4. Use `+[NSException raise:format:]` for error exits; use `NSError` + `mulleExtract` for recoverable errors.
5. Use `@try`/`@catch` (or the `NS_DURING`/`NS_HANDLER` macros) for exception handling.
6. Serialize with `NSPropertyListSerialization` or archive with `NSArchiver`/`NSKeyedArchiver`.
7. For regex or wildcard matching, use `NSString(Regex)` category methods (no `NSRegularExpression` class exists).
