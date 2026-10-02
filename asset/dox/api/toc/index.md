# MulleFoundation Library Documentation for AI
<!-- Keywords: ObjectiveC, amalgamation, collections, foundation, archiver, plist, unicode, UUID -->

## 1. Introduction & Purpose

MulleFoundation is an amalgamated library combining 11 core MulleFoundation
libraries into a single compilation unit. It aggregates platform-independent
Objective-C classes (containers, values, time, regex, plist, archiving, KVC,
math, unicode, UUID) without OS-specific dependencies.

**Advantages:**
- Single library to link against (`-lMulleFoundationBase`)
- Faster compilation than building all 11 constituents individually
- `#import` statements of individual libraries remain valid
- Can also use single unified import: `#import <MulleFoundation/MulleFoundation.h>`

**Dependencies:** `mulle-objc-list` (build tool), `MulleObjC` (runtime),
`math` (libm).

## 2. Key Concepts & Design Philosophy

- **Amalgamation Pattern**: Source files from all 11 constituents are copied
  into `src/` with `clibmode=copy`. Each constituent lives in its own
  subdirectory. The unification is a single build target, not a composition
  of sub-targets.
- **No OS Dependencies**: All 11 constituents are platform-independent.
  Platform-specific functionality lives in higher layers (e.g.,
  `MulleObjCOSFoundation`).
- **Object Initialization Style**: Avoid `+alloc`/`-init`/`-autorelease`.
  Prefer convenience constructors (`+stringWithString:`, `+array`, etc.)
  and factory methods. Never call `-release` except in `-dealloc`.
- **No dot-syntax**: Use explicit message sends for property access.
- **No blocks**: Do not use `^` block syntax.
- **Mixin Pattern**: Uses `@mixin` for cross-cutting concerns (e.g.,
  `MulleObjCPropertyListPrinting`, `MulleObjCOutputStream`).
- **SubclassesFuture Pattern**: Key methods like `-objectForKey:`, `-count`,
  `-objectAtIndex:` are declared in `SubclassesFuture` categories (conforming
  to `<MulleObjCFuture>`). Subclasses of the class cluster implement these,
  not the abstract base class.
- **`+[NSDate date]` and `+[NSString string]` are in `Future` categories**:
  The design prefers typed factory methods over the untyped convenience ones.

## 3. Core API & Data Structures

### 3.1. Unified Import Path

```objc
#import <MulleFoundation/MulleFoundation.h>
```

This umbrella header imports all 11 constituent headers. Individual constituent
imports also work:

```objc
#import <MulleObjCValueFoundation/MulleObjCValueFoundation.h>
#import <MulleObjCContainerFoundation/MulleObjCContainerFoundation.h>
// ... etc.
```

### 3.2. MulleObjCValueFoundation — Value Classes

**Location**: `src/MulleObjCValueFoundation/`
**Key Headers**: `NSString.h`, `NSNumber.h`, `NSData.h`, `NSMutableString.h`,
`NSMutableData.h`, `NSStringEncoding.h`, `NSConstantString.h`,
`NSString+NSData.h`, `NSString+Hash.h`, `NSString+Enumerator.h`,
`NSString+ClassCluster.h`, `NSString+Sprintf.h`, `mulle-chardata.h`

#### `NSString` (immutable string, class cluster)

```objc
@interface NSString : NSObject < MulleObjCClassCluster, MulleObjCImmutable, MulleObjCImmutableCopying>
```

- **Factory**: `+ (instancetype) string`, `+ (instancetype) stringWithString:(NSString *) other`
- **Init**: `- (instancetype) initWithString:(NSString *) s`
- **Substrings**: `- (NSString *) substringWithRange:(NSRange) range`,
  `- (NSString *) substringFromIndex:(NSUInteger) index`,
  `- (NSString *) substringToIndex:(NSUInteger) index`
- **Numeric conversion**: `- (BOOL) boolValue`, `- (int) intValue`,
  `- (NSInteger) integerValue`, `- (long long) longLongValue`,
  `- (float) floatValue`, `- (double) doubleValue`,
  `- (long double) mulleLongDoubleValue`
- **Comparison**: `- (BOOL) isEqualToString:(NSString *) other`,
  `- (BOOL) hasPrefix:(NSString *) prefix`, `- (BOOL) hasSuffix:(NSString *) suffix`
- **UTF32**: `+ (instancetype) stringWithCharacters:(unichar *) s length:(NSUInteger) len`,
  `- (void) getCharacters:(unichar *) buffer`
- **UTF8**: `+ (instancetype) stringWithUTF8String:(char *) s`,
  `- (char *) UTF8String`

#### `NSString( MulleAdditions)` category

- `- (NSUInteger) mulleUTF8StringLength`
- `- (BOOL) mulleFastGetASCIIData:(struct mulle_asciidata *) space`
- `- (BOOL) mulleFastGetUTF8Data:(struct mulle_utf8data *) space`
- `- (BOOL) mulleFastGetUTF16Data:(struct mulle_utf16data *) space`
- `- (BOOL) mulleFastGetUTF32Data:(struct mulle_utf32data *) space`
- `+ (instancetype) mulleStringWithCharactersNoCopy:(unichar *) s length:(NSUInteger) len allocator:(struct mulle_allocator *) allocator`
- `+ (instancetype) mulleStringWithUTF8CharactersNoCopy:(char *) s length:(NSUInteger) len allocator:(struct mulle_allocator *) allocator`
- `+ (instancetype) mulleStringWithUTF8Characters:(char *) s length:(NSUInteger) len`
- `- (void) mulleGetUTF8Characters:(char *) buf`
- `- (NSUInteger) mulleGetUTF8Characters:(char *) buf maxLength:(NSUInteger) maxLength`
- `- (NSUInteger) mulleGetUTF8Characters:(char *) buf maxLength:(NSUInteger) maxLength range:(NSRange) range`
- `- (NSUInteger) mulleGetUTF8String:(char *) buf bufferSize:(NSUInteger) size`
- `+ (BOOL) mulleAreValidUTF8Characters:(char *) buffer length:(NSUInteger) length`
- `+ (instancetype) mulleStringWithUTF16String:(mulle_utf16_t *) s`
- `- (mulle_utf16_t *) mulleUTF16String`
- Subclass requirements (`@optional`): `- (unichar) :(NSUInteger) index`,
  `- (NSUInteger) length`, `- (unichar) characterAtIndex:(NSUInteger) index`,
  `- (void) getCharacters:(unichar *) buffer range:(NSRange) range`

#### `NSString ( Future)` category

- `- (NSString *) stringByAppendingString:(NSString *) other`
- `- (NSString *) stringByPaddingToLength:(NSUInteger) length withString:(NSString *) other startingAtIndex:(NSUInteger) index`
- `- (NSString *) stringByReplacingOccurrencesOfString:(NSString *) search withString:(NSString *) replacement`

```objc
- (NSString *) stringByReplacingOccurrencesOfString:(NSString *) search
                                         withString:(NSString *) replacement
                                            options:(NSUInteger) options
                                              range:(NSRange) range;
```
- `- (NSString *) stringByReplacingCharactersInRange:(NSRange) range withString:(NSString *) replacement`
- `- (NSString *) mulleStringByRemovingPrefix:(NSString *) other`
- `- (NSString *) mulleStringByRemovingSuffix:(NSString *) other`

#### C Function

```c
struct mulle_utf8data   MulleStringUTF8Data( NSString *self, struct mulle_utf8data space);
```

#### `NSStringCompareOptions` (in `NSString.h`)

```c
enum {
   NSCaseInsensitiveSearch = 0x001,
   NSLiteralSearch         = 0x002,
   NSBackwardsSearch       = 0x004,
   NSAnchoredSearch        = 0x008,
   NSNumericSearch         = 0x040,
};
typedef NSUInteger   NSStringCompareOptions;
```

#### `NSStringEncoding` (header: `NSStringEncoding.h`)

Encoding constants: `NSASCIIStringEncoding` (1), `NSUTF8StringEncoding` (4),
`NSISOLatin1StringEncoding` (5), `NSUTF16StringEncoding` (10),
`NSMacOSRomanStringEncoding` (30), `NSUTF16BigEndianStringEncoding` (0x90000100),
`NSUTF16LittleEndianStringEncoding` (0x94000100), `NSUTF32StringEncoding` (0x8c000100),
`NSUTF32BigEndianStringEncoding` (0x98000100), `NSUTF32LittleEndianStringEncoding` (0x9c000100).

```c
type NSUInteger   NSStringEncoding;

type NS_OPTIONS( NSUInteger, MulleStringEncodingOptions) {
   MulleStringEncodingOptionBOM               = 1,
   MulleStringEncodingOptionBOMIfNeeded       = 2,
   MulleStringEncodingOptionTerminateWithZero = 4,
};

char              *MulleStringEncodingUTF8String( NSStringEncoding encoding);
NSStringEncoding   MulleStringEncodingParseUTF8String( char *s);
```

#### `NSNumber` (immutable numeric value, class cluster)

```objc
@interface NSNumber : NSValue < NSCopying, MulleObjCImmutableCopying, MulleObjCClassCluster>
```

- **Factory** (all typed): `+ (instancetype) numberWithBool:(BOOL) value`,
  `numberWithChar:(char) value`, `numberWithUnsignedChar:`, `numberWithShort:`,
  `numberWithUnsignedShort:`, `numberWithInt:`, `numberWithUnsignedInt:`,
  `numberWithInteger:(NSInteger) value`, `numberWithUnsignedInteger:(NSUInteger) value`,
  `numberWithLong:`, `numberWithUnsignedLong:`, `numberWithLongLong:(long long) value`,
  `numberWithUnsignedLongLong:(unsigned long long) value`,
  `numberWithFloat:(float) value`, `numberWithDouble:(double) value`,
  `numberWithLongDouble:(long double) value` (if `_C_LNG_DBL`)
- **Init** mirrors the factory methods with `initWith...:`
- **Access**: `- (BOOL) boolValue`, `- (char) charValue`,
  `- (unsigned char) unsignedCharValue`, `- (short) shortValue`,
  `- (unsigned short) unsignedShortValue`, `- (int) intValue`,
  `- (unsigned int) unsignedIntValue`, `- (long) longValue`,
  `- (unsigned long) unsignedLongValue`, `- (float) floatValue`,
  `- (unsigned long long) unsignedLongLongValue`,
  `- (NSUInteger) unsignedIntegerValue`
- `SubclassesFuture`: `- (NSInteger) integerValue`, `- (double) doubleValue`,
  `- (long double) longDoubleValue` (if `_C_LNG_DBL`), `- (long long) longLongValue`
- **Comparison**: `- (NSComparisonResult) compare:(id) other`,
  `- (BOOL) isEqualToNumber:(id) other`

#### `NSString+Hash.h` — String Hashing

Provides `- (NSUInteger) hash` on `NSString`.

#### `NSString+Sprintf.h`

Creation from format strings: `+ (instancetype) mulleStringWithSprintfFormat:(NSString *) format, ...`,
`- (instancetype) mulleStringByAppendingSprintfFormat:(NSString *) format, ...`.

#### `NSString+NSData.h` — String ⇄ Data Conversion

Import/export of strings from/to `NSData` with encoding. Validates encoding
correctness on import. `- initWithData:encoding:` / `- dataUsingEncoding:`
available via this header.

#### `NSData` and `NSMutableData`

```objc
@interface NSData : NSObject < NSCopying, MulleObjCImmutableCopying, MulleObjCClassCluster>

+ (instancetype) data;
+ (instancetype) dataWithBytes:(void *) bytes length:(NSUInteger) length;
+ (instancetype) dataWithBytesNoCopy:(void *) bytes length:(NSUInteger) length;
+ (instancetype) dataWithBytesNoCopy:(void *) bytes length:(NSUInteger) length freeWhenDone:(BOOL) flag;
+ (instancetype) dataWithData:(NSData *) data;
+ (instancetype) mulleDataWithCData:(struct mulle_cdata) cdata;
```

`NSMutableData` extends `NSData` with mutation: `+ (instancetype) dataWithCapacity:(NSUInteger) n`,
`+ (instancetype) dataWithLength:(NSUInteger) length`, `- (void) appendBytes:length:`,
`- (void) appendData:`, `- (void) setData:`, etc.

### 3.3. MulleObjCStandardFoundation — Standard Base Classes

**Location**: `src/MulleObjCStandardFoundation/`
**Key Headers**: `NSCalendarDate.h`, `NSError.h`, `NSException.h`,
`NSNotification.h`, `NSNotificationCenter.h`, `NSAssertionHandler.h`,
`NSCharacterSet.h`, `NSDateFormatter.h`, `NSLocale.h`, `NSSortDescriptor.h`,
`NSString+NSLocale.h`, `NSTimeZone.h`

#### `NSCalendarDate`

```objc
@interface NSCalendarDate : NSDate < NSDateFactory, MulleObjCClassCluster, MulleObjCValueProtocols>

+ (instancetype) calendarDate;
+ (instancetype) dateWithYear:(NSInteger) year
                        month:(NSUInteger) month
                          day:(NSUInteger) day
                         hour:(NSUInteger) hour
                       minute:(NSUInteger) minute
                       second:(NSUInteger) second
                     timeZone:(NSTimeZone *) tz;
- (instancetype) initWithYear:(NSInteger) year
                        month:(NSUInteger) month
                          day:(NSUInteger) day
                         hour:(NSUInteger) hour minute:(NSUInteger) minute
                       second:(NSUInteger) second
                     timeZone:(NSTimeZone *) aTimeZone;
```

NSCalendarDate always has a timeZone. It is integer-based (no subsecond precision).
For NSTimeInterval, use NSDate.

`Subclasses` category (Future):
- `- (struct mulle_mini_tm) mulleMiniTM`
- `- (NSInteger) secondOfMinute`, `- (NSInteger) minuteOfHour`,
  `- (NSInteger) hourOfDay`, `- (NSInteger) dayOfMonth`,
  `- (NSInteger) monthOfYear`, `- (NSInteger) yearOfCommonEra`,
  `- (NSTimeZone *) timeZone`
- `- (BOOL) isEqualToCalendarDate:(NSCalendarDate *) date`

`Future` category:
- `- (instancetype) initWithDate:(NSDate *) date`
- `- (instancetype) mulleInitWithDate:(NSDate *) date timeZone:(NSTimeZone *) tz`
- `- (instancetype) initWithTimeIntervalSince1970:(NSTimeInterval) timeInterval`
- `- (instancetype) mulleInitWithTimeIntervalSince1970:(NSTimeInterval) interval timeZone:(NSTimeZone *) tz`
- `- (instancetype) initWithTimeIntervalSinceReferenceDate:(NSTimeInterval) timeInterval`
- `- (NSInteger) dayOfWeek`, `- (NSInteger) dayOfYear`
- `- (instancetype) dateByAddingYears:(NSInteger) year months:(NSInteger) month days:(NSInteger) day hours:(NSInteger) hour minutes:(NSInteger) minute seconds:(NSInteger) second`

#### `NSError`

```objc
@interface NSError : NSObject < MulleObjCImmutableProtocols>
```

**Domain registration** (static):
- `+ (void) registerErrorDomain:(NSErrorDomain) domain errorStringFunction:(NSString *(*)( NSInteger)) translator`
- `+ (void) removeErrorDomain:(NSErrorDomain) domain`

**Error stack** (static):
- `+ (void) mulleSetErrorDomain:(NSString *) domain`
- `+ (NSString *) mulleErrorDomain`
- `+ (void) mulleSetError:(NSError *) error`
- `+ (void) mulleSetErrorCode:(NSInteger) code domain:(NSString *) domain userInfo:(NSDictionary *) userInfo`
- `+ (instancetype) mulleExtract`
- `+ (void) mulleClear`
- `+ (void) mulleSetGenericErrorWithDomain:(NSString *) domain localizedDescription:(NSString *) s`
- `+ (instancetype) mulleGenericErrorWithDomain:(NSString *) domain localizedDescription:(NSString *) s`

**C functions**:
- `void MulleObjCSetErrorCode( NSInteger code, NSString *domain, NSDictionary *userInfo)`
- `void MulleObjCSetErrorDomain( NSString *domain)`
- `NSString *MulleObjCGetErrorDomain( void)`
- `NSError *MulleObjCExtractError( void)`
- `void MulleObjCClearError( void)`

**Recovery**: `NSObject( RecoveryAttempting)` with
`- (void) attemptRecoveryFromError:(NSError *) error optionIndex:(NSUInteger) recoveryOptionIndex delegate:(id) delegate didRecoverSelector:(SEL) didRecoverSelector contextInfo:(void *) contextInfo`
and `- (BOOL) attemptRecoveryFromError:(NSError *) error optionIndex:(NSUInteger) recoveryOptionIndex`.

#### `NSException`

```objc
@interface NSException : NSObject < MulleObjCException, MulleObjCImmutableProtocols>

+ (NSException *) exceptionWithName:(NSString *) name
                              reason:(NSString *) reason
                            userInfo:(id) userInfo;
+ (void) raise:(NSString *) name
         format:(NSString *) format mulleVarargList:(mulle_vararg_list) args;
+ (void) raise:(NSString *) name
         format:(NSString *) format
      arguments:(va_list) va;
+ (void) raise:(NSString *) name
         format:(NSString *) format, ...;
- (instancetype) initWithName:(NSString *) name
                        reason:(NSString *) reason
                      userInfo:(NSDictionary *) userInfo;
```

Exception name globals: `NSInternalInconsistencyException`, `NSGenericException`,
`NSInvalidArgumentException`, `NSMallocException`, `NSRangeException`, `NSParseErrorException`.

Macros: `NS_DURING` / `NS_HANDLER` / `NS_ENDHANDLER`.

#### `NSNotification`

```objc
@interface NSNotification : NSObject < MulleObjCImmutableProtocols>

+ (instancetype) notificationWithName:(NSString *) aName object:(id) anObject;
+ (instancetype) notificationWithName:(NSString *) aName
                               object:(id) anObject
                             userInfo:(id <NSCopying, MulleObjCRuntimeObject>) userInfo;
```

`NSNotificationCenter` is the singleton dispatch: `+ (instancetype) defaultCenter`.

#### `NSSortDescriptor`

```objc
@interface NSSortDescriptor : NSObject < NSCopying>
+ (instancetype) sortDescriptorWithKey:(NSString *) key ascending:(BOOL) flag;
- (instancetype) initWithKey:(NSString *) key ascending:(BOOL) flag;
- (instancetype) initWithKey:(NSString *) key ascending:(BOOL) flag selector:(SEL) selector;
```

#### `NSDateFormatter`

```objc
@interface NSDateFormatter : NSFormatter
+ (void) mulleSetClass:(Class) cls forFormatterBehavior:(NSDateFormatterBehavior) behavior;
- (NSString *) stringFromDate:(NSDate *) date;
- (NSDate *) dateFromString:(NSString *) s;
```

#### `NSTimeZone`

```objc
@interface NSTimeZone : NSObject < NSCopying>
+ (instancetype) timeZoneWithName:(NSString *) name;
+ (instancetype) timeZoneWithAbbreviation:(NSString *) abbreviation;
+ (instancetype) defaultTimeZone;
+ (instancetype) localTimeZone;
+ (instancetype) systemTimeZone;
- (NSString *) name;
- (NSString *) abbreviation;
- (NSInteger) secondsFromGMTForDate:(NSDate *) date;
- (NSTimeInterval) daylightSavingTimeOffsetForDate:(NSDate *) date;
- (BOOL) isDaylightSavingTimeForDate:(NSDate *) date;
```

#### `NSLocale` (expanded)

```objc
@interface NSLocale : NSObject < MulleObjCImmutableProtocols >

+ (instancetype) localeWithLocaleIdentifier:(NSString *) s;
+ (instancetype) autoupdatingCurrentLocale;
+ (instancetype) systemLocale;
+ (instancetype) currentLocale;

- (NSString *) localeIdentifier;
- (NSString *) languageCode;
- (NSString *) scriptCode;
- (NSString *) variantCode;
- (NSString *) collationIdentifier;
- (NSString *) currencyCode;
- (NSString *) calendarIdentifier;

- (NSString *) displayNameForKey:(id) key value:(id) value;

- (NSString *) localizedStringForLocaleIdentifier:(NSString *) localeIdentifier;
- (NSString *) localizedStringForCountryCode:(NSString *) countryCode;
- (NSString *) localizedStringForLanguageCode:(NSString *) languageCode;
- (NSString *) localizedStringForScriptCode:(NSString *) scriptCode;
- (NSString *) localizedStringForVariantCode:(NSString *) variantCode;
- (NSString *) localizedStringForCollationIdentifier:(NSString *) collationIdentifier;
- (NSString *) localizedStringForCollatorIdentifier:(NSString *) collatorIdentifier;
- (NSString *) localizedStringForCurrencyCode:(NSString *) currencyCode;
- (NSString *) localizedStringForCalendarIdentifier:(NSString *) calendarIdentifier;
```

`NSLocale( Future)` conforms to `< MulleObjCFuture>` and provides:
`+[NSLocale _systemLocale]`, `+[NSLocale _currentLocale]`,
`+[NSLocale availableLocaleIdentifiers]`, `+[NSLocale ISOLanguageCodes]`,
`+[NSLocale ISOCountryCodes]`, `+[NSLocale ISOCurrencyCodes]`,
`+[NSLocale componentsFromLocaleIdentifier:]`,
`+[NSLocale localeIdentifierFromComponents:]`,
`+[NSLocale canonicalLocaleIdentifierFromString:]`,
`+[NSLocale canonicalLanguageIdentifierFromString:]`,
`-[NSLocale :(id) key]` (shortcut for objectForKey:),
`-[NSLocale objectForKey:(id) key]`,
`-[NSLocale isEqualToLocale:]`,
`-[NSLocale initWithLocaleIdentifier:]`.

Numerous `NSString` constant keys are exported: `NSLocaleCalendar`,
`NSLocaleCollationIdentifier`, `NSLocaleCurrencyCode`, `NSLocaleCurrencySymbol`,
`NSLocaleDecimalSeparator`, `NSLocaleGroupingSeparator`, `NSLocaleIdentifier`,
`NSLocaleLanguageCode`, `NSLocaleMeasurementSystem`,
`NSLocaleQuotationBeginDelimiterKey`, `NSLocaleQuotationEndDelimiterKey`,
`NSLocaleScriptCode`, `NSLocaleUsesMetricSystem`, `NSLocaleVariantCode`,
`NSAMPMDesignation`, `NSDateFormatString`, `NSDateTimeOrdering`,
`NSMonthNameArray`, `NSShortDateFormatString`, `NSShortMonthNameArray`,
`NSTimeFormatString`, `NSWeekDayNameArray`, `NSCurrencySymbol`,
`NSDecimalSeparator`, `NSThousandsSeparator`, etc.

#### `NSCharacterSet`

```objc
@interface NSCharacterSet : NSObject < NSCopying, MulleObjCClassCluster>

- (instancetype) initWithBitmapRepresentation:(NSData *) data;
- (NSData *) bitmapRepresentation;
- (BOOL) isSupersetOfSet:(NSCharacterSet *) set;
- (BOOL) longCharacterIsMember:(long) c;
+ (instancetype) characterSetWithCharactersInString:(NSString *) s;
- (void) mulleGetBitmapBytes:(unsigned char *) bytes plane:(NSUInteger) plane;

// Predefined sets:
+ (instancetype) alphanumericCharacterSet;
+ (instancetype) controlCharacterSet;
+ (instancetype) capitalizedLetterCharacterSet;
+ (instancetype) decimalDigitCharacterSet;
+ (instancetype) letterCharacterSet;
+ (instancetype) lowercaseLetterCharacterSet;
+ (instancetype) punctuationCharacterSet;
+ (instancetype) symbolCharacterSet;
+ (instancetype) uppercaseLetterCharacterSet;
+ (instancetype) whitespaceAndNewlineCharacterSet;
+ (instancetype) whitespaceCharacterSet;
```

`SubclassesFuture`: `- (BOOL) characterIsMember:(unichar) c`,
`- (BOOL) hasMemberInPlane:(NSUInteger) plane`,
`- (NSCharacterSet *) invertedSet`.

`unichar` is `typedef mulle_utf32_t unichar`.

#### `NSAssertionHandler`

```objc
@interface NSAssertionHandler : NSObject < MulleObjCImmutableProtocols>

+ (NSAssertionHandler *) currentHandler;
- (void) handleFailureInMethod:(SEL) selector
                         object:(id) object
                           file:(NSString *) fileName
                     lineNumber:(NSInteger) line
                    description:(NSString *) format, ...;
- (void) handleFailureInFunction:(NSString *) functionName
                             file:(NSString *) fileName
                       lineNumber:(NSInteger) line
                      description:(NSString *) format, ...;
```

Assertion macros: `NSAssert` / `NSCAssert` / `NSParameterAssert` /
`NSCParameterAssert` (delegate to `MulleObjCAssert` / `MulleObjCCAssert`).

### 3.4. MulleObjCContainerFoundation — Containers

**Location**: `src/MulleObjCContainerFoundation/`
**Key Headers**: `NSArray.h`, `NSMutableArray.h`, `NSDictionary.h`,
`NSMutableDictionary.h`, `NSSet.h`, `NSMutableSet.h`, `NSEnumerator.h`,
`NSArray+NSEnumerator.h`, `NSDictionary+NSEnumerator.h`

#### `NSArray` (immutable array, class cluster)

```objc
@interface NSArray : MulleObjCContainer < NSArray, MulleObjCClassCluster, MulleObjCImmutableCopying>

+ (instancetype) array;
+ (instancetype) arrayWithArray:(NSArray *) other;
+ (instancetype) arrayWithObject:(id) obj;
+ (instancetype) arrayWithObjects:(id) firstObject, ...;
+ (instancetype) arrayWithObjects:(id *) objects count:(NSUInteger) count;

- (instancetype) initWithArray:(NSArray *) other;
- (instancetype) initWithArray:(NSArray *) other copyItems:(BOOL) flag;
- (instancetype) initWithObjects:(id) firstObject, ...;
- (instancetype) initWithObjects:(id *) objects count:(NSUInteger) count;
- (NSArray *) arrayByAddingObject:(id) obj;
- (NSArray *) arrayByAddingObjectsFromArray:(NSArray *) other;
- (BOOL) containsObject:(id) obj;
- (BOOL) containsObject:(id) obj inRange:(NSRange) range;
- (NSUInteger) indexOfObject:(id) obj;
- (NSUInteger) indexOfObject:(id) obj inRange:(NSRange) range;
- (NSUInteger) indexOfObjectIdenticalTo:(id) obj;
- (NSUInteger) indexOfObjectIdenticalTo:(id) obj inRange:(NSRange) range;
- (id) firstObjectCommonWithArray:(NSArray *) other;
- (id) lastObject;
- (BOOL) isEqualToArray:(NSArray *) other;
- (NSArray *) sortedArrayUsingSelector:(SEL) comparator;
- (NSArray *) sortedArrayUsingFunction:(NSComparisonResult (*)(id, id, void *)) comparator context:(void *) context;
- (NSArray *) subarrayWithRange:(NSRange) range;
- (void) getObjects:(id *) objects;
```

`NSArray( MulleAdditions)`: `+ (instancetype) mulleArrayWithArray:(NSArray *) other range:(NSRange) range`,
`+ (instancetype) mulleArrayWithRetainedObjects:(id *) objects count:(NSUInteger) count`,
`- (instancetype) mulleInitWithArray:andObject:`, `- (instancetype) mulleInitWithArray:andArray:`,
`- (id) mulleForEachObjectCallFunction:(BOOL (*)( id, void *)) f argument:(void *) userInfo preempt:(enum MullePreempt) preempt`,
`- (id) mulleFirstObject`, `- (BOOL) mulleContainsObjectIdenticalTo:(id) obj`.

`SubclassesFuture`: `- (id) :(NSUInteger) index`, `- (id) objectAtIndex:(NSUInteger) index`,
`- (void) getObjects:(id *) objects range:(NSRange) range`, and `<NSFastEnumeration>`.

#### `NSMutableArray`

```objc
@interface NSMutableArray : NSArray < NSMutableArray, MulleObjCMutableContainerProtocols>

+ (instancetype) arrayWithCapacity:(NSUInteger) capacity;
- (instancetype) initWithCapacity:(NSUInteger) capacity;
- (void) addObject:(id) obj;
- (void) addObjectsFromArray:(NSArray *) otherArray;
- (void) insertObject:(id) obj atIndex:(NSUInteger) index;
- (void) replaceObjectAtIndex:(NSUInteger) index withObject:(id) obj;
- (void) replaceObjectsInRange:(NSRange) range withObjects:(id *) objects count:(NSUInteger) count;
- (void) replaceObjectsInRange:(NSRange) aRange withObjectsFromArray:(NSArray *) other;
- (void) removeLastObject;
- (void) removeObject:(id) obj;
- (void) removeObjectAtIndex:(NSUInteger) index;
- (void) removeObjectsInRange:(NSRange) range;
- (void) removeObjectIdenticalTo:(id) obj;
- (void) removeObjectIdenticalTo:(id) obj inRange:(NSRange) range;
- (void) removeAllObjects;
- (void) exchangeObjectAtIndex:(NSUInteger) index1 withObjectAtIndex:(NSUInteger) index2;
- (void) setArray:(NSArray *) other;
- (void) sortUsingSelector:(SEL) comparator;
- (void) sortUsingFunction:(NSComparisonResult (*)(id, id, void *)) compare context:(void *) context;
```

Mulle additions: `- (void) mulleAddRetainedObject:(id) obj`,
`- (void) mulleReverseObjects`,
`- (void) mulleMoveObjectsInRange:(NSRange) range toIndex:(NSUInteger) index`,
`- (id) mulleRemoveLastObject`.

#### `NSDictionary` (immutable dictionary, class cluster)

```objc
@interface NSDictionary : MulleObjCContainer < NSDictionary, MulleObjCClassCluster, MulleObjCImmutable, MulleObjCImmutableCopying >

+ (instancetype) dictionary;
+ (instancetype) dictionaryWithDictionary:(NSDictionary *) dictionary;
+ (instancetype) dictionaryWithObject:(id) anObject forKey:(id<NSObject, MulleObjCImmutableCopying>) aKey;
+ (instancetype) dictionaryWithObjects:(id *) objects forKeys:(id *) keys count:(NSUInteger) count;
+ (instancetype) dictionaryWithObjectsAndKeys:(id) firstObject , ...;

- (instancetype) initWithDictionary:(NSDictionary *) otherDictionary;
- (instancetype) initWithDictionary:(NSDictionary *) otherDictionary copyItems:(BOOL) flag;
- (instancetype) initWithObjects:(id *) objects forKeys:(id *) keys count:(NSUInteger) count;
- (instancetype) initWithObjectsAndKeys:(id)firstObject , ...;
- (BOOL) isEqualToDictionary:(NSDictionary *) other;
- (void) getObjects:(id *) objects andKeys:(id *) keys;
```

Mulle additions: `- (id) mulleForEachObjectAndKeyCallFunction:(BOOL (*)( id, id, void *)) f argument:(void *) userInfo preempt:(enum MullePreempt) preempt`,
`- (NSInteger) mulleCountCollisions:(NSInteger *) perfects`.

`SubclassesFuture` (`<NSFastEnumeration, MulleObjCFuture>`):
`- (NSEnumerator *) keyEnumerator`,
`- (id) :(id) key` (shortcut), `- (id) objectForKey:(id) key`,
`- (void) getObjects:(id *) objects andKeys:(id *) keys count:(NSUInteger) count`.

#### `NSMutableDictionary`

```objc
@interface NSMutableDictionary : NSDictionary < NSMutableDictionary, MulleObjCClassCluster>

+ (instancetype) dictionaryWithCapacity:(NSUInteger) capacity;
```

`SubclassesFuture`: `- (instancetype) initWithCapacity:(NSUInteger) capacity`,
`- (void) setObject:(id) anObject forKey:(id <NSObject, MulleObjCImmutableCopying>) aKey`,
`- (void) removeObjectForKey:(id)aKey`,
`- (void) removeAllObjects`,
`- (void) addEntriesFromDictionary:(NSDictionary *) other`,
`- (void) setDictionary:(NSDictionary *) other`,
`- (void) mulleSetRetainedObject:(id) anObject forKey:(id <NSObject, MulleObjCImmutableCopying>) aKey`,
`- (void) mulleSetRetainedObject:(id) anObject forCopiedKey:(id <NSObject, MulleObjCImmutableCopying>) aKey`.

#### `NSSet` / `NSMutableSet`

```objc
@interface NSSet : MulleObjCContainer < NSSet, MulleObjCClassCluster, MulleObjCImmutable, MulleObjCImmutableCopying>

+ (instancetype) set;
+ (instancetype) setWithObject:(id) object;
+ (instancetype) setWithObjects:(id) object, ...;
+ (instancetype) setWithObjects:(id *) objects count:(NSUInteger) count;
+ (instancetype) setWithSet:(NSSet *) set;
- (instancetype) initWithSet:(NSSet *) set;
- (instancetype) initWithSet:(NSSet *) set copyItems:(BOOL) flag;
- (NSSet *) setByAddingObject:(id) object;
- (NSSet *) setByAddingObjectsFromSet:(NSSet *) set;
- (BOOL) containsObject:(id) object;
- (BOOL) isSubsetOfSet:(NSSet *) set;
- (BOOL) intersectsSet:(NSSet *) set;
- (BOOL) isEqualToSet:(NSSet *) set;
- (id) :(id) object;  // shortcut for member:
```

`SubclassesFuture` (`<NSFastEnumeration, MulleObjCFuture>`):
`- (NSUInteger) count`, `- (id) member:(id) object`,
`- (NSEnumerator *) objectEnumerator`.

`NSMutableSet` extends with: `+ (instancetype) setWithCapacity:(NSUInteger) numItems`,
`- (void) addObject:`, `- (void) removeObject:`, `- (void) removeAllObjects`,
`- (void) unionSet:`, `- (void) intersectSet:`, `- (void) minusSet:`,
`- (void) setSet:`, `- (id) mulleRegisterObject:(id) object`.

#### `NSEnumerator`

```objc
@protocol NSEnumerator
- (id) nextObject;
- (id <NSArray>) allObjects;
@end

@interface NSEnumerator : NSObject
@end
```

Categories on `NSArray` provide `-objectEnumerator` and `-reverseObjectEnumerator`.
Categories on `NSDictionary` provide `-keyEnumerator`, `-objectEnumerator`, and
`-anyKey`.

### 3.5. MulleObjCTimeFoundation — Time & Date

**Location**: `src/MulleObjCTimeFoundation/`
**Key Headers**: `NSDate.h`, `NSTimeInterval.h`, `NSTimer.h`

#### `NSDate` (class cluster)

```objc
@interface NSDate : NSObject < MulleObjCClassCluster, NSDateFactory, MulleObjCImmutable>

+ (instancetype) dateWithTimeIntervalSince1970:(NSTimeInterval) seconds;
+ (instancetype) dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval) seconds;
+ (instancetype) distantFuture;
+ (instancetype) distantPast;
- (instancetype) initWithTimeInterval:(NSTimeInterval) seconds sinceDate:(NSDate *) refDate;
- (instancetype) initWithTimeIntervalSince1970:(NSTimeInterval) seconds;
- (NSComparisonResult) compare:(id) other;
- (instancetype) dateByAddingTimeInterval:(NSTimeInterval) seconds;
- (NSDate *) earlierDate:(NSDate *) other;
- (NSDate *) laterDate:(NSDate *) other;
- (NSTimeInterval) timeIntervalSince1970;
- (NSTimeInterval) timeIntervalSinceDate:(NSDate *) other;
```

`SubclassesFuture`: `- (instancetype) initWithTimeIntervalSinceReferenceDate:(NSTimeInterval) seconds`,
`- (NSTimeInterval) timeIntervalSinceReferenceDate`.
`Future`: `+ (NSDate *) date`, `+ (NSTimeInterval) timeIntervalSinceReferenceDate`.

#### `NSTimeInterval` (in `NSTimeInterval.h`)

```c
typedef mulle_calendartime_t    NSTimeInterval;
#define NSTimeIntervalSince1970  978307200.0
```

#### `NSTimer` (immutable, relative-time based)

```c
typedef void   NSTimerCallback_t( NSTimer *, id userInfo);
```

```objc
@interface NSTimer : NSObject < MulleObjCImmutableProtocols>

+ (instancetype) mulleTimerWithRelativeTimeInterval:(mulle_relativetime_t) seconds
                                     repeatInterval:(mulle_relativetime_t) repeatSeconds
                                         invocation:(NSInvocation *) invocation;

+ (instancetype) mulleTimerWithRelativeTimeInterval:(mulle_relativetime_t) seconds
                                     repeatInterval:(mulle_relativetime_t) repeatSeconds
                                             target:(id) target
                                           selector:(SEL) sel
                                           userInfo:(id) userInfo
                         fireUsesUserInfoAsArgument:(BOOL) flag;

+ (instancetype) mulleTimerWithRelativeTimeInterval:(mulle_relativetime_t) seconds
                                     repeatInterval:(mulle_relativetime_t) repeatSeconds
                                           callback:(NSTimerCallback_t) callback
                                           userInfo:(id) userInfo;

- (BOOL) isValid;
- (void) fire;
- (BOOL) mulleIsRelativeTimer;
- (mulle_relativetime_t) mulleRelativeTimeInterval;
- (mulle_relativetime_t) mulleRepeatTimeInterval;
```

**NSTimer is immutable** and uses `mulle_relativetime_t` (relative time, not
wall-clock). There is **no `-invalidate` method** — the runloop/application
removes the timer when invalidated. Timers must be added to a runloop or
UIApplication after creation.

### 3.6. MulleObjCUnicodeFoundation — Unicode Support

**Location**: `src/MulleObjCUnicodeFoundation/`
**Key Headers**: `NSString+MulleObjCUnicode.h`, `NSCharacterSet+MulleObjCUnicode.h`,
`NSMutableCharacterSet+MulleObjCUnicode.h`

Extends `NSString` with Unicode-aware operations (uppercase, lowercase, capitalization,
decaptalization via `NSString( MulleObjCUnicode)` category).

Extends `NSCharacterSet` with additional predefined sets:
- `+ (instancetype) capitalizedLetterCharacterSet`
- `+ (instancetype) nonBaseCharacterSet`
- `+ (instancetype) decomposableCharacterSet`
- `+ (instancetype) illegalCharacterSet`

### 3.7. MulleObjCUUIDFoundation — UUIDs

**Location**: `src/MulleObjCUUIDFoundation/`
**Key Headers**: `NSUUID.h`, `uuid4.h`

#### `NSUUID` (subclass of NSData, exactly 16 bytes)

```objc
#define MulleUUIDBytesLength   16
#define MulleUUIDStringLength  37

@interface NSUUID : NSData < MulleObjCValueProtocols>
{
   unsigned char  _bytes[ MulleUUIDBytesLength];
}

+ (instancetype) UUID;
- (instancetype) initWithUUIDString:(NSString *) s;
- (instancetype) initWithUUIDBytes:(unsigned char *) bytes;
- (void) getUUIDBytes:(unsigned char *) bytes;
- (NSString *) UUIDString;
@end
```

Format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` (version 4, variant 1).

#### C-level UUID functions

```c
// Thread-safe random UUID generation
void   MulleGenerateUUIDBytes( unsigned char bytes[ MulleUUIDBytesLength]);

// Generate output string (including \0) of strict format
void   MulleUUIDBytesToUTF8String( unsigned char bytes[ MulleUUIDBytesLength],
                                   char output[ MulleUUIDStringLength]);

// Return -1 if input is incompatible
int    MulleUTF8StringToUUIDBytes( char input[ MulleUUIDStringLength],
                                   unsigned char bytes[ MulleUUIDBytesLength]);

// Inline helpers:
static inline void   MulleUUIDBytesZeroVersioningBits( unsigned char bytes[ MulleUUIDBytesLength]);
static inline unsigned int   MulleUUIDBytesGetVersion( unsigned char bytes[ MulleUUIDBytesLength]);
static inline int   MulleUTF8StringGetUUIDVersion( char s[ MulleUUIDStringLength]);
static inline int   MulleUTF8StringGetUUIDVariant( char s[ MulleUUIDStringLength]);
```

`MulleGenerateUUIDBytes` is thread-safe.

### 3.8. MulleObjCKVCFoundation — Key-Value Coding

**Location**: `src/MulleObjCKVCFoundation/`
**Key Headers**: `NSObject+KeyValueCoding.h`, `NSObject+KVCSupport.h`

**Primary category** (`NSObject( _KeyValueCoding)`):

```objc
- (id) valueForKey:(NSString *) key;
- (void) takeValue:(id) value forKey:(NSString *) key;

+ (BOOL) useStoredAccessor;
- (id) storedValueForKey:(NSString *) key;
- (void) takeStoredValue:(id) value forKey:(NSString *) key;

- (id) valueForKeyPath:(NSString *) keyPath;
- (void) takeValue:(id) value forKeyPath:(NSString *) keyPath;

- (id) handleQueryWithUnboundKey:(NSString *) key;
- (id) valueForUndefinedKey:(NSString *) key;
- (void) handleTakeValue:(id) value forUnboundKey:(NSString *) key;
- (void) unableToSetNilForKey:(NSString *) key;

- (NSDictionary *) valuesForKeys:(NSArray *) keys;
- (void) takeValuesFromDictionary:(NSDictionary *) properties;
```

**Compatibility category** (`NSObject( _KeyValueCodingCompatibility)`) — "modern" KVC:

```objc
- (void) setValue:(id) value forKey:(NSString *) key;
- (void) setValue:(id) value forKeyPath:(NSString *) key;
- (void) setValue:(id) value forUndefinedKey:(NSString *) key;
- (void) setNilValueForKey:(NSString *) key;
- (NSDictionary *) dictionaryWithValuesForKeys:(NSArray *) keys;
```

**Support** (`NSObject( KVCSupport)`):
`- (void) _getKVCInformation:(struct _MulleObjCKVCInformation *) kvcInfo forKey:(id <NSStringFuture>) key methodType:(enum _MulleObjCKVCMethodType) type`

KVC collection operators (e.g., `@"@count"`, `@"@avg.value"`, `@"@max.value"`)
are supported on array-valued properties.

### 3.9. MulleObjCMathFoundation — Math Library

**Location**: `src/MulleObjCMathFoundation/`

Provides the `math` (libm) C library dependency for the amalgamation. No
additional Objective-C API headers — the component ensures that trigonometric,
exponential, logarithmic, and rounding functions from libm are available
to builds that link against `MulleFoundation`.

### 3.10. MulleObjCPlistFoundation — Property List I/O

**Location**: `src/MulleObjCPlistFoundation/`
**Key Headers**: `MulleObjCPlistFoundation.h`, `MulleObjCPropertyListPrinting.h`,
`MulleObjCStream.h`, `NSPropertyListSerialization.h`

#### Streams (`MulleObjCStream.h`)

```objc
@protocol MulleObjCInputStream < NSObject>
- (NSData *) readDataOfLength:(NSUInteger) length;
@end

@mixin MulleObjCOutputStream < NSObject>
@required
- (void) mulleWriteBytes:(void *) bytes length:(NSUInteger) length;
@optional
- (void) writeData:(NSData *) data;
- (void) mulleWriteUTF8String:(char *) s;
@end
```

`MulleObjCInMemoryInputStream` wraps `NSData` as input stream.
`NSMutableData( MulleObjCOutputStream)` conforms to `MulleObjCOutputStream`.

#### Property List Printing (`MulleObjCPropertyListPrinting.h`)

```objc
@mixin MulleObjCPropertyListPrinting < NSObject>
- (void) mullePrintPlist:(struct MulleObjCPrintPlistContext *) ctxt;
- (void) mullePrintJSON:(struct MulleObjCPrintPlistContext *) ctxt;
@optional
- (NSString *) mullePropertyListDescription;
- (NSString *) mulleJSONDescription;
- (void) mullePrintPlistToStream:(id <MulleObjCOutputStream>) handle;
- (void) mullePrintLoosePlistToStream:(id <MulleObjCOutputStream>) handle;
- (void) mullePrintJSONToStream:(id <MulleObjCOutputStream>) handle;
@end
```

Context functions: `MulleObjCPrintPlistContextInit`,
`MulleObjCPrintPlistContextSetHandle`,
`MulleObjCPrintPlistContextUTF8Indentation`,
`MulleObjCPrintPlistContextWriteUTF8String`,
`MulleObjCPrintPlistContextWriteBytes`,
`MulleObjCPrintPlistContextWriteUTF8Indentation`.

#### `NSPropertyListSerialization`

```objc
@interface NSPropertyListSerialization : NSObject

+ (void) mulleAddFormatDetector:(SEL) detector;
+ (void) mulleAddParserClass:(Class) parserClass method:(SEL) method forPropertyListFormat:(NSPropertyListFormat) format;
+ (void) mulleAddPrintMethod:(SEL) method forPropertyListFormat:(NSPropertyListFormat) format;

+ (BOOL) propertyList:(id) plist isValidForFormat:(NSPropertyListFormat) format;

+ (NSData *) dataFromPropertyList:(id) plist format:(NSPropertyListFormat) format errorDescription:(NSString **) errorString;

+ (NSData *) dataWithPropertyList:(id) plist format:(NSPropertyListFormat) format options:(NSPropertyListWriteOptions) options error:(NSError **) p_error;

+ (id) mullePropertyListFromData:(NSData *) data mutabilityOption:(NSPropertyListMutabilityOptions) opt format:(NSPropertyListFormat *) format formatOption:(enum MullePropertyListFormatOption) formatOption;

+ (id) propertyListFromData:(NSData *) data mutabilityOption:(NSPropertyListMutabilityOptions) opt format:(NSPropertyListFormat *) format errorDescription:(NSString **) errorString;

+ (id) propertyListWithData:(NSData *) data options:(NSPropertyListMutabilityOptions) opt format:(NSPropertyListFormat *) p_format error:(NSError **) p_error;
@end
```

Formats: `NSPropertyListOpenStepFormat` (1), `MullePropertyListLooseFormat` (2),
`MullePropertyListPBXFormat` (3), `MullePropertyListJSONFormat` (6),
`NSPropertyListXMLFormat_v1_0` (100), `NSPropertyListBinaryFormat_v1_0` (200).

Mutability options: `NSPropertyListImmutable`, `NSPropertyListMutableContainers`,
`NSPropertyListMutableContainersAndLeaves`.

Format options: `MullePropertyListFormatOptionDetect`, `MullePropertyListFormatOptionPrefer`,
`MullePropertyListFormatOptionForce`.

### 3.11. MulleObjCArchiverFoundation — Object Archiving

**Location**: `src/MulleObjCArchiverFoundation/`
**Key Headers**: `NSCoder.h`, `MulleObjCArchiver.h`, `MulleObjCUnarchiver.h`,
`NSArchiver.h`, `NSUnarchiver.h`, `NSKeyedArchiver.h`, `NSKeyedUnarchiver.h`,
`NSObject+NSCoder.h`

#### `NSCoder` (abstract)

Keyed archiving methods:
```objc
- (void) encodeObject:(id) obj forKey:(NSString *) key;
- (void) encodeConditionalObject:(id) obj forKey:(NSString *) key;
- (void) encodeBool:(BOOL) value forKey:(NSString *) key;
- (void) encodeInt:(int) value forKey:(NSString *) key;
- (void) encodeInt32:(int32_t) value forKey:(NSString *) key;
- (void) encodeInt64:(int64_t) value forKey:(NSString *) key;
- (void) encodeFloat:(float) value forKey:(NSString *) key;
- (void) encodeDouble:(double) value forKey:(NSString *) key;
- (void) encodeBytes:(void *) bytes length:(NSUInteger) len forKey:(NSString *) key;
- (void) encodeInteger:(NSInteger) value forKey:(NSString *) key;

- (BOOL) containsValueForKey:(NSString *) key;
- (id) decodeObjectForKey:(NSString *) key;
- (BOOL) decodeBoolForKey:(NSString *) key;
- (int) decodeIntForKey:(NSString *) key;
- (int32_t) decodeInt32ForKey:(NSString *) key;
- (int64_t) decodeInt64ForKey:(NSString *) key;
- (float) decodeFloatForKey:(NSString *) key;
- (double) decodeDoubleForKey:(NSString *) key;
- (void *) decodeBytesForKey:(NSString *) key returnedLength:(NSUInteger *) len_p;
- (NSInteger) decodeIntegerForKey:(NSString *) key;
```

Unkeyed archiving methods: `encodeValueOfObjCType:at:`, `encodeObject:`,
`encodeRootObject:`, `encodeBycopyObject:`, `encodeByrefObject:`,
`encodeConditionalObject:`, `encodeValuesOfObjCTypes:`, `encodeArrayOfObjCType:count:at:`,
`encodeBytes:length:`, `encodePropertyList:`, `decodeValueOfObjCType:at:`,
`decodeObject`, `decodeValuesOfObjCTypes:`, `decodeArrayOfObjCType:count:at:`,
`decodeBytesWithReturnedLength:`, `decodePropertyList`.

Abstract: `- (BOOL) allowsKeyedCoding`, `- (NSInteger) systemVersion`,
`- (NSInteger) versionForClassName:(NSString *) className`.

#### `MulleObjCArchiver` (binary archiver)

```objc
@interface MulleObjCArchiver : NSCoder

- (instancetype) initForWritingWithMutableData:(NSMutableData *) data;
+ (NSData *) archivedDataWithRootObject:(id) rootObject;
- (void) encodeRootObject:(id) rootObject;
- (NSString *) classNameEncodedForTrueClassName:(NSString *) trueName;
- (void) encodeClassName:(NSString *) runtime intoClassName:(NSString *) archive;
- (NSMutableData *) archiverData;
@end
```

#### `MulleObjCUnarchiver`

```objc
@interface MulleObjCUnarchiver : NSCoder

- (instancetype) initForReadingWithData:(NSData *) data;
- (BOOL) atEnd;
+ (id) unarchiveObjectWithData:(NSData *) data;
- (void) decodeClassName:(NSString *) inArchiveName asClassName:(NSString *) trueName;
- (NSString *) classNameDecodedForArchiveClassName:(NSString *) inArchiveName;
- (void) replaceObject:(id) object withObject:(id) newObject;
@end
```

`NSArchiver` and `NSUnarchiver` are concrete subclasses conforming to
`<MulleObjCUnkeyedArchiver>` / `<MulleObjCUnkeyedUnarchiver>` mixins.

`NSKeyedArchiver`/`NSKeyedUnarchiver` provide keyed archiving support.

### 3.12. MulleObjCRegexFoundation — Regular Expressions

**Location**: `src/MulleObjCRegexFoundation/`
**Key Headers**: `NSString+Regex.h`

Pattern matching is provided as an `NSString( Regex)` category, **not** as a
separate `NSRegularExpression` class:

```objc
typedef NS_ENUM( NSUInteger, MulleObjCPatternOptions)
{
   MulleObjCWildcardsShortestPath = 0x3000,
   MulleObjCWildcards             = 0x1000,
   MulleObjCSedPattern            = 0x4000,
   MulleObjCAnchoredSearch        = NSAnchoredSearch,
   MulleObjCBackwardsSearch       = NSBackwardsSearch,
};

@interface NSString( Regex)

- (NSRange) mulleRangeOfPattern:(NSString *) pattern;

- (NSRange) mulleRangeOfPattern:(NSString *) pattern
                        options:(MulleObjCPatternOptions) options;

- (NSRange) mulleRangeOfPattern:(NSString *) pattern
                        options:(MulleObjCPatternOptions) options
                          range:(NSRange) range;

- (NSString *) mulleStringByReplacingPattern:(NSString *) pattern
                                  withString:(NSString *) substitution;

- (NSString *) mulleStringByReplacingPattern:(NSString *) pattern
                                  withString:(NSString *) substitution
                                     options:(MulleObjCPatternOptions) options;

- (NSString *) mulleStringByReplacingPattern:(NSString *) pattern
                                  withString:(NSString *) substitution
                                     options:(MulleObjCPatternOptions) options
                                       range:(NSRange) range;
@end
```

Wildcard support (`*`, `?`, `[a-z]`, `[^a-z]`): `MulleObjCWildcards` extends as far
as possible; `MulleObjCWildcardsShortestPath` extends as short as possible.

## 4. Performance Characteristics

- **Linking**: O(1) single library symbol resolution (vs. 11 separate libraries).
- **Runtime**: Zero overhead from amalgamation — identical to individual libraries.
- **Containers**: `NSArray`/`NSMutableArray` use contiguous storage with doubling
  capacity. `NSDictionary`/`NSSet` use hash tables. All O(1) amortized add/get/remove.
- **Strings**: Class cluster with ASCII (7-bit), UTF-16 (15-bit), and UTF-32
  internal representations. Conversion happens lazily through `mulleFastGet*` APIs.
- **Thread safety**: None of the mutable container classes are thread-safe.
  `MulleGenerateUUIDBytes` is explicitly thread-safe.
- **NSUUID**: O(1) generation and comparison. Uses RFC 4122 version 4 (random).
- **NSTimer**: Immutable, relative-time based. No scheduling overhead from
  invalidation tracking in the timer itself.

## 5. AI Usage Recommendations & Patterns

### Best Practices

- **Use convenience constructors**: Prefer `+[NSArray array]`, `+[NSString stringWithUTF8String:]`,
  etc. over `+alloc`/`-init`/`-autorelease`.
- **Never call `-release`** except in `-dealloc` methods.
- **Use `+instance` patterns** for singleton-like objects where available.
- **`return( expr);`** — always parenthesize return expressions.
- **Use `#import <MulleFoundation/MulleFoundation.h>`** for simplicity;
  individual constituent imports also work.
- **Use `MulleUUIDBytesToUTF8String`** for C-level UUID-to-string conversion
  (avoids object allocation).
- **For KVC, prefer `takeValue:forKey:`** over `setValue:forKey:` for new code;
  the `set*` variants are in a compatibility category.

### Common Pitfalls

- **No `NSRegularExpression` class exists** — regex is done through
  `NSString(Regex)` category methods prefixed `mulle`.
- **`NSCharacterSet` and `NSCalendarDate`** are in `MulleObjCStandardFoundation`,
  not in Unicode or Time respectively.
- **`NSValue` was removed** from the amalgamation — `NSNumber` inherits from it
  but the base `NSValue` is provided by the runtime.
- **`@mixin` not `@interface`**: `MulleObjCPropertyListPrinting` and
  `MulleObjCOutputStream` use the `@mixin` keyword (MulleObjC extension).
- **`NSTimer` is immutable and relative**: There is no `-invalidate` method.
  Timer uses `mulle_relativetime_t` not `NSTimeInterval`. Must be added to a
  runloop/application after creation.
- **`NSDate` uses `dateByAddingTimeInterval:`** not `addTimeInterval:`.
- **`NSDictionary` key methods are in `SubclassesFuture`**: `-objectForKey:`,
  `-count` are not declared on the abstract `NSDictionary` interface — they
  are on concrete subclasses implementing `SubclassesFuture`.
- **Mutable containers do not deep-copy** — `-setArray:`, `-setDictionary:`, etc.
  perform shallow copies.
- **UTF8 strings from `NSString`** — returned `char *` pointers are borrowed;
  do not free them.
- **`+[NSDate date]` and `+[NSString string]` are in `Future` categories**:
  They are considered obsolete — use typed factory methods instead.

### Idiomatic Usage (project style)

```c
// 3-space indent, Allman braces, no inline init, one var per line
void   example( void)
{
   NSUUID      *uuid;
   NSArray     *array;
   char        uuid_string[ MulleUUIDStringLength];
   NSUInteger  i, n;

   uuid = [NSUUID UUID];
   array = [NSArray arrayWithObjects:@"one", @"two", @"three", nil];

   n = [array count];
   for( i = 0; i < n; i++)
   {
      // Use explicit message sends, not dot-syntax
      [[array objectAtIndex:i] description];
   }

   MulleUUIDBytesToUTF8String( [uuid bytes], uuid_string);
   // uuid_string now holds e.g. "550e8400-e29b-41d4-a716-446655440000"
}
```

## 6. Integration Examples

### Example 1: Using Multiple Constituent Libraries

```objc
#import <MulleFoundation/MulleFoundation.h>

int   main( void)
{
   NSMutableArray    *tasks;
   NSString          *name;
   NSDate            *created;
   NSUUID            *projectId;
   NSCalendarDate    *today;
   NSUInteger        i, n;

   tasks      = [NSMutableArray arrayWithCapacity:10];
   name       = @"Project";
   created    = [NSDate dateWithTimeIntervalSince1970:1690000000.0];
   projectId  = [NSUUID UUID];
   today      = [NSCalendarDate calendarDate];

   [tasks addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        name,                       @"name",
                        created,                    @"created",
                        [projectId UUIDString],     @"id",
                        nil]];

   n = [tasks count];
   for( i = 0; i < n; i++)
   {
      NSLog( @"%@", [[tasks objectAtIndex:i] objectForKey:@"name"]);
   }
   return( 0);
}
```

### Example 2: KVC and Container Operations

```objc
#import <MulleFoundation/MulleFoundation.h>

int   main( void)
{
   NSMutableArray    *records;
   NSArray           *names;
   NSNumber          *avgValue;
   NSUInteger        i;

   records = [NSMutableArray arrayWithCapacity:4];
   for( i = 0; i < 3; i++)
   {
      NSMutableDictionary   *record;

      record = [NSMutableDictionary dictionaryWithCapacity:3];
      [record setObject:[NSString stringWithFormat:@"Record%lu", (unsigned long) i]
                 forKey:@"name"];
      [record setObject:[NSNumber numberWithInt:(int) i * 10]
                 forKey:@"value"];
      [records addObject:record];
   }

   names    = [records valueForKey:@"name"];
   avgValue = [records valueForKey:@"@avg.value"];

   NSLog( @"Names: %@", names);
   NSLog( @"Avg value: %@", avgValue);
   return( 0);
}
```

### Example 3: String Pattern Matching

```objc
#import <MulleFoundation/MulleFoundation.h>

int   main( void)
{
   NSString    *text;
   NSRange     range;

   text = @"The quick brown fox jumps over the lazy dog";

   range = [text mulleRangeOfPattern:@"brown" options:0 range:NSMakeRange( 0, [text length])];
   if( range.location != NSNotFound)
   {
      NSLog( @"Found 'brown' at location %lu", (unsigned long) range.location);
   }

   range = [text mulleRangeOfPattern:@"b*wn"
                             options:MulleObjCWildcards
                               range:NSMakeRange( 0, [text length])];
   if( range.location != NSNotFound)
   {
      NSLog( @"Wildcard match at location %lu", (unsigned long) range.location);
   }
   return( 0);
}
```

### Example 4: Property List Serialization

```objc
#import <MulleFoundation/MulleFoundation.h>

int   main( void)
{
   NSDictionary   *config;
   NSData         *plistData;
   NSError        *error;
   id             restored;

   error  = nil;
   config = @{
      @"name"  : @"MyApp",
      @"value" : @"1.0",
   };

   plistData = [NSPropertyListSerialization dataWithPropertyList:config
                                                          format:NSPropertyListXMLFormat_v1_0
                                                         options:0
                                                           error:&error];
   if( error)
   {
      NSLog( @"Error: %@", error);
      return( 1);
   }

   restored = [NSPropertyListSerialization propertyListWithData:plistData
                                                        options:0
                                                         format:NULL
                                                          error:&error];
   NSLog( @"Restored: %@", restored);
   return( 0);
}
```

### Example 5: Object Archiving

```objc
#import <MulleFoundation/MulleFoundation.h>

int   main( void)
{
   NSData                *data;
   NSMutableDictionary   *dict;
   NSDictionary          *restored;

   dict = [NSMutableDictionary dictionaryWithCapacity:3];
   [dict setObject:[NSUUID UUID] forKey:@"id"];
   [dict setObject:[NSDate dateWithTimeIntervalSince1970:1690000000.0] forKey:@"created"];
   [dict setObject:@"Hello World" forKey:@"message"];

   data    = [NSArchiver archivedDataWithRootObject:dict];
   NSLog( @"Archived to %lu bytes", (unsigned long) [data length]);

   restored = [NSUnarchiver unarchiveObjectWithData:data];
   NSLog( @"Restored message: %@", [restored objectForKey:@"message"]);
   return( 0);
}
```

## 7. Dependencies

Direct dependencies (from `.mulle/etc/sourcetree/config`):

| Dependency | Description |
|---|---|
| `MulleObjC` | Objective-C runtime and root classes |
| `mulle-objc-list` | Build-time tool for listing runtime info (no-link, no-header) |
| `math` (libm) | System math library (no-build, platform-linux alias `m`) |

Internal constituent dependencies (copy-mode, no individual build):

| Constituent | Source directory |
|---|---|
| `MulleObjCValueFoundation` | `src/MulleObjCValueFoundation/` |
| `MulleObjCStandardFoundation` | `src/MulleObjCStandardFoundation/` |
| `MulleObjCContainerFoundation` | `src/MulleObjCContainerFoundation/` |
| `MulleObjCTimeFoundation` | `src/MulleObjCTimeFoundation/` |
| `MulleObjCUnicodeFoundation` | `src/MulleObjCUnicodeFoundation/` |
| `MulleObjCUUIDFoundation` | `src/MulleObjCUUIDFoundation/` |
| `MulleObjCKVCFoundation` | `src/MulleObjCKVCFoundation/` |
| `MulleObjCMathFoundation` | `src/MulleObjCMathFoundation/` |
| `MulleObjCPlistFoundation` | `src/MulleObjCPlistFoundation/` |
| `MulleObjCArchiverFoundation` | `src/MulleObjCArchiverFoundation/` |
| `MulleObjCRegexFoundation` | `src/MulleObjCRegexFoundation/` |

## 8. Linking

```
-lMulleFoundationBase
```

A single library provides all 11 constituent APIs. No need to link constituent
libraries individually.
