# MulleObjCFreeBSDFoundation Library Documentation for AI
<!-- Keywords: freebsd, mixin, categories, nsbundle, nsprocessinfo, nspathutilities, nsfilemanager -->

## 1. Introduction & Purpose

- `MulleObjCFreeBSDFoundation` supplies the FreeBSD platform back-end for the MulleFoundation Objective-C stack.
- It solves the problem that FreeBSD's Foundation layout and C library differ from generic POSIX: the process argument list and executable path come from `sysctl` (`KERN_PROC_ARGS`, `KERN_PROC_PATHNAME`) rather than `/proc`, loaded shared libraries are enumerated with `dl_iterate_phdr` (ELF, not Mach-O), and FreeBSD wants `cString`/`cStringLength` semantics instead of raw UTF-8.
- Key features:
  - Objective-C categories named `( FreeBSD)` that **override** the generic `( Posix)` or `( BSD)` category implementations for `NSBundle`, `NSFileManager`, `NSProcessInfo`, `NSString` and `NSTask`.
  - The `NSString( FileSystemString)` category with `-mulleUnixFileSystemString` / `-mulleWindowsFileSystemString`.
  - The private `_NSPathUtilityVectorTable_Loader( FreeBSD)` category that installs the FreeBSD replacements for `NSHomeDirectory`, `NSUserName`, `NSTemporaryDirectory`, `NSSearchPathForDirectoriesInDomains`, etc.
  - No new public classes and no public headers: the library is a "mixin" that changes behaviour purely by category override.
- Relationship: a platform component of MulleFoundation. It is layered `FreeBSD -> BSD -> Posix -> OSBase`, i.e. it depends on `MulleObjCBSDFoundation` and `MulleObjCPosixFoundation`.
- Build gate: `CMakeLists.txt` only compiles real code when `CMAKE_SYSTEM_NAME` matches `FreeBSD`; on any other target it clears the sources so an empty `INTERFACE` library is emitted (nothing compiled, linked or installed, but the target still exists for a linking consumer).

## 2. Key Concepts & Design Philosophy

- **Category override with explicit load order.** Each `( FreeBSD)` category declares an explicit runtime dependency (`@dependency NSBundle( Posix);`, `@dependency NSProcessInfo( BSD);`, …) so the mulle-objc runtime loads the overriding category *after* the category it overrides. The `MulleObjCDeps( MulleObjCFreeBSDFoundation)` category publishes that dependency table (generated into `src/reflect/objc-deps.inc`).
- **No public API surface.** The generated export/provide/include headers are empty. Callers use the normal Foundation API; the FreeBSD behaviour is picked up automatically when this library is linked. Consequently the "signatures" in section 3 are copied from the `.m` implementation files, not from installed headers.
- **`sysctl` for process state.** `NSProcessInfo( FreeBSD)` reads argv from `CTL_KERN`/`KERN_PROC`/`KERN_PROC_ARGS` and the executable path from `KERN_PROC_PATHNAME`; if the executable path cannot be resolved it falls back to an absolute `argv[0]`.
- **ELF shared-library enumeration.** `NSBundle( FreeBSD)` walks `dl_iterate_phdr` and derives each image's `start`/`end` from its ELF program headers (`p_vaddr + p_memsz`), skipping kernel-injected entries (empty or relative `dlpi_name`).
- **Lazy, locked process state.** `NSProcessInfo( FreeBSD)` fills `_arguments`, `_environment` and `_executablePath` on first access under the inherited `_lock`.
- **No `/private` prefix.** Unlike Darwin, FreeBSD has no `/private` path aliasing, so `-_stringByRemovingPrivatePrefix` is a no-op returning `self`.

## 3. Core API & Data Structures

Visibility note: this library installs **no** public header. Everything below is declared and implemented in the `src/*.m` files and is loaded by category. Signatures are copied verbatim from those files. Underscore-prefixed methods are the internal backend override surface and are not intended for application code.

### 3.1. `src/NSBundle+FreeBSD.m`

`@implementation NSBundle( FreeBSD)` — `@dependency NSBundle( Posix);`

```objc
+ (NSData *) _allSharedLibraries;
```

- `+_allSharedLibraries`: calls `dl_iterate_phdr` with the `collect_filesystem_libraries` callback and returns an `NSMutableData` of `struct _MulleObjCSharedLibrary` records. Each record's `start` is `dlpi_addr`, `end` is the maximum of `dlpi_addr + p_vaddr + p_memsz` over the ELF program headers, `handle` is `NULL`, and `path` is the `dlpi_name` converted with `-[NSFileManager stringWithFileSystemRepresentation:length:]`. Entries with an empty name (the main binary) or a non-absolute name (kernel-injected) are skipped.

### 3.2. `src/NSFileManager+FreeBSD.m`

`@implementation NSFileManager (FreeBSD)` — `@dependency NSFileManager( Posix);`

```objc
- (char *) fileSystemRepresentationWithPath:(NSString *) path;
- (NSString *) stringWithFileSystemRepresentation:(char *) s
                                           length:(NSUInteger) len;
```

- `-fileSystemRepresentationWithPath:`: returns `[path cString]` when the path is non-empty and convertible to `defaultCStringEncoding`, otherwise sets `errno = EINVAL` and returns `NULL`.
- `-stringWithFileSystemRepresentation:length:`: `[NSString stringWithCString:length:]`.

### 3.3. `src/NSPathUtilities+FreeBSD.m`

`@implementation _NSPathUtilityVectorTable_Loader( FreeBSD)` — `@dependency _NSPathUtilityVectorTable_Loader;`

```objc
+ (void) load;
```

- The category's `+load` installs the static `_FreeBSDTable` into the global `_NSPathUtilityVectors` pointer. The table (declared in the dependency header `NSPathUtilities+OSBase-Private.h`) supplies, in struct order: `NSFullUserName`, `NSHomeDirectory`, `NSHomeDirectoryForUser`, `_NSSearchPathForDirectoriesInDomains`, `NSOpenStepRootDirectory`, `NSTemporaryDirectory`, `NSUserName`.
- FreeBSD implementations:
  - `NSFullUserName` and `NSUserName` both map to `FreeBSDUserName`: reads `USER`, falling back to `LOGNAME`, falling back to `getpwuid( getuid())->pw_name`, falling back to `@"unknown"`. (Note: `NSFullUserName` is therefore not a real full name on this platform.)
  - `NSHomeDirectory`: reads `HOME`, falling back to `@""`.
  - `NSHomeDirectoryForUser`: `getpwnam( [userName UTF8String])->pw_dir`, or `nil` if the user is unknown.
  - `NSOpenStepRootDirectory`: always `@"/"`.
  - `NSTemporaryDirectory`: reads `TMPDIR`, falling back to `@"/tmp"`.
  - `_NSSearchPathForDirectoriesInDomains`: currently a stub — it computes domain prefixes (`~`, `/usr/lib`, `/var/net`, the system root) but the `switch` on the search-path type only `break`s, so it returns an empty array.

### 3.4. `src/NSProcessInfo+FreeBSD.m`

`@implementation NSProcessInfo( FreeBSD)` — `@dependency NSProcessInfo( BSD);`

```objc
- (NSArray *) arguments;
- (NSDictionary *) environment;
- (NSString *) _executablePath;
- (NSString *) hostName;
- (NSUInteger) operatingSystem;
- (NSString *) operatingSystemName;
```

- `-arguments`: lazily built under `_lock` by `_NSGetArgcArgv`, which reads the raw NUL-terminated argument space via `sysctl( CTL_KERN, KERN_PROC, KERN_PROC_ARGS, getpid())` and constructs an `NSArray` with `+[NSArray _newWithArgc:argv:]`. Throws `MulleObjCThrowInternalInconsistencyException` if `sysctl` fails.
- `-environment`: lazily built under `_lock` from the C `environ` global via `+[NSDictionary _newWithEnvironment:]`.
- `-_executablePath`: lazily resolved under `_lock` via `sysctl( CTL_KERN, KERN_PROC, KERN_PROC_PATHNAME, getpid())`; if that fails and `argv[0]` is absolute, `argv[0]` is copied instead.
- `-hostName`: always `@"localhost"`.
- `-operatingSystem`: always `NSBSDOperatingSystem`.
- `-operatingSystemName`: always `@"FreeBSD"`.

### 3.5. `src/NSString+FreeBSD.m`

`@implementation NSString( FreeBSD)` — `@dependency NSString( OSBase);`

```objc
- (NSString *) _stringByRemovingPrivatePrefix;
- (NSUInteger) cStringLength;
- (char *) cString;
- (NSStringEncoding) _cStringEncoding;
+ (NSStringEncoding) defaultCStringEncoding;
```

- `-_stringByRemovingPrivatePrefix`: returns `self` unchanged (FreeBSD has no `/private` alias).
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

### 3.6. `src/NSTask+FreeBSD.m`

`@implementation NSTask( FreeBSD)` — `@dependency NSTask( BSD);`

- Empty override category. Process control is implemented generically in `NSTask( Posix)`; this category only establishes the `( FreeBSD)` load-order dependency. The child environment is supplied by `mulle-spawn` (as `options.env`), so the former `+_environment` that handed this platform's `environ` to fork/execve was removed rather than moved.

### 3.7. `src/MulleObjCDeps+MulleObjCFreeBSDFoundation.m`

```objc
+ (struct _mulle_objc_dependency *) dependencies;
```

- Returns the static category dependency table included from `src/reflect/objc-deps.inc`: `NSBundle( FreeBSD)`, `NSFileManager( FreeBSD)`, `NSProcessInfo( FreeBSD)`, `NSString( FreeBSD)`, `NSTask( FreeBSD)` and `_NSPathUtilityVectorTable_Loader( FreeBSD)`.

### 3.8. Generic Import Headers

- `src/generic/include.h` / `src/generic/import.h`: public central include/import headers that pull in the generated `_MulleObjCFreeBSDFoundation-include.h` / `_MulleObjCFreeBSDFoundation-import.h` files.
- `src/generic/include-private.h` / `src/generic/import-private.h`: private counterparts used by `.c`/`.m` files only.
- `src/reflect/_MulleObjCFreeBSDFoundation-export.h`: currently exports no headers.

## 4. Performance Characteristics

- Path accessors (`NSFileManager`, `NSPathUtilities`) are O(1) string operations; `-fileSystemRepresentationWithPath:` may scan the string for encoding convertibility.
- `+[NSBundle _allSharedLibraries]` is O(n) in the number of loaded ELF images and their program headers; it allocates an `NSMutableData` and one `NSString` per image.
- `NSProcessInfo` lazy accessors copy the whole argv/environ once; subsequent calls return an autoreleased cached object. Access is serialised by the inherited `_lock`. Each `-arguments` call performs one `sysctl` size probe plus one data fetch.
- The `_NSPathUtilityVectorTable` is written exactly once in `+load` and never mutated afterwards; the functions it points to are stateless, so concurrent reads are safe.
- Thread-safety: the library is not an additional locking layer. `NSProcessInfo` uses its inherited lock; `NSFileManager` and path utilities are effectively stateless. The categories do not synchronise the underlying filesystem or loader state.

## 5. AI Usage Recommendations & Patterns

- **Best practices:**
  - Use the ordinary Foundation API (`NSBundle`, `NSProcessInfo`, `NSFileManager`, `NSString`). The `( FreeBSD)` categories are installed automatically when the library is linked; there is no header to import from this project.
  - When writing platform glue that must also work on other platforms, prefer the generic `( Posix)`/`( BSD)` methods; the FreeBSD category overrides only where FreeBSD genuinely differs.
  - For process globals use `[NSProcessInfo processInfo]` rather than reading the C globals (`environ`, `sysctl`) directly.
- **Common pitfalls:**
  - Do **not** call the underscore-prefixed methods (`+_allSharedLibraries`, `-_executablePath`, `-_stringByRemovingPrivatePrefix`, `-_cStringEncoding`). They are the override surface and may be tied to a specific dependency.
  - Do not manually touch `_NSPathUtilityVectors` or instantiate `_NSPathUtilityVectorTable_Loader`; the `+load` method does the registration. On non-FreeBSD platforms the library is empty, so the POSIX behaviour stays in effect.
  - `-[NSFileManager fileSystemRepresentationWithPath:]` can return `NULL` and set `errno`; always check.
  - `-[NSProcessInfo arguments]` throws `MulleObjCThrowInternalInconsistencyException` if the kernel denies or cannot satisfy the `sysctl`; do not assume it always succeeds.
  - `NSSearchPathForDirectoriesInDomains` is a stub on FreeBSD and returns an empty array; do not rely on it for search paths.
  - `NSFullUserName` and `NSUserName` return the same value on FreeBSD (the login name).
- **Idiomatic usage:** import the dependency umbrella (`#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>` for C/Objective-C callers), link `MulleObjCFreeBSDFoundation`, and call standard Foundation methods — never re-declare the category methods.

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

### Example 3: Converting a path between Unix and Windows form

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

### Example 4: Reading standard path utilities

```objc
#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>
#include <stdio.h>

void
print_path_utilities( void)
{
   printf( "home: %s\n", [NSHomeDirectory() UTF8String]);
   printf( "tmp:  %s\n", [NSTemporaryDirectory() UTF8String]);
   printf( "user: %s\n", [NSUserName() UTF8String]);
}
```

## 7. Dependencies

- `MulleObjCBSDFoundation` (direct; marked `no-header,no-singlephase` in `.mulle/etc/sourcetree/config`, so its headers are not imported)
- `MulleObjCPosixFoundation` (direct; its umbrella `<MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>` is imported by the generated `_MulleObjCFreeBSDFoundation-import.h`)
- `execinfo` (platform-only, `only-platform-freebsd`, not built or imported)
