# MulleObjCLinuxFoundation Library Documentation for AI
<!-- Keywords: linux, mixin, categories, nslocale, nstimezone, nsdateformatter, nsprocessinfo -->

## 1. Introduction & Purpose

- `MulleObjCLinuxFoundation` supplies the Linux (and Android) platform back-end for the MulleFoundation Objective-C stack.
- It solves the problem that Linux's Foundation layout and C library differ from generic POSIX: the process argument list comes from `/proc/self/cmdline`, the executable path from `/proc/self/exe`, loaded shared libraries are enumerated with `dl_iterate_phdr` (ELF, not Mach-O), `timegm` is used for UTC conversion, locale data is read through `nl_langinfo_l`/`xlocale`, and Linux wants `cString`/`cStringLength` semantics instead of raw UTF-8.
- Key features:
  - Objective-C categories named `( Linux)` that **override** the generic `( Posix)` (and `( OSBase)`) category implementations for `NSBundle`, `NSCalendarDate`, `NSDateFormatter`, `NSFileManager`, `NSLocale`, `NSProcessInfo`, `NSString`, `NSTask`, `NSTimeZone` and `_MulleGMTTimeZone`.
  - The `NSString( FileSystemString)` category with `-mulleUnixFileSystemString` / `-mulleWindowsFileSystemString`.
  - The private `_NSPathUtilityVectorTable_Loader( Linux)` category that installs the Linux replacements for `NSHomeDirectory`, `NSUserName`, `NSTemporaryDirectory`, `NSSearchPathForDirectoriesInDomains`, etc.
  - The C function `mulle_posix_tm_get_time()` which provides the platform's `timegm`-based UTC conversion.
  - No new public classes and no public headers: the library is a "mixin" that changes behaviour purely by category override.
- Relationship: a platform component of MulleFoundation. It is layered `Linux -> Posix -> OSBase`, i.e. it depends on `MulleObjCPosixFoundation`.
- Build gate: `CMakeLists.txt` only compiles real code when `CMAKE_SYSTEM_NAME` matches `Linux|Android`; on any other target it clears `SOURCES`/`STAGE2_SOURCES` so an empty `INTERFACE` library is emitted (nothing compiled, linked or installed, but the target still exists for a linking consumer).

## 2. Key Concepts & Design Philosophy

- **Category override with explicit load order.** Each `( Linux)` category declares an explicit runtime dependency (e.g. `@dependency NSProcessInfo( Posix);`, `@dependency NSString( OSBase);`) so the mulle-objc runtime loads the overriding category *after* the category it overrides. The `MulleObjCDeps( MulleObjCLinuxFoundation)` category publishes that dependency table (generated into `src/reflect/objc-deps.inc`).
- **No public API surface.** The generated export/provide/include headers are empty. Callers use the normal Foundation API; the Linux behaviour is picked up automatically when this library is linked. Consequently the "signatures" in section 3 are copied from the `.m` implementation files, not from installed headers.
- **`/proc` for process state.** `NSProcessInfo( Linux)` reads argv from `/proc/self/cmdline` and the executable path via `readlink("/proc/self/exe")`. This is the Linux counterpart of the FreeBSD `sysctl` and Darwin `_NSGetArgv` approaches.
- **ELF shared-library enumeration.** `NSBundle( Linux)` walks `dl_iterate_phdr` and derives each image's `start`/`end` from its ELF program headers (`p_vaddr + p_memsz`), skipping kernel-injected entries (empty or relative `dlpi_name`).
- **Lazy, locked process state.** `NSProcessInfo( Linux)` fills `_arguments`, `_environment` and `_executablePath` on first access under the inherited `_lock`.
- **`xlocale` for locale-sensitive formatting.** `NSDateFormatter( Linux)` switches to the locale's `xlocale` via `uselocale()` around `strftime`, and `NSLocale( Linux)` reads item values through `nl_langinfo_l()`.
- **`timegm` for UTC.** Because `timegm` is a BSD/GNU extension, the UTC conversion lives here (not in the generic POSIX layer): `mulle_posix_tm_get_time()` and `_MulleGMTTimeZone( Linux)` both use it.
- **No `/private` prefix.** Linux has no `/private` path aliasing, so `-_stringByRemovingPrivatePrefix` is a no-op returning `self`.

## 3. Core API & Data Structures

Visibility note: this library installs **no** public header. Everything below is declared and implemented in the `src/*.m` files and is loaded by category. Signatures are copied verbatim from those files. Underscore-prefixed methods are the internal backend override surface and are not intended for application code.

### 3.1. `src/NSBundle+Linux.m`

`@implementation NSBundle (Linux)` — `@dependency NSBundle( Posix);`

```objc
+ (NSData *) _allSharedLibraries;
+ (BOOL) isBundleFilesystemExtension:(NSString *) extension;
```

- `+_allSharedLibraries`: calls `dl_iterate_phdr` with the `collect_filesystem_libraries` callback and returns an `NSMutableData` of `struct _MulleObjCSharedLibrary` records. Each record's `start` is `dlpi_addr`, `end` is the maximum of `dlpi_addr + p_vaddr + p_memsz` over the ELF program headers, `handle` is `NULL`, and `path` is the `dlpi_name` converted with `-[NSFileManager stringWithFileSystemRepresentation:length:]`. Entries with an empty name (the main binary) or a non-absolute name (kernel-injected) are skipped.
- `+isBundleFilesystemExtension:`: `YES` for `so`, `NO` otherwise.

### 3.2. `src/NSCalendarDate+Linux.m`

`@implementation NSCalendarDate( Linux)` — `@dependency NSCalendarDate( Posix);`

- Empty override category (marked `// EMPTY`). It only establishes the `( Linux)` load-order dependency; date arithmetic is inherited from `NSCalendarDate( Posix)`.

This file also defines the platform C function:

```c
time_t   mulle_posix_tm_get_time( struct tm *tm);
```

- Converts a broken-down `struct tm` to a `time_t` using `timegm()` (a copy of `*tm` is passed, so the caller's `tm` is not modified). Returns `0` for a `NULL` argument. This is the UTC conversion the generic POSIX layer cannot provide because `timegm` is non-standard.

It also forward-declares (private) `NSTimeZone( Posix)`:

```objc
- (NSInteger) mulleSecondsFromGMTForTimeIntervalSince1970:(NSTimeInterval) interval;
```

### 3.3. `src/NSDateFormatter+Linux.m`

`@implementation NSDateFormatter (Linux)`

```objc
- (size_t) _printTM:(struct tm *) tm
             buffer:(char *) buf
             length:(size_t) len
      formatUTF8String:(char *) c_format
             locale:(NSLocale *) locale;
```

- Formats `tm` into `buf` via `strftime`, after switching the calling thread to the locale's `xlocale` with `uselocale( [locale xlocale])` and restoring the previous locale afterwards. A `NULL` locale leaves the C locale unchanged. Asserts `tm` and `c_format` are non-`NULL` and that `locale` is `nil` or an `NSLocale`. Returns the number of bytes written (`0` on overflow, per `strftime`).

### 3.4. `src/NSFileManager+Linux.m`

`@implementation NSFileManager (Linux)` — `@dependency NSFileManager( Posix);`

```objc
- (char *) fileSystemRepresentationWithPath:(NSString *) path;
- (NSString *) stringWithFileSystemRepresentation:(char *) s
                                           length:(NSUInteger) len;
```

- `-fileSystemRepresentationWithPath:`: returns `[path cString]` when the path is non-empty and convertible to `defaultCStringEncoding`, otherwise sets `errno = EINVAL` and returns `NULL`.
- `-stringWithFileSystemRepresentation:length:`: `[NSString stringWithCString:length:]`.

### 3.5. `src/NSLocale+Linux.m`

`@implementation NSLocale (Linux)` — `@dependency NSLocale( Posix);`

```objc
+ (NSString *) systemLocalePath;
+ (instancetype) _systemLocale;
+ (instancetype) _currentLocale;
- (id) _localeInfoForKey:(id) key;
```

- `+systemLocalePath`: always `@"/usr/share/i18n/locales"`.
- `+_systemLocale` / `+_currentLocale`: build an autoreleased `NSLocale` from the environment identifier.
- `-_localeInfoForKey:`: maps `key` through `mulle_locale_map_string_key_to_local_key()` and resolves it by type: `IDENTIFIER_INFO` returns `_identifier`; `CONV_INFO` returns a `CONV_*` value via `nl_langinfo_l()` (see the static `mulle_locale_conv_info`); `LANG_INFO` returns `nl_langinfo_l( info.code, _xlocale)`. Unknown keys return `nil`.

Static behavior in this file:

- `mulle_locale_environment_identifier()`: returns the locale name from `LC_ALL`, else `LC_CTYPE`, else `LANG`; an empty variable counts as unset; falls back to `@"C"`.
- `mulle_locale_conv_nl_item()`: maps `CONV_DECIMAL_POINT`→`RADIXCHAR`, `CONV_THOUSANDS_SEPERATOR`→`THOUSEP`, `CONV_CURRENCY_SYMBOL`→`CRNCYSTR`, `CONV_INT_CURRENCY_SYMBOL`→`INT_CURR_SYMBOL`, else `-1`.
- `mulle_locale_conv_info()`: reads the mapped `nl_langinfo_l` item, strips the leading sign from `CRNCYSTR` and trailing blanks, returns an `NSString` or `nil`.

### 3.6. `src/NSPathUtilities+Linux.m`

`@implementation _NSPathUtilityVectorTable_Loader( Linux)` — `@dependency _NSPathUtilityVectorTable_Loader;`

```objc
+ (void) load;
```

- The category's `+load` installs the static `_LinuxTable` into the global `_NSPathUtilityVectors` pointer. The table (declared in the dependency header `NSPathUtilities+OSBase-Private.h`) supplies, in struct order: `NSFullUserName`, `NSHomeDirectory`, `NSHomeDirectoryForUser`, `_NSSearchPathForDirectoriesInDomains`, `NSOpenStepRootDirectory`, `NSTemporaryDirectory`, `NSUserName`.
- Linux implementations:
  - `NSFullUserName` and `NSUserName` both map to `LinuxUserName`: reads `USER`, falling back to `LOGNAME`, falling back to `getpwuid( getuid())->pw_name`, falling back to `@"unknown"`. (Note: `NSFullUserName` is therefore not a real full name on this platform.)
  - `NSHomeDirectory`: reads `HOME`, falling back to `@""` (bash-compatible).
  - `NSHomeDirectoryForUser`: `getpwnam( [userName UTF8String])->pw_dir`, or `nil` if `userName` is not UTF-8-convertible or the user is unknown.
  - `NSOpenStepRootDirectory`: always `@"/"`.
  - `NSTemporaryDirectory`: reads `TMPDIR`, falling back to `@"/tmp"`.
  - `_NSSearchPathForDirectoriesInDomains`: walks the requested domains (`NSUserDomainMask`→`~`, `NSLocalDomainMask`→`/usr/lib`, `NSNetworkDomainMask`→`/var/net`, `NSSystemDomainMask`→`NSOpenStepRootDirectory()`), appends the directory returned by `pathForType()` for each, and returns the accumulated `NSMutableArray`. Handles `NSAllApplicationsDirectory` and `NSAllLibrariesDirectory` specially; types with no mapping contribute nothing.

### 3.7. `src/NSProcessInfo+Linux.m`

`@implementation NSProcessInfo( Linux)` — `@dependency NSProcessInfo( Posix);`

```objc
- (NSArray *) arguments;
- (NSDictionary *) environment;
- (NSString *) _executablePath;
- (NSString *) hostName;
- (NSString *) operatingSystemName;
- (NSUInteger) operatingSystem;
- (NSString *) processName;
- (void) setProcessName:(NSString *) name;
```

- `-arguments`: lazily built under `_lock` by `unlazyArguments()`, which reads `/proc/self/cmdline` (size probe, then read) and builds the array with `+[NSArray _newWithArgc:argv:]`. Throws `MulleObjCThrowInternalInconsistencyException` if `/proc/self/cmdline` cannot be read. Under `__MULLE_COSMOPOLITAN__` the leading `ape` argument is lopped off.
- `-environment`: lazily built under `_lock` from the C `environ` global via `+[NSDictionary _newWithEnvironment:]`.
- `-_executablePath`: lazily resolved under `_lock` via `readlink("/proc/self/exe")` (into a `PATH_MAX + 1` buffer) and `-[NSString initWithCString:length:]`. Throws `MulleObjCThrowInternalInconsistencyException` on failure.
- `-hostName`: always `@"localhost"`.
- `-operatingSystemName`: always `@"Linux"`.
- `-operatingSystem`: always `NSLinuxOperatingSystem`.
- `-processName`: the `lastPathComponent` of `-_executablePath` (i.e. the executable's file name).
- `-setProcessName:`: no-op; the comment notes that `setprogname` is not native and linking against bsd-compat is avoided.

### 3.8. `src/NSString+Linux.m`

`@implementation NSString( Linux)` — `@dependency NSString( OSBase);`

```objc
- (NSString *) _stringByRemovingPrivatePrefix;
- (NSUInteger) cStringLength;
- (char *) cString;
- (NSStringEncoding) _cStringEncoding;
+ (NSStringEncoding) defaultCStringEncoding;
```

- `-_stringByRemovingPrivatePrefix`: returns `self` unchanged (Linux has no `/private` alias).
- `-cStringLength`: `[self mulleUTF8StringLength]`.
- `-cString`: `(char *) [self UTF8String]`.
- `-_cStringEncoding` / `+defaultCStringEncoding`: `mulle_posix_cstring_encoding()`.

`@implementation NSString( FileSystemString)`

```objc
- (NSString *) mulleUnixFileSystemString;
- (NSString *) mulleWindowsFileSystemString;
```

- `-mulleUnixFileSystemString`: returns `self` unchanged.
- `-mulleWindowsFileSystemString`: replaces `/` with `\` via `-stringByReplacingOccurrencesOfString:withString:`.

### 3.9. `src/NSTask+Linux.m`

`@implementation NSTask( Linux)` — `@dependency NSTask( Posix);`

- Empty override category. Process control is implemented generically in `NSTask( Posix)`; this category only establishes the `( Linux)` load-order dependency. The child environment is supplied by `mulle-spawn` (as `options.env`), so the former `+_environment` that handed this platform's `environ` to fork/execve was removed rather than moved.

### 3.10. `src/NSTimeZone+Linux.m`

`@implementation NSTimeZone( Linux)` — `@dependency NSTimeZone( Posix);`

```objc
- (NSTimeInterval) _timeIntervalSince1970ForTM:(struct tm *) tm;
```

- Copies the broken-down fields from `tm` into a `struct tz_tm`, resolves the interval through the external `mulle_get_timeinterval_for_tm( [_data bytes], &tmp)` (the timezone rule data lives in `_data`), writes the normalized fields back into `tm`, and returns the interval. Throws `MulleObjCThrowInvalidArgumentException` if the result is `-1`.

### 3.11. `src/_MulleGMTTimeZone+Linux.m`

`@implementation _MulleGMTTimeZone (Linux)`

```objc
- (NSTimeInterval) _timeIntervalSince1970ForTM:(struct tm *) tm;
```

- Returns `timegm( tm)` directly — a fast UTC-only conversion that bypasses the timezone rule data used by `NSTimeZone( Linux)`.

### 3.12. `src/MulleObjCDeps+MulleObjCLinuxFoundation.m`

`@implementation MulleObjCDeps( MulleObjCLinuxFoundation)`

```objc
+ (struct _mulle_objc_dependency *) dependencies;
```

- Returns the static category dependency table included from `src/reflect/objc-deps.inc`: `NSBundle( Linux)`, `NSCalendarDate( Linux)`, `NSDateFormatter( Linux)`, `NSFileManager( Linux)`, `NSLocale( Linux)`, `NSProcessInfo( Linux)`, `NSString( FileSystemString)`, `NSString( Linux)`, `NSTask( Linux)`, `NSTimeZone( Linux)`, `_MulleGMTTimeZone( Linux)` and `_NSPathUtilityVectorTable_Loader( Linux)`.

### 3.13. Generic Import Headers

- `src/generic/include.h` / `src/generic/import.h`: public central include/import headers that pull in the generated `_MulleObjCLinuxFoundation-include.h` / `_MulleObjCLinuxFoundation-import.h` files.
- `src/generic/include-private.h` / `src/generic/import-private.h`: private counterparts used by `.c`/`.m` files only.
- `src/reflect/_MulleObjCLinuxFoundation-import.h`: imports the dependency umbrella `<MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>`.
- `src/reflect/_MulleObjCLinuxFoundation-export.h`: currently exports no headers.

## 4. Performance Characteristics

- Path accessors (`NSFileManager`, `NSPathUtilities`) are O(1) string operations; `-fileSystemRepresentationWithPath:` may scan the string for encoding convertibility. `_NSSearchPathForDirectoriesInDomains` is O(d·n) in the number of requested domains and mapped directory types.
- `+[NSBundle _allSharedLibraries]` is O(n) in the number of loaded ELF images and their program headers; it allocates an `NSMutableData` and one `NSString` per image.
- `NSProcessInfo` lazy accessors copy the whole argv/environ once; subsequent calls return an autoreleased cached object. Access is serialised by the inherited `_lock`. `-arguments` performs two `/proc/self/cmdline` opens (size probe then read) plus one `mulle_calloc`.
- `NSDateFormatter -_printTM:...` is O(n) in the length of the format string plus O(m) in the formatted output, with one `uselocale`/`uselocale` pair.
- `NSLocale` item lookup is O(1) per key (one `nl_langinfo_l` call) after a constant mapping.
- The `_NSPathUtilityVectorTable` is written exactly once in `+load` and never mutated afterwards; the functions it points to are stateless, so concurrent reads are safe.
- Thread-safety: the library is not an additional locking layer. `NSProcessInfo` uses its inherited lock; `NSDateFormatter` and `NSLocale` rely on the per-thread `xlocale` (thread-local), `NSBundle`, `NSFileManager` and path utilities are effectively stateless. The categories do not synchronise the underlying filesystem, `/proc` or loader state.

## 5. AI Usage Recommendations & Patterns

- **Best practices:**
  - Use the ordinary Foundation API (`NSBundle`, `NSProcessInfo`, `NSFileManager`, `NSString`, `NSLocale`, `NSTimeZone`). The `( Linux)` categories are installed automatically when the library is linked; there is no header to import from this project.
  - When writing platform glue that must also work on other platforms, prefer the generic `( Posix)` methods; the Linux category overrides only where Linux genuinely differs.
  - For process globals use `[NSProcessInfo processInfo]` rather than reading `/proc`, `environ` or the C `argv` directly.
  - For locale-sensitive formatting, use `NSDateFormatter` / `NSLocale` so the correct `xlocale` is selected per thread.
- **Common pitfalls:**
  - Do **not** call the underscore-prefixed methods (`+_allSharedLibraries`, `-_executablePath`, `-_stringByRemovingPrivatePrefix`, `-_cStringEncoding`, `-_printTM:...`, `-_localeInfoForKey:`, `-_timeIntervalSince1970ForTM:`). They are the override surface and may be tied to a specific dependency.
  - Do not manually touch `_NSPathUtilityVectors` or instantiate `_NSPathUtilityVectorTable_Loader`; the `+load` method does the registration. On non-Linux platforms the library is empty, so the POSIX behaviour stays in effect.
  - `-[NSFileManager fileSystemRepresentationWithPath:]` can return `NULL` and set `errno`; always check.
  - `-[NSProcessInfo arguments]` and `-[NSProcessInfo _executablePath]` throw `MulleObjCThrowInternalInconsistencyException` if `/proc` is unavailable (e.g. some sandboxes/containers); do not assume they always succeed.
  - `NSFullUserName` and `NSUserName` return the same value on Linux (the login name).
  - `NSTimeZone( Linux)` throws `MulleObjCThrowInvalidArgumentException` for an interval it cannot convert; `_MulleGMTTimeZone( Linux)` does not (it is UTC-only).
- **Idiomatic usage:** import the dependency umbrella (`#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>` for C/Objective-C callers), link `MulleObjCLinuxFoundation`, and call standard Foundation methods — never re-declare the category methods.

## 6. Integration Examples

### Example 1: Inspecting process arguments and environment

```objc
#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>
#include <stdio.h>

void
print_process_info( void)
{
   NSProcessInfo   *info;
   NSArray         *arguments;
   NSString        *name;
   NSUInteger      i;

   info      = [NSProcessInfo processInfo];
   arguments = [info arguments];
   name      = [info operatingSystemName];

   printf( "os: %s, pid-args: %lu\n",
           [name UTF8String], (unsigned long) [arguments count]);

   for( i = 0; i < [arguments count]; i++)
      printf( "  argv[%lu] = %s\n",
              (unsigned long) i, [[arguments objectAtIndex:i] UTF8String]);
}
```

### Example 2: File system representation of a path

```objc
#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

void
print_fs_representation( NSString *path)
{
   NSFileManager   *manager;
   char            *representation;

   manager        = [NSFileManager defaultManager];
   representation = [manager fileSystemRepresentationWithPath:path];
   if( ! representation)
   {
      printf( "bad path: %s\n", strerror( errno));
      return;
   }

   printf( "path: %s\n", representation);
}
```

### Example 3: Reading selected locale information

```objc
#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>
#include <stdio.h>

void
print_locale_info( void)
{
   NSLocale   *locale;
   NSString   *decimal;
   NSString   *currency;

   locale   = [NSLocale currentLocale];
   decimal  = [locale objectForKey:NSLocaleDecimalSeparator];
   currency = [locale objectForKey:NSLocaleCurrencySymbol];

   printf( "locale:   %s\n", [[locale localeIdentifier] UTF8String]);
   printf( "decimal:  %s\n", [decimal UTF8String]);
   printf( "currency: %s\n", [currency UTF8String]);
}
```

### Example 4: Converting a path between Unix and Windows form

```objc
#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>
#include <stdio.h>

void
print_converted( NSString *path)
{
   NSString   *unixPath;
   NSString   *windowsPath;

   unixPath    = [path mulleUnixFileSystemString];
   windowsPath = [path mulleWindowsFileSystemString];

   printf( "unix:    %s\n", [unixPath UTF8String]);
   printf( "windows: %s\n", [windowsPath UTF8String]);
}
```

## 7. Dependencies

- `MulleObjCPosixFoundation` (direct; marked `no-singlephase` in `.mulle/etc/sourcetree/config`; its umbrella `<MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>` is imported by the generated `_MulleObjCLinuxFoundation-import.h`)
