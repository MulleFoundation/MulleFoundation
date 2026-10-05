# MulleObjCWindowsFoundation Library Documentation for AI
<!-- Keywords: windows, objc, foundation, port, filesystem, registry, categories -->

## 1. Introduction & Purpose

- `MulleObjCWindowsFoundation` is the Windows platform back-end for the
  MulleFoundation Objective-C stack.
- It solves the problem that the generic `MulleObjCOSBaseFoundation` layer
  relies on POSIX facilities that Win32 does not provide: `gmtime` for negative
  times, `timegm`, symbolic links, `localeconv_l`, locale enumeration,
  `fork`/`exec`, and Unix-shaped filesystem paths.
- Key features:
  - A small public C API (`mulle-windows-tm.h`) that makes `struct tm`
    conversion work for pre-1970 and post-2038 dates on top of the CRT.
  - A replacement `NSLog`, `NSLogv`, `NSLogArguments` that also writes to the
    Windows debugger via `OutputDebugStringA`.
  - Objective-C categories named `( Windows)` that implement the Windows
    behaviour for `NSBundle`, `NSCalendarDate`, `NSData`, `NSDate`,
    `NSDirectoryEnumerator`, `NSFileHandle`, `NSFileManager`, `NSLocale`,
    `NSPathUtilities`, `NSPipe`, `NSProcessInfo`, `NSRunLoop`, `NSString`,
    `NSTask`, `NSTimeZone`, `NSUserDefaults` and several private classes.
  - A Windows-specific path convention: the canonical Foundation path is
    Unix-like with a lowercase drive (`/c/Users/foo`), converted to and from
    Win32 (`C:\Users\foo`) at the Win32 boundary.
- Relationship: a platform component of MulleFoundation. It depends on
  `MulleObjCOSBaseFoundation` and occupies the same slot for Windows that
  `MulleObjCBSDFoundation` / `MulleObjCPosixFoundation` occupy elsewhere.
- Build gate: `CMakeLists.txt` only compiles real code on `WIN32`; on any other
  platform it configures harmlessly as an empty `INTERFACE` library.
- Maturity: the `README.md` still reads "This is the beginning... But nothing
  works!". Treat this as an in-progress port: several methods are stubs (for
  example `NSTimeZone` only knows GMT/UTC, and `NSLocale` returns `C` on
  failure).

## 2. Key Concepts & Design Philosophy

- **Categories over the OSBase classes.** Almost all functionality is added as
  Objective-C categories on classes supplied by `MulleObjCOSBaseFoundation` /
  `MulleObjCStandardFoundation`. The `( Windows)` category overrides the
  generic implementation; overriding categories declare an explicit runtime
  dependency (`@dependency NSFileManager;`, `@dependency NSString( OSBase);`,
  etc.) so the mulle-objc runtime loads them in the right order.
- **Foundation path vs. Windows path.** The library keeps the Foundation
  convention that a path is UTF-8 in `NSString` and uses `/`, with the drive
  encoded as a leading `/c`. `-mulleWindowsFileSystemString` produces
  `C:\...` and `-mulleUnixFileSystemString` produces `/c/...`. Every call into a
  Win32 `*W` API goes through this conversion exactly once at the boundary.
- **UTF-16 at the Win32 boundary.** `NSString` is UTF-32; Win32 `W` functions
  want UTF-16. Conversion uses `mulle_utf16_t` (`mulle-utf`), with
  `-mulleUTF16String`, `-mulleInitWithUTF16Characters:length:`, and
  `_mulle_utf32_convert_to_utf16`.
- **`struct tm` helper layer.** The C functions in `mulle-windows-tm.h` shield
  callers from the Windows CRT's inability to `gmtime` negative `time_t` (it
  shifts by 400-year spans and adjusts `tm_year`) and provide a
  `struct mulle_mini_tm` bridge. They are the Windows analogue of
  `mulle_posix_tm_*` / `mulle_bsd_tm_*`.
- **Global-symbol macro.** Public globals and functions are exported through
  `MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL` /
  `MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL_VAR`, defined in `import.h`.
- **Error domain.** OS-level failures set `NSWindowsErrorDomain` through
  `MulleObjCSetWindowsErrorDomain()`; callers retrieve the pending `NSError`
  with `MulleObjCExtractError()`.

## 3. Core API & Data Structures

Visibility note: the installed public headers are listed in
`src/reflect/_MulleObjCWindowsFoundation-export.h` — `NSLog.h`,
`MulleObjCDeps+MulleObjCWindowsFoundation.h`, `NSErrorWindows.h`,
`NSFileManager+Windows.h`, `NSTask+Windows.h`. The `mulle-windows-tm.h` C API
and the date-formatter / private category headers are installed as private
headers. Most category behaviour has no header at all and is declared in the
`src/*.m` files. Signatures below are copied verbatim from the headers and the
`src/*.m` implementation files.

### 3.1. `mulle-windows-tm.h`

The public C time API. Include as `<MulleObjCWindowsFoundation/mulle-windows-tm.h>`.

```c
void           mulle_windows_tm_invalidate( struct tm *tm);
int            mulle_windows_tm_is_invalid( struct tm *tm);

struct mulle_mini_tm   mulle_windows_tm_get_mini_tm( struct tm *src);
void                   mulle_windows_tm_init_with_mini_tm( struct tm *dst, struct mulle_mini_tm src);

void    mulle_windows_tm_init_with_time( struct tm *tm, time_t time);
time_t  mulle_windows_tm_get_time( struct tm *tm);

void  mulle_windows_tm_init_with_interval1970( struct tm *tm,
                                               double timeInterval,
                                               int offset);
```

- `mulle_windows_tm_invalidate`: marks `tm` invalid by setting every field to
  `INT_MIN`.
- `mulle_windows_tm_is_invalid`: returns `1` when the invalid sentinel is
  detected, `0` otherwise.
- `mulle_windows_tm_get_mini_tm`: converts a `struct tm` to a
  `struct mulle_mini_tm` (month becomes 1-based, year is full year). A `NULL`
  source yields a zeroed struct.
- `mulle_windows_tm_init_with_mini_tm`: inverse conversion; clears `dst` first
  and sets `tm_isdst = -1`. A `NULL` `dst` is ignored.
- `mulle_windows_tm_init_with_time`: `gmtime` wrapper that first shifts negative
  or very small `time` forward by whole 400-year spans, then subtracts those
  spans from `tm_year`, so pre-1970 dates convert correctly.
- `mulle_windows_tm_get_time`: the inverse, using `_mkgmtime` plus the same
  400-year shift for pre-1970 dates.
- `mulle_windows_tm_init_with_interval1970`: fills `tm` from a
  seconds-since-1970 `double` and a GMT `offset` (in seconds).
- All functions are no-ops or return `0`/zeroed output for `NULL` arguments.

### 3.2. `NSLog.h`

```objc
MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL
void   NSLog( NSString *format, ...);

MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL
void   NSLogv( NSString *format, va_list args);

MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL
void   NSLogArguments( NSString *format, mulle_vararg_list args);
```

- All three format the message, print it to `stderr` with a trailing newline,
  and additionally emit it through `OutputDebugStringA` so it reaches a
  debugger. They run inside an `@autoreleasepool`.
- They live in this library (not OSBase) because the Windows linker cannot deal
  with future globals from OSBase.

### 3.3. `NSErrorWindows.h`

```objc
MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL
NSString   *NSWindowsErrorDomain;

void   MulleObjCSetWindowsErrorDomain( void);
```

- `NSWindowsErrorDomain`: the `NSError` domain used for Win32 failures
  (value `@"NSWindowsError"`).
- `MulleObjCSetWindowsErrorDomain`: installs that domain via
  `[NSError mulleSetErrorDomain:]`. Most Win32 calls in this library begin by
  calling it.

### 3.4. `NSFileManager+Windows.h`

```objc
@interface NSFileManager( Windows)

- (mulle_utf16_t *) fileSystemRepresentationUTF16WithPath:(NSString *) path;

- (NSString *) stringWithFileSystemRepresentationUTF16:(mulle_utf16_t *) s_utf16
                                                length:(NSUInteger) len;

@end
```

- `-fileSystemRepresentationUTF16WithPath:`: converts a Foundation path to a
  `mulleWindowsFileSystemString` and returns its UTF-16 bytes (`mulleUTF16String`).
  This is the canonical bridge used by every Win32 call in the library.
- `-stringWithFileSystemRepresentationUTF16:length:`: inverse — builds an
  `NSString` from UTF-16 and converts it back to a Unix-style Foundation path.

### 3.5. `NSTask+Windows.h`

```objc
@interface NSTask( Windows)
@end
```

- Declared but empty. The Windows launch implementation lives in
  `NSTask+Windows.m` (see 3.10).

### 3.6. `MulleObjCDeps+MulleObjCWindowsFoundation.h`

```objc
@interface MulleObjCDeps( MulleObjCWindowsFoundation)

+ (struct _mulle_objc_dependency *) dependencies;

@end
```

- Returns the category load-order dependency table (generated into
  `objc-deps.inc`). Required to be public so dependent libraries can register
  their load in `MulleObjcLoader`.

### 3.7. `_NSWindowsDateFormatter.h`

```objc
@interface _NSWindowsDateFormatter : NSDateFormatter

- (BOOL) getObjectValue:(id *) obj
              forString:(NSString *) string
                  range:(NSRange *) rangep
                  error:(NSError **) error;

- (NSString *) stringFromDate:(id) date;
- (id) dateFromString:(NSString *) s;

@end


@interface NSDateFormatter( WindowsFuture) < MulleObjCFuture>

- (size_t) _printTM:(struct tm *) tm
             buffer:(char *) buf
             length:(size_t) len
      formatUTF8String:(char *) c_format
             locale:(NSLocale *) locale;

- (NSDate *) _parseDateWithUTF8String:(char **) string
                        formatUTF8String:(char *) c_format
                               locale:(NSLocale *) locale;

@end
```

- `_NSWindowsDateFormatter` is the concrete 10.0-style formatter. It registers
  itself with `+[NSDateFormatter mulleSetClass:forFormatterBehavior:]` in
  `+load`, parses/formats a format string into a C format buffer, and uses
  `strftime` plus the `mulle_windows_tm_*` helpers for the platform work.
  Supported printf-style directives include `%Y %y %m %d %H %M %S %F %z %Z %n`
  and the `%E`/`%O` modifiers (delegated to `strftime`).
- `NSDateFormatter( WindowsFuture)`: future-interface methods that print/parse
  using an explicit `struct tm`, C format string and `NSLocale`.

### 3.8. `NSDate+Windows-Private.h` and `NSTimeZone+Windows-Private.h`

```objc
NSTimeInterval   _NSTimeIntervalNow( void);


@interface NSDate (Windows)

- (instancetype) _initWithTM:(struct tm *) tm
                 nanoseconds:(unsigned long long) nanoseconds
                    timeZone:(NSTimeZone *) tz;

@end
```

```objc
@interface NSTimeZone( Windows_PrivateFuture) < MulleObjCFuture>

- (NSTimeInterval) _timeIntervalSince1970ForTM:(struct tm *) tm;
- (NSInteger) mulleSecondsFromGMTForTimeIntervalSince1970:(NSTimeInterval) interval;

@end
```

- `NSDate( Windows)` `-_initWithTM:nanoseconds:timeZone:` converts the `tm` to a
  since-1970 interval, adds the fractional nanoseconds, subtracts the timezone
  offset, and calls `-initWithTimeIntervalSince1970:`.
- `NSTimeZone` `-mulleSecondsFromGMTForTimeIntervalSince1970:` returns the
  cached fixed offset, or `0` if the zone has no fixed offset.
- `NSTimeInterval _NSTimeIntervalNow( void)` is declared here (implementation
  comes from the generic layer).

### 3.9. `MulleObjCWindowsString+Private.h`

```objc
MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL
NSString  *NSFilePathComponentSeparator;

MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL
NSString  *NSFilePathExtensionSeparator;
```

- Declared path-separator globals for the Windows port.

### 3.10. Objective-C `( Windows)` Categories

No public headers exist for these; they are defined in the `src/*.m` files.
Signatures are copied verbatim from those files.

#### `NSString( Windows)` and `NSString( FileSystemString)`

```objc
- (NSUInteger) cStringLength;
- (char *) cString;
- (NSStringEncoding) _cStringEncoding;
+ (NSStringEncoding) defaultCStringEncoding;
- (BOOL) isAbsolutePath;

- (NSString *) mulleUnixFileSystemString;
- (NSString *) mulleWindowsFileSystemString;
```

- `-cString` / `-cStringLength`: map to the UTF-8 representation.
- The C-string encoding is derived from `GetACP()`; only CP 28591 maps to
  `NSISOLatin1StringEncoding`, everything else reports `NSUTF8StringEncoding`.
- `-isAbsolutePath` accepts a leading `/` or a drive-letter prefix (`C:`).
- `-mulleUnixFileSystemString` converts `C:\a\b` to `/c/a/b`.
- `-mulleWindowsFileSystemString` converts `/c/a/b` to `C:\a\b`.

#### `NSFileManager( Windows)`

```objc
- (int) _isValidDirectoryContentsFilenameAsCString:(char *) s;

- (char *) fileSystemRepresentationWithPath:(NSString *) path;
- (mulle_utf16_t *) fileSystemRepresentationUTF16WithPath:(NSString *) path;
- (NSString *) stringWithFileSystemRepresentation:(char *) s
                                           length:(NSUInteger) len;
- (NSString *) stringWithFileSystemRepresentationUTF16:(mulle_utf16_t *) s_utf16
                                                length:(NSUInteger) len;

- (NSString *) pathContentOfSymbolicLinkAtPath:(NSString *) path;
- (BOOL) changeCurrentDirectoryPath:(NSString *) path;
- (NSString *) currentDirectoryPath;
- (BOOL) fileExistsAtPath:(NSString *) path;
- (BOOL) fileExistsAtPath:(NSString *) path
              isDirectory:(BOOL *) isDir;
- (BOOL) isReadableFileAtPath:(NSString *) path;
- (BOOL) isWritableFileAtPath:(NSString *) path;
- (BOOL) isDeletableFileAtPath:(NSString *) path;
- (BOOL) isExecutableFileAtPath:(NSString *) path;
- (BOOL) createDirectoryAtPath:(NSString *) path
   withIntermediateDirectories:(BOOL) createIntermediates
                    attributes:(NSDictionary *) attributes
                         error:(NSError **) error;
- (NSArray *) directoryContentsAtPath:(NSString *) path;
- (NSDictionary *) fileAttributesAtPath:(NSString *) path
                           traverseLink:(BOOL) flag;
- (NSDictionary *) attributesOfItemAtPath:(NSString *) path
                                    error:(NSError **) error;
- (BOOL) setAttributes:(NSDictionary *) attributes
          ofItemAtPath:(NSString *) path
                 error:(NSError **) error;
- (NSDictionary *) fileSystemAttributesAtPath:(NSString *) path;
- (NSDictionary *) attributesOfFileSystemForPath:(NSString *) path
                                           error:(NSError **) error;
- (BOOL) createSymbolicLinkAtPath:(NSString *) path
              withDestinationPath:(NSString *) otherpath
                            error:(NSError **) error;
- (NSString *) destinationOfSymbolicLinkAtPath:(NSString *) path
                                         error:(NSError **) error;
- (BOOL) copyItemAtPath:(NSString *) fromPath
                 toPath:(NSString *) toPath
                  error:(NSError **) error;
- (BOOL) moveItemAtPath:(NSString *) srcPath
                 toPath:(NSString *) dstPath
                  error:(NSError **) error;
- (BOOL) copyPath:(NSString *) src
           toPath:(NSString *) dest
          handler:(id) handler;
- (BOOL) movePath:(NSString *) src
           toPath:(NSString *) dest
          handler:(id) handler;
```

- File tests use `GetFileAttributesW`; executability is inferred from the
  `.exe` / `.bat` / `.cmd` / `.com` extension.
- Directories are enumerated with `FindFirstFileW` / `FindNextFileW`; `.`, `..`
  and `._*` entries are filtered out.
- Attributes are filled from `GetFileInformationByHandle` / `GetFileAttributesExW`
  and include `NSFileSize`, `NSFileType`, `NSFilePosixPermissions` (approximated
  by the read-only bit), `NSFileSystemNumber` and timestamps.
- Symlinks use reparse points (`CreateSymbolicLinkW`, with the unprivileged
  flag retry) and a hand-rolled `REPARSE_DATA_BUFFER` reader.
- `-copyItemAtPath:toPath:error:` copies recursively and preserves symlinks;
  `-moveItemAtPath:toPath:error:` falls back to copy+delete when `MoveFileW`
  fails.

#### `NSPathUtilities` — `_NSPathUtilityVectorTable_Loader( Windows)`

```objc
+ (void) load;
```

- Installs `_WindowsTable` into `_NSPathUtilityVectors` (generic
  `MulleObjCOSBaseFoundation` indirection). The table provides
  `NSHomeDirectory`, per-user home, `NSSearchPathForDirectoriesInDomains`,
  root/temporary directories, and user name using `SHGetFolderPathW`,
  `GetWindowsDirectoryW`, `GetTempPathW` and `GetUserNameW`.

#### `NSData( Windows)`

```objc
+ (void) load;
- (instancetype) initWithContentsOfFile:(NSString *) path;
- (BOOL) writeToFile:(NSString *) path
          atomically:(BOOL) flag;
- (BOOL) writeToFile:(NSString *) path
          atomically:(BOOL) flag
               error:(NSError **) error;
```

- `+load` sets the page size from `mulle_mmap_get_system_pagesize()`.
- Reads/writes go through `CreateFileW` / `ReadFile` / `WriteFile`;
  atomic writes create a `~` scratch file and `MoveFileW` it into place.

#### `NSFileHandle( Windows)`

```objc
+ (instancetype) _fileHandleWithPath:(NSString *) path
                                mode:(enum _MulleObjCOpenMode) mode;
- (instancetype) initWithFileDescriptor:(int) fd
                         closeOnDealloc:(BOOL) flag;
+ (instancetype) fileHandleWithStandardInput;
+ (instancetype) fileHandleWithStandardOutput;
+ (instancetype) fileHandleWithStandardError;
- (ssize_t) _readBytes:(void *) buf
                length:(size_t) len;
- (size_t) _writeBytes:(void *) buf
                length:(size_t) len;
- (unsigned long long) _seek:(unsigned long long) offset
                        mode:(enum _MulleObjCSeekMode) mode;
- (void) synchronizeFile;
- (void) _truncate:(unsigned long long) offset;
```

- A `HANDLE` is stored in the instance's `_fd` slot; the standard handles are
  wrapped without owning them. Read/write/seek/truncate map directly to
  `ReadFile`/`WriteFile`/`SetFilePointerEx`/`SetEndOfFile`; broken-pipe errors
  set `NSFileHandleStateEOF | NSFileHandleStatePipe`.

#### `NSPipe( Windows)`

```objc
- (instancetype) init;
```

- Creates an anonymous inheritable pipe with `CreatePipe` and wraps both ends in
  `NSFileHandle`.

#### `NSProcessInfo( Windows)`

```objc
- (NSInteger) processIdentifier;
- (NSString *) hostName;
- (NSString *) operatingSystemName;
- (NSString *) operatingSystemVersionString;
- (NSUInteger) operatingSystem;
- (NSArray *) arguments;
- (NSDictionary *) environment;
- (NSString *) processName;
- (void) setProcessName:(NSString *) name;
- (void) mulleSetEnvironmentValue:(NSString *) value
                           forKey:(NSString *) key;
```

- `arguments` uses `CommandLineToArgvW`; `environment` uses
  `GetEnvironmentStringsW`; the executable path comes from
  `GetModuleFileNameW` and is converted to a Unix Foundation path.
- `operatingSystem` reports `NSWindowsNTOperatingSystem`.
- `setProcessName:` is a no-op (Windows cannot rename a running process).

#### `NSRunLoop( Windows)`

- Implements `-_initializeRunLoopMode:` and
  `-_acceptInputForRunLoopMode:beforeDate:` using `WaitForMultipleObjects` on
  the mode's handles, with timer-aware timeouts.

#### `NSBundle( Windows)`

```objc
+ (BOOL) isBundleFilesystemExtension:(NSString *) extension;
+ (NSBundle *) bundleForClass:(Class) aClass;
- (BOOL) loadBundle;
- (BOOL) unloadBundle;
- (void *) _addressOfSymbol:(NSString *) symbolName;
- (NSString *) builtInPlugInsPath;
- (NSString *) pathForAuxiliaryExecutable:(NSString *) executableName;
- (NSString *) privateFrameworksPath;
- (NSString *) sharedFrameworksPath;
- (NSString *) sharedSupportPath;
```

- Bundles are DLLs (`isBundleFilesystemExtension:` accepts `dll`). Loading uses
  `LoadLibraryW`; symbol lookup uses `GetProcAddress`; `bundleForClass:` resolves
  the module with `GetModuleHandleExW`. `+_allSharedLibraries` enumerates modules
  with `EnumProcessModules`.

#### `NSTask( Windows)`

```objc
- (void) launch;
```

- The only Windows-specific part of `NSTask`. It builds the argument vector and
  environment, converts the launch path and working directory to Windows form,
  asks for a new process group (so interrupt can target the child), marks the
  parent's ends of any `NSPipe` non-inheritable, and hands the three standard
  streams to `mulle_spawn_open_with_options` as descriptors. Lifecycle after
  launch is generic `NSTask.m`.

#### `NSLocale( Windows)`

```objc
+ (instancetype) _systemLocale;
+ (instancetype) _currentLocale;
+ (NSArray *) availableLocaleIdentifiers;
- (instancetype) initWithLocaleIdentifier:(NSString *) name;
- (void) dealloc;
- (id) _localeInfoForKey:(id) key;
```

- Uses `GetSystemDefaultLocaleName` / `GetUserDefaultLocaleName` and
  `EnumSystemLocalesEx`. Only keys that need the OS (`NSLocaleDecimalSeparator`,
  `NSLocaleGroupingSeparator`, `NSLocaleCurrencySymbol`, `NSLocaleCurrencyCode`)
  go through `GetLocaleInfoEx`; identifier-derived keys are answered by the
  generic `NSLocale`.

#### `NSTimeZone( Windows)` and `_MulleGMTTimeZone( Windows)`

```objc
- (instancetype) initWithName:(NSString *) name;
+ (NSTimeZone *) _uncachedSystemTimeZone;
+ (NSArray *) knownTimeZoneNames;
+ (NSDictionary *) abbreviationDictionary;
- (NSInteger) mulleSecondsFromGMTForTimeIntervalSince1970:(NSTimeInterval) interval;
- (NSInteger) secondsFromGMTForDate:(NSDate *) aDate;
- (NSString *) abbreviationForDate:(NSDate *) aDate;
- (BOOL) isDaylightSavingTimeForDate:(NSDate *) aDate;
```

- Only `GMT`/`UTC` are supported; all offsets are `0`. `_uncachedSystemTimeZone`
  returns the shared GMT zone. `_MulleGMTTimeZone` always reports `0`.

#### `NSCalendarDate( Windows)` and `_MulleObjCConcreteCalendarDate( Windows)`

```objc
- (instancetype) _initWithTM:(struct tm *) tm
                 nanoseconds:(unsigned long long) nanoseconds
                    timeZone:(NSTimeZone *) tz;
- (instancetype) init;
- (instancetype) initWithTimeIntervalSince1970:(NSTimeInterval) timeInterval;
- (instancetype) mulleInitWithTimeIntervalSince1970:(NSTimeInterval) timeInterval
                                           timeZone:(NSTimeZone *) tz;
- (instancetype) initWithTimeIntervalSinceReferenceDate:(NSTimeInterval) timeInterval;
- (instancetype) mulleInitWithTimeIntervalSinceReferenceDate:(NSTimeInterval) timeInterval
                                                    timeZone:(NSTimeZone *) tz;
- (instancetype) mulleInitWithDate:(NSDate *) date
                          timeZone:(NSTimeZone *) tz;
- (instancetype) initWithDate:(NSDate *) date;
- (NSDate *) date;
- (NSCalendarDate *) dateByAddingYears:(NSInteger) years
                                months:(NSInteger) months
                                  days:(NSInteger) days
                                 hours:(NSInteger) hours
                               minutes:(NSInteger) minutes
                               seconds:(NSInteger) seconds;
```

- `_MulleObjCConcreteCalendarDate( Windows)` provides the concrete storage: the
  `+newWith...` factories and `-timeIntervalSince1970` /
  `-timeIntervalSinceReferenceDate`, all backed by `mulle_windows_tm_*`.

#### `NSDirectoryEnumerator( Windows)`

```objc
- (instancetype) initWithFileManager:(NSFileManager *) manager
                            rootPath:(NSString *) root
                       inheritedPath:(NSString *) inherited;
- (NSString *) _nextEntry:(int *) is_dir;
- (void) _close;
```

- Backed by `FindFirstFileW` / `FindNextFileW`; a regular file produces an empty
  enumerator.

#### `NSData( Windows)` / `NSUserDefaults( Windows)`

```objc
- (BOOL) _loadPersistentDomain:(NSMutableDictionary *) domain;
- (BOOL) _savePersistentDomain:(NSDictionary *) domain;
```

- Defaults persist as a binary plist under
  `HKEY_CURRENT_USER\Software\<identifier>` using `RegOpenKeyExA`,
  `RegQueryValueExA`, `RegCreateKeyExA` and `RegSetValueExA`, via a temporary
  scratch file.

#### `MulleObjCDeps( MulleObjCWindowsFoundation)`

```objc
+ (struct _mulle_objc_dependency *) dependencies;
```

- See 3.6; implemented in `MulleObjCDeps+MulleObjCWindowsFoundation.m`.

### 3.11. Generic Import Headers

- `src/generic/include.h` / `src/generic/import.h`: central include/import
  headers pulling in the generated
  `_MulleObjCWindowsFoundation-include.h` / `-import.h` files. `import.h` also
  defines the `MULLE_OBJC_WINDOWS_FOUNDATION_GLOBAL*` macros and imports the
  dependency umbrella `<MulleObjCOSBaseFoundation/MulleObjCOSBaseFoundation.h>`.
- `src/generic/include-private.h` / `src/generic/import-private.h`: private
  counterparts for `.c`/`.m` files only.
- `src/reflect/_MulleObjCWindowsFoundation-export.h`: exports the five public
  headers listed at the top of section 3.

## 4. Performance Characteristics

- The `mulle_windows_tm_*` functions are O(1) in the number of fields, but
  `mulle_windows_tm_init_with_time` / `mulle_windows_tm_get_time` loop over
  400-year spans for pre-1970 dates, so they are O(number of 400-year shifts),
  normally 0 or 1.
- Filesystem operations are O(n) in the size of the file (copy/read/write) or in
  the number of directory entries (enumeration and recursive copy/move).
  `FindFirstFileW`/`FindNextFileW` enumeration is the underlying mechanism.
- Memory: file reads allocate one buffer for the whole file; `NSData`
  `initWithContentsOfFile:` uses the instance allocator. `NSPathUtilities`,
  `NSProcessInfo` and `NSUserDefaults` allocate Objective-C objects as usual.
- Thread-safety: `NSLocale` guards its lazily filled `_keyValues` with an
  `NSLock`; `NSProcessInfo` guards its cached `_arguments` / `_environment` with
  `_lock`. The C `struct tm` helpers operate on caller-owned memory and are
  reentrant. `NSUserDefaults` registry access is not additionally synchronised.
  Most Foundation classes here are not documented as thread-safe, matching their
  generic counterparts.

## 5. AI Usage Recommendations & Patterns

- **Best practices:**
  - Prefer the generic Foundation API (`NSFileManager`, `NSData`, `NSString`,
    `NSPathUtilities`, `NSProcessInfo`, `NSTask`); the `( Windows)` categories
    are installed automatically when the library is linked on Windows.
  - When crossing into Win32, always convert with
    `-fileSystemRepresentationUTF16WithPath:` /
    `-stringWithFileSystemRepresentationUTF16:length:` (or the `NSString`
    `-mulleWindowsFileSystemString` / `-mulleUnixFileSystemString` pair) rather
    than assuming a separator style.
  - Use `mulle_windows_tm_*` for `struct tm` math instead of the CRT's
    `gmtime`/`timegm`; it handles negative `time_t` correctly.
  - Start Win32 error paths with `MulleObjCSetWindowsErrorDomain()` if you want a
    populated `NSWindowsErrorDomain`.
- **Common pitfalls:**
  - Do not assume POSIX semantics: `NSTimeZone` only knows GMT/UTC,
    `NSProcessInfo` cannot rename the process, and path separators are reversed
    at the Win32 boundary.
  - Do not call underscore-prefixed methods (`-_initWithTM:...`,
    `-_acceptInputForRunLoopMode:...`, `-_localeInfoForKey:`, etc.) from
    application code; they are the platform override surface.
  - The `NSFileManager( Windows)` object-attribute dictionary approximates Unix
    metadata (`NSFilePosixPermissions`, inode counts) from Windows flags; do not
    rely on it for exact permission or inode values.
  - Do not free the `char *` / `mulle_utf16_t *` returned by the
    `fileSystemRepresentation...` methods as if it were your buffer; it belongs
    to the converted `NSString`.
  - On non-Windows platforms this library compiles to nothing; do not expect its
    categories to be present there.
- **Idiomatic usage:** import the dependency umbrella
  (`<MulleObjCOSBaseFoundation/MulleObjCOSBaseFoundation.h>` plus
  `<MulleObjCWindowsFoundation/MulleObjCWindowsFoundation.h>`) and use plain
  Foundation calls; only reach for the C `mulle-windows-tm.h` helpers or the
  UTF-16 path bridge when writing platform glue.

## 6. Integration Examples

### Example 1: Reading a file with NSData and the UTF-16 path bridge

```objc
#import <MulleObjCWindowsFoundation/MulleObjCWindowsFoundation.h>
#import <MulleObjCOSBaseFoundation/MulleObjCOSBaseFoundation.h>

void
read_file( NSString *path)
{
   NSData   *data;
   NSError  *error;

   data = [NSData dataWithContentsOfFile:path];
   if( ! data)
   {
      error = MulleObjCExtractError();
      NSLog( @"could not read %@: %@", path, error);
      return;
   }

   NSLog( @"read %lu bytes", (unsigned long) [data length]);
}
```

### Example 2: Converting between Foundation and Windows paths

```objc
#import <MulleObjCWindowsFoundation/MulleObjCWindowsFoundation.h>
#import <MulleObjCOSBaseFoundation/MulleObjCOSBaseFoundation.h>

void
print_paths( NSString *unixPath)
{
   NSFileManager   *manager;
   NSString        *windowsPath;
   NSString        *back;

   manager     = [NSFileManager defaultManager];
   windowsPath = [unixPath mulleWindowsFileSystemString];
   back        = [manager stringWithFileSystemRepresentationUTF16:
                     [manager fileSystemRepresentationUTF16WithPath:unixPath]
                                                          length:0];

   NSLog( @"unix: %@ windows: %@ back: %@", unixPath, windowsPath, back);
}
```

### Example 3: Round-tripping a date through `struct tm`

```c
#include <MulleObjCWindowsFoundation/mulle-windows-tm.h>
#include <stdio.h>
#include <time.h>

void
print_utc( double interval)
{
   struct tm   tm;
   time_t      back;

   mulle_windows_tm_init_with_interval1970( &tm, interval, 0);

   printf( "%04d-%02d-%02d %02d:%02d:%02dZ\n",
           tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
           tm.tm_hour, tm.tm_min, tm.tm_sec);

   back = mulle_windows_tm_get_time( &tm);
   printf( "round-trip: %ld\n", (long) back);
}
```

### Example 4: Launching a child process with NSTask

```objc
#import <MulleObjCWindowsFoundation/MulleObjCWindowsFoundation.h>
#import <MulleObjCOSBaseFoundation/MulleObjCOSBaseFoundation.h>

void
run_cmd( void)
{
   NSTask   *task;

   task = [[NSTask alloc] init];
   [task setLaunchPath:@"/c/Windows/System32/cmd.exe"];
   [task setArguments:@[ @"/c", @"echo hello"]];

   [task launch];
   [task waitUntilExit];

   NSLog( @"terminated with status %d", [task terminationStatus]);
   [task release];
}
```

### Example 5: Persisting user defaults through the registry

```objc
#import <MulleObjCWindowsFoundation/MulleObjCWindowsFoundation.h>
#import <MulleObjCOSBaseFoundation/MulleObjCOSBaseFoundation.h>

void
store_setting( NSString *value)
{
   NSUserDefaults   *defaults;

   defaults = [NSUserDefaults standardUserDefaults];
   [defaults setObject:value
                forKey:@"LastPath"];
   [defaults synchronize];
}
```

## 7. Dependencies

- `MulleObjCOSBaseFoundation` (direct, from `.mulle/etc/sourcetree/config` and
  `clib.json`)
- Runtime/import-level references to `MulleObjC`, `MulleObjCStandardFoundation`,
  `MulleObjCTimeFoundation`, `mulle-utf`, `mulle-allocator` and `mulle-spawn`
  are pulled in transitively through that dependency and the build system, not
  as direct sourcetree dependencies.
