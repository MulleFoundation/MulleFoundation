# MulleFoundation Library Documentation for AI
<!-- Keywords: ObjectiveC, amalgamation, archiver, calendar, filesystem, subprocess, runloop -->

## 1. Introduction & Purpose

- **MulleFoundation** is an *amalgamation* library: the sources of ten
  MulleFoundation projects are copied (clibmode=copy) into `src/` and built as a
  single linkable library. It aggregates:
  - `MulleObjCArchiverFoundation` — `NSCoder` / `NSArchiver` / `NSUnarchiver` /
    `NSKeyedArchiver` / `NSKeyedUnarchiver`.
  - `MulleObjCCalendarFoundation` — `NSCalendar` (Gregorian + Julian) and
    `NSDateComponents`.
  - `MulleObjCOSBaseFoundation` — platform-neutral OS classes (filesystem,
    bundles, tasks, pipes, run loop, user defaults, path utilities).
  - `MulleObjCOSFoundation` — the umbrella/facade that re-exports OSBase plus a
    platform backend.
  - Platform backends: `MulleObjCPosixFoundation`, `MulleObjCBSDFoundation`,
    `MulleObjCDarwinFoundation`, `MulleObjCFreeBSDFoundation`,
    `MulleObjCLinuxFoundation`, `MulleObjCWindowsFoundation`.
- It solves two problems: (1) linking a dozen small libraries individually, and
  (2) portability — one public Objective-C API with per-platform implementations.
- **Advantages:** one library to link; faster builds than ten separate projects;
  existing `#import <MulleObjCWhatever/Whatever.h>` statements keep working; a
  single unified import `#import <MulleFoundation/MulleFoundation.h>`.
- **Relationship to MulleFoundationBase.** The umbrella header also imports
  `MulleFoundationBase`, a *dependency* (not part of this project) that supplies
  the value/container/standard/time/unicode/uuid/kvc/math/plist/regex classes
  (`NSString`, `NSArray`, `NSDictionary`, `NSDate`, `NSError`, …). This document
  documents only the classes physically bundled in this project.

## 2. Key Concepts & Design Philosophy

- **Amalgamation, not composition.** Each constituent still lives in its own
  `src/<Name>/` directory with its own umbrella header and generated
  `_<Name>-export.h`. There is one build target, not sub-targets. The public
  umbrella `src/MulleFoundation/MulleFoundation.h` imports
  `MulleFoundationBase`, `MulleObjCArchiverFoundation`,
  `MulleObjCCalendarFoundation`, and `MulleObjCOSFoundation`.
- **Layering.** Lower layers are built first; concrete layers override by
  defining Objective-C categories with the same selectors:

  ```text
  MulleFoundationBase (dependency: NSString, NSArray, NSDate, NSError, ...)
        |
  OSBase (abstract API + generic implementation)
        |
  Posix -------------------- Windows
        |
  BSD  --- Linux
        |
  Darwin, FreeBSD
  ```

  `MulleObjCOSFoundation`/OSBase provide the *API*; the linked platform library
  provides the *behavior* via categories such as `NSFileManager( Posix)`.
- **`( Future)` categories and `<MulleObjCFuture>`.** Many methods are declared
  in categories named `( Future)`, `( SubclassesFuture)`, `( OSSpecificFuture)`,
  `( SubclassFuture)`, or `( Persistent)` conforming to `MulleObjCFuture`. This
  marks API that is implemented by a subclass or platform layer and may not be
  linked by a bare, platform-less build. Treat these methods as public API.
- **Singletons with locking.** `NSFileManager`, `NSProcessInfo`, and
  `NSUserDefaults` conform to `MulleObjCSingleton` and `MulleObjCThreadSafe`;
  access via `+defaultManager`, `+processInfo`, `+standardUserDefaults`.
- **`NSRunLoop` is per-thread**; it is a `select(2)` wrapper and must never be
  shared across threads.
- **mulle-objc coding conventions** (apply to all code written against this
  library): 3-space indent, Allman braces, aligned declarations, C89 variable
  rules, one variable per line, `return( expr);`, **no dot-syntax** (use
  `[obj method]` / `[obj setMethod:value]`), **no blocks** (`^`), no
  `+alloc`/`-init`/`-autorelease` in application code (use factory methods), and
  never call `-release` outside `-dealloc`.
- **Per-constituent deep dives** live next to the sources and contain the full
  symbol-by-symbol reference:
  `src/MulleObjCArchiverFoundation/index.md`, `src/MulleObjCCalendarFoundation/index.md`,
  `src/MulleObjCOSBaseFoundation/index.md`, `src/MulleObjCOSFoundation/index.md`,
  `src/MulleObjCPosixFoundation/index.md`, `src/MulleObjCBSDFoundation/index.md`,
  `src/MulleObjCDarwinFoundation/index.md`, `src/MulleObjCFreeBSDFoundation/index.md`,
  `src/MulleObjCLinuxFoundation/index.md`, `src/MulleObjCWindowsFoundation/index.md`.

## 3. Core API & Data Structures

All signatures below are copied verbatim from the public headers. The member
functions of the ten constituents are reachable from the umbrella header.

### 3.1. Umbrella headers and version

```objc
#import <MulleFoundation/MulleFoundation.h>
```

```c
#define MULLE_FOUNDATION_VERSION  ((0UL << 20) | (31 << 8) | 0)

static inline unsigned int   MulleFoundation_get_version_major( void);
static inline unsigned int   MulleFoundation_get_version_minor( void);
static inline unsigned int   MulleFoundation_get_version_patch( void);
```

Per-constituent version macros (all static inline getters `_get_version_major`,
`_get_version_minor`, `_get_version_patch`):

- `MULLE_OBJC_ARCHIVER_FOUNDATION_VERSION` (`(0UL << 20) | (23 << 8) | 0`)
- `MULLE_OBJC_CALENDAR_FOUNDATION_VERSION` (`(0UL << 20) | (21 << 8) | 6`), plus
  exported `uint32_t MulleObjCCalendarFoundation_get_version( void);`
- `MULLE_OBJC_OS_BASE_FOUNDATION_VERSION` (= `MULLE_OBJC_FOUNDATION_VERSION`)
- `MULLE_OBJC_OS_FOUNDATION_VERSION` (`(0UL << 20) | (27 << 8) | 0`)

The window/posix/bsd/darwin/freebsd/linux umbrellas (e.g.
`MulleObjCPosixFoundation.h`) mainly import their generated `-export.h`
and version checks.

### 3.2. `MulleObjCArchiverFoundation` — object archiving

Umbrella: `#import <MulleObjCArchiverFoundation/MulleObjCArchiverFoundation.h>`
(which imports `_MulleObjCArchiverFoundation-export.h` → all headers below).

#### `NSCoder.h`

```objc
@interface NSCoder : NSObject
- (BOOL) allowsKeyedCoding;
- (NSInteger) systemVersion;
@end

@interface NSCoder ( Common)
- (NSInteger) versionForClassName:(NSString *) className;
@end
```

Keyed archiving (categories `NSCoder( KeyedArchiving)` / `NSCoder( KeyedUnarchiving)`):

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

Unkeyed archiving (`NSCoder( UnkeyedArchiving)`), unkeyed unarchiving
(`NSCoder( UnkeyedUnarchiving)`): `encodeValueOfObjCType:at:`, `encodeObject:`,
`encodeRootObject:`, `encodeBycopyObject:`, `encodeByrefObject:`,
`encodeConditionalObject:`, `encodeValuesOfObjCTypes:`,
`encodeArrayOfObjCType:count:at:`, `encodeBytes:length:`, `encodePropertyList:`,
`decodeValueOfObjCType:at:`, `decodeObject`, `decodeValuesOfObjCTypes:`,
`decodeArrayOfObjCType:count:at:`, `decodeBytesWithReturnedLength:`,
`decodePropertyList`.

Mixins implemented by concrete coders:

```objc
@mixin MulleObjCUnkeyedArchiver < NSObject>
@required
- (void) encodeValueOfObjCType:(char *) type at:(void *) data;
@end

@mixin MulleObjCUnkeyedUnarchiver < NSObject>
@required
- (void) decodeValueOfObjCType:(char *) type at:(void *) data;
@end
```

#### `MulleObjCArchiver` / `MulleObjCUnarchiver` (concrete bases)

```objc
MULLE_OBJC_ARCHIVER_FOUNDATION_GLOBAL NSString *NSInconsistentArchiveException;
MULLE_OBJC_ARCHIVER_FOUNDATION_GLOBAL NSString *NSInvalidArchiveOperationException;

@interface MulleObjCArchiver : NSCoder
- (instancetype) initForWritingWithMutableData:(NSMutableData *) data;
+ (NSData *) archivedDataWithRootObject:(id) rootObject;
- (void) encodeRootObject:(id) rootObject;
- (NSString *) classNameEncodedForTrueClassName:(NSString *) trueName;
- (void) encodeClassName:(NSString *) runtime intoClassName:(NSString *) archive;
- (NSMutableData *) archiverData;
@end

@interface MulleObjCUnarchiver : NSCoder
- (instancetype) initForReadingWithData:(NSData *) data;
- (BOOL) atEnd;
+ (id) unarchiveObjectWithData:(NSData *) data;
- (void) decodeClassName:(NSString *) inArchiveName asClassName:(NSString *) trueName;
- (NSString *) classNameDecodedForArchiveClassName:(NSString *) inArchiveName;
- (void) replaceObject:(id) object withObject:(id) newObject;
- (void *) _decodeBytesWithReturnedLength:(NSUInteger *) len_p;
@end
```

#### Concrete subclasses

```objc
@interface NSArchiver : MulleObjCArchiver < MulleObjCUnkeyedArchiver>
@end

@interface NSUnarchiver : MulleObjCUnarchiver < MulleObjCUnkeyedUnarchiver>
- (void) decodeValueOfObjCType:(char *) type at:(void *) p;
- (void *) decodeBytesWithReturnedLength:(NSUInteger *) len_p;
@end

@interface NSKeyedArchiver : MulleObjCArchiver
@end

@interface NSKeyedUnarchiver : MulleObjCUnarchiver
{
   NSMapTable   *_scope;
}
@end
```

`NSArchiver+OSBase.h` adds file convenience:

```objc
@interface NSArchiver (OSBase)
+ (BOOL) archiveRootObject:(NSObject *) rootObject toFile:(NSString *) path;
@end
```

`NSObject+NSCoder.h`: `@interface NSObject( NSCoder)` declares
`- (Class) classForCoder;` (not implemented here — subclasses override).

`mulle-buffer-archiver.h` provides inline variable-length integer / float /
double coding helpers on `struct mulle_buffer` (`mulle_buffer_next_integer`,
`mulle_buffer_next_long_long`, `mulle_buffer_next_float`,
`mulle_buffer_next_double`, `mulle_buffer_add_integer`,
`mulle_buffer_add_long_long`, `mulle_buffer_add_float`,
`mulle_buffer_add_double`, and the fixed-width `_add_integer_7/14/21/…/64`).

### 3.3. `MulleObjCCalendarFoundation` — calendars and date components

Umbrella: `#import <MulleObjCCalendarFoundation/MulleObjCCalendarFoundation.h>`.

#### `NSCalendar.h`

```c
enum
{
    NSCalendarUnitEra            = 0x0001,
    NSCalendarUnitYear           = 0x0002,
    NSCalendarUnitQuarter        = 0x0004,
    NSCalendarUnitMonth          = 0x0008,
    NSCalendarUnitWeekOfYear     = 0x0010,
    NSCalendarUnitWeekOfMonth    = 0x0020,
    NSCalendarUnitDay            = 0x0040,
    NSCalendarUnitWeekday        = 0x0080,
    NSCalendarUnitWeekdayOrdinal = 0x0100,
    NSCalendarUnitHour           = 0x0200,
    NSCalendarUnitMinute         = 0x0400,
    NSCalendarUnitSecond         = 0x0800,
    NSCalendarUnitNanosecond     = 0x1000
};
typedef NSUInteger NSCalendarUnit;
```

Legacy aliases `NSEraCalendarUnit`, `NSYearCalendarUnit`, `NSMonthCalendarUnit`,
`NSWeekCalendarUnit`, `NSDayCalendarUnit`, `NSWeekdayCalendarUnit`,
`NSWeekdayOrdinalCalendarUnit`, `NSHourCalendarUnit`, `NSMinuteCalendarUnit`,
`NSSecondCalendarUnit`. Identifier globals:

```c
MULLE_OBJC_CALENDAR_FOUNDATION_GLOBAL NSString *NSGregorianCalendar; // @"gregorian"
MULLE_OBJC_CALENDAR_FOUNDATION_GLOBAL NSString *NSJulianCalendar;    // @"julian"
```

```objc
@interface NSCalendar : NSObject
{
   NSUInteger   _daysOfCommonEraOfReferenceDate;
}
@property( copy) NSLocale     *locale;
@property( copy) NSTimeZone   *timeZone;
@property( assign) NSInteger  firstWeekday;              // Sunday: 0, Monday: 1
@property( assign) NSInteger  minimumDaysInFirstWeek;

+ (void) mulleRegisterClass:(Class) cls forIdentifier:(NSString *) identifier;
+ (instancetype) calendarWithIdentifier:(NSString *) identifier;
- (instancetype) initWithCalendarIdentifier:(NSString *) identifier;

- (NSDateComponents *) components:(NSUInteger) flags fromDate:(NSDate *) date;
- (NSDate *) dateByAddingComponents:(NSDateComponents *) components
                             toDate:(NSDate *) date
                            options:(NSUInteger) options;
- (NSDate *) dateFromComponents:(NSDateComponents *) components;
@end
```

`NSCalendar( SubclassesFuture) <MulleObjCFuture>` supplies
`+currentCalendar`, `-calendarIdentifier`, `-mulleFirstWeekdayOfCommonEra`,
`-minimumRangeOfUnit:`, `-maximumRangeOfUnit:`,
`-rangeOfUnit:inUnit:forDate:`, `-rangeOfUnit:startDate:interval:forDate:`,
`-ordinalityOfUnit:inUnit:forDate:`, `-mulleIsLeapYear:`,
`-mulleNumberOfDaysInYear:`, `-mulleNumberOfWeeksInYear:`,
`-mulleNumberOfDaysInMonth:ofYear:`, `-mulleNumberOfDaysInCommonEraOfDay:month:year:`,
`-mulleTimeIntervalWithYear:month:day:hour:minute:second:nanosecond:`.

#### `NSDateComponents.h`

```c
#define NSDateComponentUndefined    NSIntegerMax
```

```objc
@interface NSDateComponents : NSObject < MulleObjCThreadUnsafe>
@public
    NSInteger   _era, _year, _quarter, _month, _weekOfYear, _weekOfMonth,
                _day, _weekday, _weekdayOrdinal, _hour, _minute, _second,
                _nanosecond;   // (declared one per line in the header)
@property( assign) NSInteger   era, year, quarter, month, weekOfYear,
                               weekOfMonth, day, weekday, weekdayOrdinal,
                               hour, minute, second, nanosecond;
- (void) setWeek:(NSInteger) week;
- (NSInteger) week;
- (NSInteger) valueForComponent:(NSCalendarUnit) unit;
- (void) setValue:(NSInteger) value forComponent:(NSCalendarUnit) unit;
- (NSString *) description;
- (NSString *) mulleDebugContentsDescription;
@end
```

#### `NSCalendar+NSDate.h`

```c
enum MulleCalendarWeekday
{
   MulleCalendarSunday    = 1, MulleCalendarMonday    = 2,
   MulleCalendarTuesday   = 3, MulleCalendarWednesday = 4,
   MulleCalendarThursday  = 5, MulleCalendarFriday    = 6,
   MulleCalendarSaturday  = 7
};

struct MulleExtendedTimeInterval
{
   NSTimeInterval    interval;
   NSInteger         year, month, weekday,
                     dayOfCommonEra, dayOfMonth, hour;
};
```

`NSCalendar( NSDate)` exposes `-mulleIsLeapYearFromExtendedTimeInterval:`,
`-mulle12HourFromExtendedTimeInterval:`, `-mulle24HourFromExtendedTimeInterval:`,
`-mulleAMPMFromExtendedTimeInterval:`, `-mulleDayOfCommonEraFromExtendedTimeInterval:`,
`-mulleDayOfMonthFromExtendedTimeInterval:`, `-mulleDayOfWeekFromExtendedTimeInterval:`,
`-mulleDayOfYearFromExtendedTimeInterval:`, `-mulleISOWeekOfYearFromExtendedTimeInterval:`,
`-mulleMonthFromExtendedTimeInterval:`, `-mulleQuarterFromExtendedTimeInterval:`,
`-mulleWeekOfYearFromExtendedTimeInterval:`, `-mulleYearFromExtendedTimeInterval:`
(and further ISO/week/quarter variants). Inline helpers `MulleSecondFromTimeInterval`
and `MulleNanosecondFromTimeInterval` are also declared here.

Concrete calendar classes `_MulleGregorianCalendar` and `_MulleJulianCalendar`
are registered for the `NSGregorianCalendar` / `NSJulianCalendar` identifiers.

### 3.4. `MulleObjCOSBaseFoundation` — platform-neutral OS classes

Umbrella: `#import <MulleObjCOSBaseFoundation/MulleObjCOSBaseFoundation.h>`.
This is the abstract API layer. Its methods are implemented by the platform
backend that is linked (Unix/POSIX, BSD, Darwin, FreeBSD, Linux, Windows).

Key classes and their core methods:

- **`NSBundle : NSObject <MulleObjCThreadSafe>`** — executable/resource bundles.
  `+mainBundle`, `+allFrameworks`, `+allBundles`, `+bundleWithPath:`,
  `+bundleWithIdentifier:`, `-initWithPath:`, `-bundleIdentifier`,
  `-principalClass`, `-resourcePath`, `-executablePath`, `-bundlePath`,
  `-isLoaded`, `-pathForResource:ofType:`, `-pathForResource:ofType:inDirectory:`,
  `-pathsForResourcesOfType:inDirectory:`, `-classNamed:`,
  `-localizedStringForKey:value:table:`, `-objectForInfoDictionaryKey:`,
  `-infoDictionary`, `-developmentLocalization`. Its `( Future)` category adds
  `+isBundleFilesystemExtension:`, `+pathForResource:ofType:inDirectory:`,
  `+pathsForResourcesOfType:inDirectory:`, `-pathForAuxiliaryExecutable:`,
  `-privateFrameworksPath`, `-sharedFrameworksPath`, `-sharedSupportPath`,
  `-builtInPlugInsPath`; `( OSSpecificFuture)` adds `-loadBundle`,
  `-unloadBundle`, `+bundleForClass:`; `( MulleSymbolLookup)` adds
  `-mulleLookupSymbolUTF8String:`, `-mulleLookupSymbol:`. Globals
  `NSLoadedClasses`, `NSBundleDidLoadNotification`,
  `NSBundleGetOrRegisterBundleWithPath`, `NSBundleDeregisterBundleWithPath`,
  `MulleObjCBundleLocalizedStringFromTable` and the `NSLocalizedString*` macros.

- **`NSDirectoryEnumerator : NSEnumerator <NSEnumerator, NSFastEnumeration>`** —
  recursive enumerator from `-[NSFileManager enumeratorAtPath:]`.
  `-directoryAttributes`, `-fileAttributes`, `-count`, `-level`,
  `-skipDescendants`, `-skipDescendents`.

- **`NSFileHandle : NSObject <MulleObjCInputStream, MulleObjCOutputStream, MulleObjCThreadSafe>`**
  — `+fileHandleForReadingAtPath:`, `+fileHandleForWritingAtPath:`,
  `+fileHandleForUpdatingAtPath:`, `+fileHandleWithNullDevice`,
  `-initWithFileDescriptor:`, `-availableData`, `-readDataToEndOfFile`,
  `-readDataOfLength:`, `-offsetInFile`, `-seekToEndOfFile`,
  `-seekToFileOffset:`, `-truncateFileAtOffset:`, `-writeData:`,
  `-fileDescriptor`, `-closeFile`, `-mulleWriteBytes:length:`,
  `-mulleAddToStateBits:`, `-mulleGetStateBits`. Global
  `NSFileHandleOperationException`; enum `NSFileHandleStateBit`.
  Subclass `NSNullDeviceFileHandle`.

- **`NSFileManager : NSObject <MulleObjCSingleton, MulleObjCThreadSafe>`** —
  `@property( assign) id delegate;`, `+defaultManager`,
  `-enumeratorAtPath:`, `-createFileAtPath:contents:attributes:`,
  `-contentsAtPath:`, `-contentsEqualAtPath:andPath:`,
  `-removeFileAtPath:handler:`, `-createDirectoryAtPath:attributes:`,
  `-createSymbolicLinkAtPath:pathContent:`. The `( Future)` category adds
  `-fileSystemRepresentationWithPath:`, `-stringWithFileSystemRepresentation:length:`,
  `-currentDirectoryPath`, `-changeCurrentDirectoryPath:`, `-fileExistsAtPath:`,
  `-fileExistsAtPath:isDirectory:`, `-is{Deletable,Executable,Readable,Writable}FileAtPath:`,
  `-createDirectoryAtPath:withIntermediateDirectories:attributes:error:`,
  `-removeItemAtPath:error:`, `-moveItemAtPath:toPath:error:`,
  `-copyItemAtPath:toPath:error:`, attribute queries
  (`-attributesOfItemAtPath:error:`, `-attributesOfFileSystemForPath:error:`,
  `-setAttributes:ofItemAtPath:error:`) and more. Protocols
  `NSFileManagerHandler` and `NSFileManagerDelegate`. Global attribute keys
  `NSFileType`, `NSFileSize`, `NSFileModificationDate`, `NSFilePosixPermissions`,
  … and values `NSFileTypeDirectory/Regular/SymbolicLink/Socket/Pipe/…`.
  Macros `NSFilePathComponentSeparator` (`@"/"`) and
  `NSFilePathExtensionSeparator` (`@"."`).

- **`NSPipe : NSObject <MulleObjCImmutableProtocols>`** — `+pipe`,
  `-fileHandleForReading`, `-fileHandleForWriting`,
  `-_fileDescriptorForReading`, `-_fileDescriptorForWriting`.

- **`NSProcessInfo : NSObject <MulleObjCSingleton, MulleObjCThreadSafe>`** —
  `+processInfo`; `( Future)` adds `-hostName`,
  `-operatingSystem`, `-operatingSystemName`, `-operatingSystemVersionString`,
  `-arguments`, `-environment`, `-_executablePath`, `-processName`,
  `-setProcessName:`, `-globallyUniqueString`, `-processIdentifier`,
  `-mulleSetEnvironmentValue:forKey:`. OS constants
  `NSWindowsNTOperatingSystem`, `NSWindows95OperatingSystem`,
  `NSSolarisOperatingSystem`, `NSHPUXOperatingSystem`, `NSDarwinOperatingSystem`,
  `NSSunOSOperatingSystem`, `NSOSF1OperatingSystem`, `NSLinuxOperatingSystem`,
  `NSBSDOperatingSystem`.

- **`NSRunLoop : NSObject`** — per-thread `select(2)` wrapper.
  `+currentRunLoop`, `+mainRunLoop`, `+mulleCurrentRunLoop` (returns `nil` during
  thread teardown), `-currentMode`, `-acceptInputForMode:beforeDate:`, `-run`,
  `-runUntilDate:`, `-runMode:beforeDate:`, `-limitDateForMode:`,
  `-performSelector:target:argument:order:modes:`,
  `-cancelPerformSelector:target:argument:`, `-cancelPerformSelectorsWithTarget:`,
  `-addTimer:forMode:`. `typedef NSString *NSRunLoopMode;` global
  `NSDefaultRunLoopMode`; enum `MulleRunLoopInputState`.

- **`NSTask : NSObject`** — child process. `+launchedTaskWithLaunchPath:arguments:`,
  `-setArguments:`, `-setCurrentDirectoryPath:`, `-setEnvironment:`,
  `-setLaunchPath:`, `-setStandardError:`, `-setStandardInput:`,
  `-setStandardOutput:`, `-processIdentifier`, `-terminationStatus`,
  `-standardError`, `-standardInput`, `-standardOutput`, `-arguments`,
  `-launchPath`, `-currentDirectoryPath`, `-environment`. `( Future)` adds
  `-isRunning`, `-interrupt`, `-launch`, `-resume`, `-suspend`, `-terminate`,
  `-waitUntilExit`, `-terminationReason`.
  `NSTask+System.h` adds the convenience `mulleDataSystemCallWithArguments:…`,
  `mulleStringSystemCallWithArguments:…`, and
  `mulleStringSystemCallWithCommandString:…` families, returning an
  `NSDictionary` with keys `NSTaskExceptionKey`, `NSTaskTerminationStatusKey`,
  `NSTaskStandardOutputDataKey`, `NSTaskStandardOutputStringKey`,
  `NSTaskStandardErrorDataKey`, `NSTaskStandardErrorStringKey`;
  `typedef NS_ENUM(int, NSTaskSystemOptions)`.

- **`NSUserDefaults : NSObject <MulleObjCSingleton, MulleObjCThreadSafe>`** —
  `+standardUserDefaults`, `-init`, `-objectForKey:`, `-setObject:forKey:`,
  `-removeObjectForKey:`, `-registerDefaults:`, `-dictionaryRepresentation`,
  `-synchronize`. `( Conveniences)` adds typed getters/setters
  (`-boolForKey:`, `-integerForKey:`, `-stringForKey:`, `-setInteger:forKey:`, …).
  `( Persistent)` defines the platform storage hook
  (`-_defaultsIdentifier`, `-_loadPersistentDomain:`, `-_savePersistentDomain:`).
  Globals `NSGlobalDomain`, `NSArgumentDomain`, `NSRegistrationDomain`.

- **C functions:** page allocation `NSAllocateMemoryPages`,
  `NSDeallocateMemoryPages`, `NSPageSize`, `NSLogPageSize`,
  `NSRoundDownToMultipleOfPageSize`, `NSRoundUpToMultipleOfPageSize`
  (`NSPageAllocation.h`); path utilities `NSFullUserName`, `NSHomeDirectory`,
  `NSHomeDirectoryForUser`, `NSOpenStepRootDirectory`,
  `NSSearchPathForDirectoriesInDomains`, `NSTemporaryDirectory`, `NSUserName`
  (`NSPathUtilities.h`); `NSLog`, `NSLogv`, `NSLogArguments` (platform `NSLog.h`).

- **Categories:** `NSArray( OSBase)`, `NSDictionary( OSBase)`,
  `NSData( OSBase)`, `NSData( OSBaseFuture)`, `NSData( MulleMemoryMapping)`,
  `NSMutableData( MulleMemoryMapping)`, `NSString( CString)`,
  `NSString( CStringFuture)`, `NSString( OSBase)`, `NSString( OSBaseFuture)`,
  `NSString( FileSystemString)`, `NSCalendarDate( NSUserDefaults)`,
  `NSDate( NSUserDefaults)`, `NSFileHandle( NSRunLoop)`,
  `NSObject( NSRunLoop)`, `NSTimer( NSRunLoop)`.

  Highlights:
  ```objc
  // NSArray( OSBase) / NSDictionary( OSBase)
  + (instancetype) arrayWithContentsOfFile:(NSString *) path;
  - (BOOL) writeToFile:(NSString *) path atomically:(BOOL) flag;
  + (instancetype) dictionaryWithContentsOfFile:(NSString *) path;

  // NSData( OSBase)
  + (instancetype) dataWithContentsOfFile:(NSString *) path
                                  options:(NSDataReadingOptions) options
                                    error:(NSError **) error;
  // NSData( MulleMemoryMapping)
  + (instancetype) dataWithContentsOfMappedFile:(NSString *) path;

  // NSString( CString)
  + (instancetype) stringWithCString:(char *) s;
  - (void) getCString:(char *) bytes maxLength:(NSUInteger) maxLength;
  NSStringEncoding mulle_cstring_encoding_for_codeset( char *codeset);

  // NSString( OSBase)
  - (NSString *) stringByAppendingPathComponent:(NSString *) component;
  - (NSString *) lastPathComponent;
  - (char *) fileSystemRepresentation;
  - (BOOL) writeToFile:(NSString *) path atomically:(BOOL) flag;

  // NSObject( NSRunLoop)
  - (void) performSelector:(SEL) aSelector withObject:(id) anArgument
                afterDelay:(NSTimeInterval) delay;
  // NSTimer( NSRunLoop)
  - (void) invalidate;
  ```

### 3.5. `MulleObjCOSFoundation` — OS umbrella

Umbrella: `#import <MulleObjCOSFoundation/MulleObjCOSFoundation.h>`. This is a
facade: it declares `MULLE_OBJC_OS_FOUNDATION_VERSION` and imports
`MulleObjCOSBaseFoundation` plus the platform library selected for the target
(POSIX on non-Windows, Windows on `_WIN32`). Importing this one header gives the
full OS API. It has no classes of its own.

### 3.6. Platform backends

Platform libraries define categories on the OSBase classes; they add little
public surface of their own.

- **`MulleObjCPosixFoundation`** — POSIX (`select`, `fork`, native C strings,
  `tzfile`). Public extras: `NSError+Posix.h`
  (`NSString *NSPOSIXErrorDomain;`, `void MulleObjCSetPosixErrorDomain( void);`),
  `NSLocale+Posix.h` (`+systemLocalePath`, `-_localeInfoForKey:`),
  `NSLog.h` (`NSLog`, `NSLogv`, `NSLogArguments`), `mulle-posix-tm.h`
  (`mulle_posix_tm_from_string_with_format`, `mulle_posix_tm_invalidate`,
  `mulle_posix_tm_is_invalid`, `mulle_posix_tm_augment`,
  `mulle_posix_tm_get_mini_tm`, `mulle_posix_tm_init_with_mini_tm`,
  `mulle_posix_tm_init_with_time`, `mulle_posix_tm_get_time`,
  `mulle_posix_tm_init_with_interval1970`).
- **`MulleObjCBSDFoundation`** — BSD additions. Public header `mulle-bsd-tm.h`
  (`mulle_bsd_tm_invalidate`, `mulle_bsd_tm_is_invalid`, `mulle_bsd_tm_augment`,
  `mulle_bsd_tm_from_string_with_format`, `mulle_bsd_tm_init_with_interval1970`,
  and inline `mulle_bsd_tm_get_mini_tm` / `mulle_bsd_tm_init_with_mini_tm` /
  `mulle_bsd_tm_init_with_time` / `mulle_bsd_tm_get_time`).
- **`MulleObjCDarwinFoundation`**, **`MulleObjCFreeBSDFoundation`**,
  **`MulleObjCLinuxFoundation`** — category-only platform layers (bundle,
  file manager, path utilities, process info, string, task, date formatter,
  time zone, locale). No project-specific public headers; they are exposed
  through the OSBase API.
- **`MulleObjCWindowsFoundation`** — public extras: `NSErrorWindows.h`
  (`NSString *NSWindowsErrorDomain;`, `void MulleObjCSetWindowsErrorDomain( void);`),
  `NSLog.h`, `mulle-windows-tm.h` (`mulle_windows_tm_invalidate`,
  `mulle_windows_tm_is_invalid`, `mulle_windows_tm_get_mini_tm`,
  `mulle_windows_tm_init_with_mini_tm`, `mulle_windows_tm_init_with_time`,
  `mulle_windows_tm_get_time`, `mulle_windows_tm_init_with_interval1970`),
  `NSFileManager+Windows.h`
  (`-fileSystemRepresentationUTF16WithPath:`,
  `-stringWithFileSystemRepresentationUTF16:length:`), and an empty
  `NSTask( Windows)` category.

### 3.7. Generated / generic headers

Every constituent ships generated `import.h`, `include.h`, `_<Name>-import.h`,
`_<Name>-include.h`, `_<Name>-export.h`, `_<Name>-provide.h`, `_<Name>-versioncheck.h`.
`_<Name>-export.h` imports all public class headers of that constituent;
`_<Name>-import.h` imports cross-constituent dependencies. These are regenerated
by `mulle-sde reflect` — do not edit them.

## 4. Performance Characteristics

- **Amalgamation**: zero runtime overhead versus the individual libraries; only
  link time and build parallelism change (one library, one symbol resolution).
- **`NSArchiver` / `MulleObjCArchiver`**: encodes into an in-memory
  `mulle_buffer`; O(1) per scalar, O(size) for byte blobs. Object graphs use
  pointer-handle maps (`mulle_map` + `mulle_pointerarray`) for identity, so
  repeated references are encoded once. `NSUnarchiver` rehydrates with hash
  lookups.
- **`NSCalendar`**: `components:fromDate:` and `dateFromComponents:` are O(1)
  arithmetic over the loaded calendar tables; range/ordinality queries are O(1)
  to O(1) per unit. `_MulleGregorianCalendar` and `_MulleJulianCalendar` differ
  only in leap-year rules.
- **`NSBundle`**: accessors are O(1) plus optional `stat`; `infoDictionary` and
  localization tables are lazily parsed and cached under a lock.
- **`NSFileManager` / `NSDirectoryEnumerator`**: one or a few syscalls per
  operation; enumeration is O(total entries). `-count` materializes a fresh
  enumerator (O(n)) — avoid in hot loops.
- **`NSFileHandle`**: blocking `read`/`write`, no extra buffering;
  `mulleWriteBytes:length:` with `len == -1` scans for `'\0'`.
- **`NSRunLoop`**: each iteration is O(file descriptors + timers) bounded by the
  `select(2)` timeout. Not thread-safe; one per thread.
- **`NSTask`**: fork/exec + `waitpid`. The `mulleStringSystemCall…` helpers buffer
  the complete stdout/stderr in memory and may use a writer thread to avoid pipe
  deadlock.
- **Thread safety**: `NSBundle`, `NSFileManager`, `NSProcessInfo`, `NSFileHandle`,
  and `NSUserDefaults` are `MulleObjCThreadSafe`. `NSRunLoop` must not be shared.
  `NSTask` and `NSDateComponents` are not thread-safe. Mutable containers from
  MulleFoundationBase are not thread-safe.

## 5. AI Usage Recommendations & Patterns

### Best Practices

- Import one umbrella header (`<MulleFoundation/MulleFoundation.h>` or the
  constituent you need); individual constituent headers also work.
- Use factory methods (`+stringWithUTF8String:`, `+array`, `+dictionary`,
  `+pipe`, …); never `+alloc`/`-init`/`-autorelease` in application code.
- Use the singletons: `[NSFileManager defaultManager]`,
  `[NSProcessInfo processInfo]`, `[NSUserDefaults standardUserDefaults]`,
  `[NSRunLoop currentRunLoop]`.
- Prefer the `mulleStringSystemCall…` helpers over hand-rolling `NSTask` +
  `NSPipe` unless you need streaming I/O.
- Use `NSData`/`NSString`/`NSArray`/`NSDictionary` `…WithContentsOfFile:`
  categories for simple file I/O; use `NSData( MulleMemoryMapping)` for large
  read-only files.
- Treat methods in `( Future)` categories as usable public API, but remember a
  bare, platform-less build may not link their implementations.
- `return( expr);`, no dot-syntax, no blocks, one declaration per line.

### Common Pitfalls

- **`NSRunLoop` is per-thread.** Never instantiate/share one; use
  `+currentRunLoop`, or `+mulleCurrentRunLoop` in teardown code where creating a
  loop would be wrong.
- **Underscore methods are the platform/subclass override surface** — do not call
  them from application code (e.g. `-_removeFileAtPath:`, `-_readBytes:length:`,
  `-_acceptInputForRunLoopMode:beforeDate:`, `-_defaultsIdentifier`).
- **Base `NSUserDefaults( Persistent)` does not persist** — only the platform
  category writes to disk; `-synchronize` returns `NO` on the bare base.
- **Path utility C functions require a linked platform**; the OSBase defaults
  dispatch through a global vector table.
- **System-call helpers flatten exceptions**: check `NSTaskExceptionKey` and a
  termination status of `-1` before trusting output.
- **`NSBundle` localization stubs** (`-localizations`,
  `-preferredLocalizations`, `-localizedInfoDictionary`) may return empty/nil.
- **Archiver is either keyed or unkeyed, not both.** Probe with
  `-allowsKeyedCoding`; objects encode themselves via `-encodeWithCoder:` and
  decode via `-initWithCoder:`.
- **`char *` from `fileSystemRepresentation` / `UTF8String` is borrowed** — do
  not free it, and check `NULL` for filesystem conversions.
- **Path separators are macros**, not globals:
  `NSFilePathComponentSeparator` → `@"/"`, `NSFilePathExtensionSeparator` → `@"."`.

### Idiomatic Usage (mulle-objc style)

```c
// 3-space indent, Allman braces, aligned declarations, C89 vars,
// one var per line, no inline init, return( expr);
void   example( void)
{
   NSFileManager   *manager;
   NSString        *home;
   NSArray         *entries;

   manager = [NSFileManager defaultManager];
   home    = NSHomeDirectory();
   entries = [manager directoryContentsAtPath:home];
}
```

## 6. Integration Examples

### Example 1: Archive and unarchive a root object

```objc
#import <MulleFoundation/MulleFoundation.h>
#include <stdio.h>

void   round_trip( NSDictionary *root)
{
   NSData   *data;
   id       restored;

   data = [NSArchiver archivedDataWithRootObject:root];
   if( ! data)
   {
      printf( "archiving failed\n");
      return;
   }

   restored = [NSUnarchiver unarchiveObjectWithData:data];
   printf( "%s\n", [[restored description] UTF8String]);
}
```

### Example 2: Decompose and recompose a date with NSCalendar

```objc
#import <MulleFoundation/MulleFoundation.h>
#include <stdio.h>

void   calendar_example( void)
{
   NSCalendar       *calendar;
   NSDate           *date;
   NSDateComponents *components;
   NSDate           *later;

   calendar = [NSCalendar calendarWithIdentifier:NSGregorianCalendar];
   date     = [NSDate dateWithTimeIntervalSince1970:1700000000.0];

   components = [calendar components:NSCalendarUnitYear |
                                     NSCalendarUnitMonth |
                                     NSCalendarUnitDay
                            fromDate:date];

   printf( "%ld-%ld-%ld\n",
           (long) [components year],
           (long) [components month],
           (long) [components day]);

   [components setDay:[components day] + 7];
   later = [calendar dateByAddingComponents:components
                                     toDate:date
                                    options:0];
   printf( "%s\n", [[later description] UTF8String]);
}
```

### Example 3: Run a subprocess and capture its output

```objc
#import <MulleFoundation/MulleFoundation.h>
#include <stdio.h>

void   run_command( void)
{
   NSDictionary   *result;
   NSException    *exception;
   NSString       *output;

   result = [NSTask mulleStringSystemCallWithCommandString:@"uname -a"];

   exception = [result objectForKey:NSTaskExceptionKey];
   if( exception)
   {
      printf( "failed: %s\n", [[exception reason] UTF8String]);
      return;
   }

   output = [result objectForKey:NSTaskStandardOutputStringKey];
   printf( "%s\n", [output UTF8String]);
}
```

### Example 4: File I/O and user defaults

```objc
#import <MulleFoundation/MulleFoundation.h>
#include <stdio.h>

void   persist_example( void)
{
   NSUserDefaults *defaults;
   NSDictionary   *dictionary;
   NSString       *path;

   defaults = [NSUserDefaults standardUserDefaults];
   [defaults setInteger:42
                 forKey:@"answer"];
   [defaults synchronize];

   path       = [NSTemporaryDirectory() stringByAppendingPathComponent:@"mulle.plist"];
   dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
   if( ! dictionary)
   {
      printf( "no file at %s\n", [path UTF8String]);
      return;
   }

   if( ! [dictionary writeToFile:path
                      atomically:YES])
      printf( "write failed\n");
}
```

## 7. Dependencies

- This is an amalgamation; its constituents (`MulleObjCArchiverFoundation`,
  `MulleObjCCalendarFoundation`, `MulleObjCOSBaseFoundation`,
  `MulleObjCOSFoundation`, and the POSIX/BSD/Darwin/FreeBSD/Linux/Windows
  backends) are **embedded sources** under `src/`, not external dependencies.
- Direct `mulle-sde` library dependencies (from `clib.json` /
  `.mulle/etc/sourcetree/config`):
  - `MulleFoundationBase` — the value/container/standard/time/unicode/uuid/
    kvc/math/plist/regex foundation, re-exported by the umbrella header.
  - `math` (libm) — for the math support pulled in through `MulleFoundationBase`.
- Additional link requirements (not mulle-sde `library` deps): the `MulleObjC`
  runtime, and `mulle-objc-list` as a build-time tool.
- Types such as `NSString`, `NSArray`, `NSDate`, `NSTimeZone`, `NSError`, and
  `NSCoding` come transitively from `MulleFoundationBase` (and the runtime), not
  from this project's own sources.
