# MulleObjCDarwinFoundation Library Documentation for AI
<!-- Keywords: darwin, mixin, categories, nsbundle, nsprocessinfo, nspathutilities, nsfilemanager -->

## 1. Introduction & Purpose

- `MulleObjCDarwinFoundation` supplies the Darwin (macOS) platform back-end for the MulleFoundation Objective-C stack.
- It solves the problem that Darwin's Foundation layout and C library differ from generic POSIX: `.app` / `.framework` bundles use a `Contents/` directory (`Contents/MacOS`, `Contents/Resources`, `Contents/Frameworks`), Darwin wants `cString`/`cStringLength` semantics instead of raw UTF-8, `strftime` handles `%z`/`%Z` incorrectly, `struct stat` exposes `st_ctimespec`/`st_mtimespec`, the process argument list comes from `_NSGetArgc`/`_NSGetArgv`/`_NSGetEnviron`, and user records are read through `dscl`.
- Key features:
  - Objective-C categories named `( Darwin)` that **override** the generic `( Posix)` or `( BSD)` category implementations for `NSBundle`, `NSFileManager`, `NSDateFormatter`, `NSProcessInfo`, `NSString` and `NSTask`.
  - The `NSString( FileSystemString)` category with `-mulleUnixFileSystemString` / `-mulleWindowsFileSystemString`.
  - The private `_NSPathUtilityVectorTable_Loader( Darwin)` category that installs the Darwin replacements for `NSHomeDirectory`, `NSUserName`, `NSTemporaryDirectory`, `NSSearchPathForDirectoriesInDomains`, etc.
  - No new public classes and no public headers: the library is a "mixin" that changes behaviour purely by category override.
- Relationship: a platform component of MulleFoundation. It is layered `Darwin -> BSD -> Posix -> OSBase`, i.e. it depends on `MulleObjCBSDFoundation` and `MulleObjCPosixFoundation`.
- Build gate: `CMakeLists.txt` only compiles real code when `APPLE` is set; on any other target it emits an empty `INTERFACE` library.

## 2. Key Concepts & Design Philosophy

- **Category override with explicit load order.** Each `( Darwin)` category declares an explicit runtime dependency (`@dependency NSBundle( Posix);`, `@dependency NSDateFormatter( BSD);`, …) so the mulle-objc runtime loads the overriding category *after* the category it overrides. The `MulleObjCDeps( MulleObjCDarwinFoundation)` category publishes that dependency table (generated into `src/reflect/objc-deps.inc`).
- **No public API surface.** The generated export/provide/include headers are empty. Callers use the normal Foundation API; the Darwin behaviour is picked up automatically when this library is linked. Consequently the "signatures" in section 3 are copied from the `.m` implementation files, not from installed headers.
- **Two bundle layouts.** A "true" macOS bundle has a `Contents/` directory; a POSIX-style bundle (`<root>/bin` + `<root>/share`) does not. `hasContents()` decides, and when there is no `Contents/` the category delegates to the inherited `( Posix)` implementation so cross-platform code gets consistent answers.
- **`dscl` for user records.** `DarwinFullUserName` and `DarwinHomeDirectoryForUser` shell out to `dscl` (`DSCL_UTILITY_PATH`, default `/usr/bin/dscl`) rather than linking to Directory Services.
- **Lazy, locked process state.** `NSProcessInfo( Darwin)` fills `_arguments`, `_environment` and `_executablePath` on first access under the inherited `_lock`.
- **Darwin `strftime` workaround.** `NSDateFormatter( Darwin)` pre-expands `%z` / `%Z` into a stack buffer before calling `strftime`/`strftime_l`, because Darwin ignores `tm_gmtoff`/`tm_zone` for those conversions.

## 3. Core API & Data Structures

Visibility note: this library installs **no** public header. Everything below is declared and implemented in the `src/*.m` files and is loaded by category. Signatures are copied verbatim from those files. Underscore-prefixed methods are the internal backend override surface and are not intended for application code.

### 3.1. `src/NSBundle+Darwin.m`

`@implementation NSBundle( Darwin)` — `@dependency NSBundle( Posix);`

The category relies on these private `NSBundle( Posix)` methods: `-_posixResourcePath`, `-_loadFailureReason`, `-_posixBuiltInPlugInsPath`, `-_posixPathForAuxiliaryExecutable:`, `-_posixPrivateFrameworksPath`, `-_posixSharedFrameworksPath`, `-_posixSharedSupportPath`, `-_posixExecutablePath`.

#### Bundle layout/path accessors

```objc
- (NSString *) builtInPlugInsPath;
- (NSString *) pathForAuxiliaryExecutable:(NSString *) executableName;
- (NSString *) privateFrameworksPath;
- (NSString *) sharedFrameworksPath;
- (NSString *) sharedSupportPath;
- (NSString *) _resourcePath;
- (NSString *) _executablePath;
```

- `-builtInPlugInsPath`: returns `Contents/Resources/PlugIns` if it exists, `nil` if not; falls back to `-_posixBuiltInPlugInsPath` when there is no `Contents/` directory.
- `-pathForAuxiliaryExecutable:`: returns `Contents/<OSIdentifier>/<name>` for a true bundle, else `-( Posix)` result.
- `-privateFrameworksPath`, `-sharedFrameworksPath`, `-sharedSupportPath`: `Contents/Frameworks`, `Contents/SharedFrameworks`, `Contents/SharedSupport`; fall back to the POSIX variant without a `Contents/` directory.
- `-_resourcePath`: prefers `Contents/Resources`, then `Resources`, then the POSIX resource path for a `.dylib`, else `bundlePath`.
- `-_executablePath`: derives the executable from `NSExecutable` or the bundle name under `Contents/<OSIdentifier>`, verifying executability; falls back to `-_posixExecutablePath`.

#### Bundle identity

```objc
- (NSString *) bundleIdentifier;
- (NSString *) developmentLocalization;
- (BOOL) preflightAndReturnError:(NSError **) error;
```

- `-bundleIdentifier`: `CFBundleIdentifier` or `NSBundleIdentifier` from `infoDictionary`.
- `-developmentLocalization`: `CFBundleDevelopmentRegion` or `NSBundleDevelopmentRegion` from `infoDictionary`.
- `-preflightAndReturnError:`: runs `dlopen_preflight` on `executablePath`; on failure sets `*error` to an `NSError` in `NSPOSIXErrorDomain` with `NSLocalizedDescriptionKey` from `-_loadFailureReason`.

#### Class-level helpers

```objc
+ (NSData *) _allSharedLibraries;
+ (NSString *) _mainBundlePathForExecutablePath:(NSString *) executablePath;
+ (BOOL) isBundleFilesystemExtension:(NSString *) extension;
+ (NSString *) _bundlePathForExecutablePath:(NSString *) executablePath;
```

- `+_allSharedLibraries`: walks `_dyld_get_image_name`/`_dyld_get_image_header`, computes each image's `start`/`end` from its Mach-O `LC_SEGMENT`/`LC_SEGMENT_64` load commands, and returns an `NSMutableData` of `struct _MulleObjCSharedLibrary` records.
- `+_mainBundlePathForExecutablePath:`: strips `MacOS/<arch>` and `Contents` components from the given symlink-resolved path. Requires the path to already be symlink-resolved (`NSParameterAssert`).
- `+isBundleFilesystemExtension:`: `YES` for `dylib` and `bundle`.
- `+_bundlePathForExecutablePath:`: maps an executable path back to its bundle path for dylibs, PlugIns (`MacOS` parent), and `.framework` (`Versions/A`) layouts.

### 3.2. `src/NSDateFormatter+Darwin.m`

`@implementation NSDateFormatter( Darwin)` — `@dependency NSDateFormatter( BSD);`

```objc
- (size_t) _printTM:(struct tm *) tm
             buffer:(char *) buf
             length:(size_t) len
      formatUTF8String:(char *) c_format
             locale:(NSLocale *) locale;
```

- Formats `tm` into `buf` using the locale's `xlocale` (`strftime_l`) or plain `strftime`. Because Darwin's `strftime` ignores `tm_gmtoff`/`tm_zone` for `%z`/`%Z`, the format string is first scanned by `percent_z_find` and expanded by `percent_z_replace` into a tight stack buffer (max 1024 bytes, else `MulleObjCThrowInvalidArgumentException`) before the actual conversion. `locale` must be an `NSLocale`.

### 3.3. `src/NSFileManager+Darwin.m`

`@implementation NSFileManager (Darwin)` — `@dependency NSFileManager( Posix);`

```objc
- (char *) fileSystemRepresentationWithPath:(NSString *) path;
- (NSString *) stringWithFileSystemRepresentation:(char *) s
                                           length:(NSUInteger) len;
- (struct timespec) _getCTimeFromStat:(void *) aStat;
- (struct timespec) _getMTimeFromStat:(void *) aStat;
```

- `-fileSystemRepresentationWithPath:`: returns `[path cString]` when the path is non-empty and convertible to `defaultCStringEncoding`, otherwise sets `errno = EINVAL` and returns `NULL`.
- `-stringWithFileSystemRepresentation:length:`: `[NSString stringWithCString:length:]`.
- `-_getCTimeFromStat:` / `-_getMTimeFromStat:`: extract `stat->st_ctimespec` / `stat->st_mtimespec`. The `void *` argument deliberately avoids Darwin's differing `stat` type encoding in the method signature.

### 3.4. `src/NSPathUtilities+Darwin.m`

`@implementation _NSPathUtilityVectorTable_Loader( Darwin)` — `@dependency _NSPathUtilityVectorTable_Loader;`

```objc
+ (void) load;
```

- The category's `+load` installs the static `_DarwinTable` into the global `_NSPathUtilityVectors` pointer. The table (declared in the dependency header `NSPathUtilities+OSBase-Private.h`) supplies: `NSFullUserName`, `NSHomeDirectory`, `NSHomeDirectoryForUser`, `_NSSearchPathForDirectoriesInDomains`, `NSOpenStepRootDirectory`, `NSTemporaryDirectory`, `NSUserName`.
- Darwin implementations: full user name and per-user home directory come from `dscl`; `NSHomeDirectory` reads `HOME` (falling back to `dscl`); `NSTemporaryDirectory` reads `TMPDIR` (falling back to `/tmp`); `NSUserName` reads `USER` (falling back to `LOGNAME`); `NSOpenStepRootDirectory` is `/`; `NSSearchPathForDirectoriesInDomains` maps `NSSearchPathDirectory`/`NSSearchPathDomainMask` to `~/`, `/Library`, `/Network`, `/System/Library` variants.

### 3.5. `src/NSProcessInfo+Darwin.m`

`@implementation NSProcessInfo( Darwin)` — `@dependency NSProcessInfo( BSD);`

```objc
- (NSArray *) arguments;
- (NSDictionary *) environment;
- (NSString *) _executablePath;
- (NSString *) hostName;
- (NSUInteger) operatingSystem;
- (NSString *) operatingSystemName;
```

- `-arguments` / `-environment`: lazily built from `_NSGetArgc`, `_NSGetArgv` and `_NSGetEnviron` (`_NSGetArgcArgvEnviron`), then returned retained+autoreleased under `_lock`.
- `-_executablePath`: lazily resolved with `_NSGetExecutablePath` under `_lock`.
- `-hostName`: always `@"localhost"`.
- `-operatingSystem`: always `NSDarwinOperatingSystem`.
- `-operatingSystemName`: always `@"Darwin"`.

### 3.6. `src/NSString+Darwin.m`

`@implementation NSString( Darwin)` — `@dependency NSString( OSBase);`

```objc
- (NSString *) _stringByRemovingPrivatePrefix;
- (NSUInteger) cStringLength;
- (char *) cString;
- (NSStringEncoding) _cStringEncoding;
+ (NSStringEncoding) defaultCStringEncoding;
```

- `-_stringByRemovingPrivatePrefix`: if `self` starts with `"/private"` and exists on disk, returns the path without that prefix (8 characters), otherwise returns `self`.
- `-cStringLength`: `[self mulleUTF8StringLength]`.
- `-cString`: `(char *) [self UTF8String]`.
- `-_cStringEncoding` / `+defaultCStringEncoding`: `mulle_posix_cstring_encoding()`.

`@implementation NSString( FileSystemString)`

```objc
- (NSString *) mulleUnixFileSystemString;
- (NSString *) mulleWindowsFileSystemString;
```

- `-mulleUnixFileSystemString`: returns `self` unchanged.
- `-mulleWindowsFileSystemString`: replaces `/` with `\`.

### 3.7. `src/NSTask+Darwin.m`

`@implementation NSTask( Darwin)` — `@dependency NSTask( BSD);`

- Empty override category. Process control is implemented generically in `NSTask( Posix)`; this category only establishes the load-order dependency. The former Darwin `+_environment` (via `_NSGetEnviron`/`<crt_externs.h>`) was removed because child environments are now supplied by `mulle-spawn`.

### 3.8. `src/MulleObjCDeps+MulleObjCDarwinFoundation.m`

```objc
+ (struct _mulle_objc_dependency *) dependencies;
```

- Returns the static category dependency table included from `src/reflect/objc-deps.inc`: `NSBundle( Darwin)`, `NSDateFormatter( Darwin)`, `NSFileManager( Darwin)`, `NSProcessInfo( Darwin)`, `NSString( Darwin)`, `NSString( FileSystemString)`, `NSTask( Darwin)` and `_NSPathUtilityVectorTable_Loader( Darwin)`.

## 4. Performance Characteristics

- Path accessors (`NSBundle`, `NSPathUtilities`) are O(1) string operations plus, for `NSBundle`, one or more `NSFileManager` existence checks that perform filesystem `stat` syscalls.
- `+[NSBundle _allSharedLibraries]` is O(n) in the number of loaded Mach-O images and their load commands.
- `-[NSDateFormatter _printTM:...]` is O(n) in the length of the format string for the `%z`/`%Z` pre-scan, plus O(m) in the formatted output. It uses bounded stack storage (`needed_len + 2`, hard-capped at 1024).
- `NSProcessInfo` lazy accessors copy the whole argv/environ once; subsequent calls return an autoreleased cached object. Access is serialised by the inherited `_lock`.
- `NSFileManager` accessors are O(1); `-fileSystemRepresentationWithPath:` may scan the string for encoding convertibility.
- The `_NSPathUtilityVectorTable` is written exactly once in `+load` and never mutated afterwards; the functions it points to are stateless, so concurrent reads are safe.
- Thread-safety: the library is not an additional locking layer. `NSProcessInfo` uses its inherited lock; `NSBundle` and path utilities are effectively stateless. The categories do not synchronise the underlying filesystem or dyld state.

## 5. AI Usage Recommendations & Patterns

- **Best practices:**
  - Use the ordinary Foundation API (`NSBundle`, `NSProcessInfo`, `NSFileManager`, `NSString`). The `( Darwin)` categories are installed automatically when the library is linked; there is no header to import from this project.
  - When writing platform glue that must also work on other platforms, prefer the generic `( Posix)`/`( BSD)` methods; the Darwin category delegates to them when there is no `Contents/` directory.
  - For process globals use `[NSProcessInfo processInfo]` rather than reading the C globals directly.
- **Common pitfalls:**
  - Do **not** call the underscore-prefixed methods (`-_resourcePath`, `-_executablePath`, `-_getCTimeFromStat:`, `-_printTM:...`, `-_stringByRemovingPrivatePrefix`, `+_allSharedLibraries`, `+_mainBundlePathForExecutablePath:`, `+_bundlePathForExecutablePath:`, `-_cStringEncoding`). They are the override surface and may be tied to a specific dependency.
  - Do not manually touch `_NSPathUtilityVectors` or instantiate `_NSPathUtilityVectorTable_Loader`; the `+load` method does the registration. On non-`APPLE` platforms the library is empty, so the POSIX behaviour stays in effect.
  - `+_mainBundlePathForExecutablePath:` and `+_bundlePathForExecutablePath:` require a symlink-resolved path (they assert it); pass the result of `-stringByResolvingSymlinksInPath`.
  - `-[NSFileManager fileSystemRepresentationWithPath:]` can return `NULL` and set `errno`; always check.
  - `-[NSDateFormatter _printTM:...]` throws `MulleObjCThrowInvalidArgumentException` for a timezone name containing `%` or for a format that expands beyond 1024 characters.
- **Idiomatic usage:** import the dependency umbrella (`#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>` for C/Objective-C callers), link `MulleObjCDarwinFoundation`, and call standard Foundation methods — never re-declare the category methods.

## 6. Integration Examples

### Example 1: Reading bundle resources on Darwin

```objc
#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>
#include <stdio.h>

void
print_bundle_paths( void)
{
   NSBundle   *bundle;
   NSString   *path;

   bundle = [NSBundle mainBundle];

   path = [bundle resourcePath];
   if( path)
      printf( "resources: %s\n", [path UTF8String]);

   path = [bundle sharedSupportPath];
   if( path)
      printf( "shared support: %s\n", [path UTF8String]);

   path = [bundle pathForAuxiliaryExecutable:@"helper"];
   printf( "helper: %s\n", path ? [path UTF8String] : "(none)");
}
```

### Example 2: Inspecting process arguments and environment

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

### Example 3: File system representation of a path

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

- `MulleObjCBSDFoundation` (direct; marked `no-header,no-singlephase` in `.mulle/etc/sourcetree/config`, so its headers are not imported)
- `MulleObjCPosixFoundation` (direct; its umbrella `<MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>` is imported by the generated `_MulleObjCDarwinFoundation-import.h`)
