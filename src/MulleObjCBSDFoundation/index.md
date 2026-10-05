# MulleObjCBSDFoundation Library Documentation for AI
<!-- Keywords: bsd, timezone, locale, date, processinfo, categories, timegm -->

## 1. Introduction & Purpose

- `MulleObjCBSDFoundation` supplies the BSD-flavoured (Darwin, FreeBSD, NetBSD, OpenBSD, DragonFly) platform back-end for the MulleFoundation Objective-C stack.
- It solves the problem that some C library behaviour used by Foundation is not portable POSIX: `timegm`, `strptime_l`, `strftime_l`, `localeconv_l`, `querylocale`, the `tm_gmtoff` / `tm_zone` fields of `struct tm`, and `getprogname` / `setprogname`.
- Key features:
  - A small public C API (`mulle-bsd-tm.h`) that mirrors the POSIX time helpers but understands BSD `struct tm` timezone fields.
  - Objective-C categories named `( BSD)` that **override** the generic `( Posix)` category implementations for `NSDate`, `NSCalendarDate`, `NSDateFormatter`, `NSLocale`, `NSProcessInfo`, `NSTimeZone` and the private `_MulleObjCConcreteCalendarDate` / `_MulleGMTTimeZone` classes.
  - The `timegm`-based implementation of `mulle_posix_tm_get_time`, which is declared by the dependency `MulleObjCPosixFoundation` but deliberately implemented here because `timegm` is a BSD extension.
- Relationship: a platform component of MulleFoundation. It depends on `MulleObjCPosixFoundation` and is layered `BSD -> Posix -> OSBase`.
- Build gate: `CMakeLists.txt` only compiles real code on `APPLE` or when the system name matches `BSD|DragonFly`; elsewhere it configures harmlessly as an empty `INTERFACE` library.

## 2. Key Concepts & Design Philosophy

- **Category override with explicit load order.** Each `( BSD)` category that replaces a `( Posix)` method declares an explicit runtime dependency, e.g. `@dependency NSDate( Posix);`, so the mulle-objc runtime loads the overriding category after the category it overrides.
- **C companion, not a rewrite.** `mulle-bsd-tm_*` functions wrap the `mulle_posix_tm_*` functions and add BSD specifics. Callers that work on `struct tm` can use either layer.
- **Invalid `struct tm` sentinel.** An invalid `tm` is detected both by the POSIX invalidation and by the BSD marker `tm->tm_gmtoff == LONG_MIN && tm->tm_zone == (void *) tm`.
- **Locale-aware C functions.** String parsing/formatting uses the reentrant `_l` variants (`strptime_l`, `strftime_l`, `localeconv_l`, `querylocale`) with an opaque `locale_t`; the library only changes `LC_CTYPE` (to UTF-8) and leaves numeric parsing in the `C` locale.
- **`timegm` owns UTC.** Because `timegm` is not portable, the UTC conversion lives in this BSD library, not in `MulleObjCPosixFoundation`.
- **No new public classes.** Only one public C header is installed (`mulle-bsd-tm.h`); all Objective-C behaviour is added through categories.

## 3. Core API & Data Structures

Visibility note: `mulle-bsd-tm.h` is the only installed public header. The `( BSD)` category methods have no public header; they are declared here (and implemented) in the `src/*.m` files and are mostly backend overrides, many with a leading underscore. Signatures below are copied verbatim from `src/mulle-bsd-tm.h` and the `src/*.m` implementation files.

### 3.1. `mulle-bsd-tm.h`

The public C time API. Include as `<MulleObjCBSDFoundation/mulle-bsd-tm.h>`.

#### `enum mulle_bsd_tm_status`

```c
enum mulle_bsd_tm_status
{
   mulle_bsd_tm_error   = -1,
   mulle_bsd_tm_no_tz   = 0,
   mulle_bsd_tm_with_tz = 1
};
```

- Return status of the parse/format helpers: `mulle_bsd_tm_error` on failure, `mulle_bsd_tm_no_tz` when no timezone information was found, `mulle_bsd_tm_with_tz` when a timezone was recovered from `now`.

#### Validation and augmentation

```c
void           mulle_bsd_tm_invalidate( struct tm *tm);
int            mulle_bsd_tm_is_invalid( struct tm *tm);
unsigned int   mulle_bsd_tm_augment( struct tm *tm,
                                     struct tm *now,
                                     enum mulle_bsd_tm_status *has_tz);
```

- `mulle_bsd_tm_invalidate`: mark `tm` invalid (also sets the BSD `tm_gmtoff` / `tm_zone` sentinel).
- `mulle_bsd_tm_is_invalid`: returns `1` if `tm` is invalid, `0` otherwise.
- `mulle_bsd_tm_augment`: fill in missing fields of `tm` from `now`; returns the number of fields augmented and writes `has_tz` with `mulle_bsd_tm_no_tz` or `mulle_bsd_tm_with_tz`.

#### Parsing

```c
enum mulle_bsd_tm_status
   mulle_bsd_tm_from_string_with_format( struct tm *tm,
                                         char **c_str_p,
                                         char *c_format,
                                         locale_t locale,
                                         int is_lenient);
```

- Parses `*c_str_p` with `strptime_l` using the given `locale_t`. `*c_str_p` is updated to the first unparsed character. Missing values are augmented from the current time. Returns the `mulle_bsd_tm_status`; `is_lenient` allows partial/zero conversions.

#### Construction

```c
void   mulle_bsd_tm_init_with_interval1970( struct tm *tm,
                                            double timeInterval,
                                            int secondsFromGMT);
```

- Initialises `tm` from a seconds-since-1970 interval and a GMT offset; sets `tm_gmtoff` to `secondsFromGMT`.

#### Inline conversion helpers

These forward to the `mulle_posix_tm_*` counterparts:

```c
static inline struct mulle_mini_tm
   mulle_bsd_tm_get_mini_tm( struct tm *src);

static inline void  mulle_bsd_tm_init_with_mini_tm( struct tm *dst,
                                                    struct mulle_mini_tm src);

static inline void    mulle_bsd_tm_init_with_time( struct tm *tm, time_t time);

static inline time_t   mulle_bsd_tm_get_time( struct tm *tm);
```

- `mulle_bsd_tm_get_mini_tm`: convert a BSD `struct tm` to `struct mulle_mini_tm`.
- `mulle_bsd_tm_init_with_mini_tm`: initialise a `struct tm` from a `struct mulle_mini_tm`.
- `mulle_bsd_tm_init_with_time` / `mulle_bsd_tm_get_time`: forward to `mulle_posix_tm_init_with_time` / `mulle_posix_tm_get_time`. The latter is the `timegm`-based UTC conversion implemented in this library (see 3.2).

### 3.2. Objective-C `( BSD)` Categories

No public headers exist for these; they are defined in the `src/*.m` files. Each is an override of the matching `( Posix)` category.

#### `NSDate( BSD)`

```objc
- (instancetype) _initWithTM:(struct tm *) tm
                 nanoseconds:(unsigned long long) nanoseconds
                    timeZone:(NSTimeZone *) tz;
```

- Overrides the POSIX initialiser; converts the BSD `struct tm` to a seconds-since-1970 interval via `timegm`, adds `nanoseconds`, subtracts the timezone offset, then calls `-initWithTimeIntervalSince1970:`.

#### `_MulleObjCConcreteCalendarDate( BSD)`

```objc
+ (instancetype) newWithTimeIntervalSince1970:(NSTimeInterval) timeInterval
                                     timeZone:(NSTimeZone *) timeZone;

+ (instancetype) newWithTimeIntervalSince1970:(NSTimeInterval) timeInterval;

- (NSTimeInterval) timeIntervalSince1970;
```

- Factory methods build the private calendar-date object for a given interval and timezone (the 1-argument variant defaults to `[NSTimeZone defaultTimeZone]`, the 2-argument variant defaults a `nil` timezone to GMT).
- `-timeIntervalSince1970` converts the stored mini-`tm` back with `timegm` and applies the timezone offset.

#### `NSCalendarDate( BSD)`

```objc
- (instancetype) _initWithTM:(struct tm *) tm
                 nanoseconds:(unsigned long long) nanoseconds
                    timeZone:(NSTimeZone *) tz;

- (NSCalendarDate *) dateByAddingYears:(NSInteger) years
                                months:(NSInteger) months
                                  days:(NSInteger) days
                                 hours:(NSInteger) hours
                               minutes:(NSInteger) minutes
                               seconds:(NSInteger) seconds;
```

- `_initWithTM:...` converts a BSD `struct tm` to a mini-`tm` and calls the private `-mulleInitWithMiniTM:timeZone:`.
- `-dateByAddingYears:...` adds calendar units to the receiver's mini-`tm` and returns a new autoreleased date in the receiver's timezone.

#### `NSDateFormatter( BSD)`

```objc
- (size_t) _printTM:(struct tm *) tm
             buffer:(char *) buf
             length:(size_t) len
      formatUTF8String:(char *) c_format
             locale:(NSLocale *) locale;
```

- Overrides formatting to use `strftime_l` with the locale's immutable `locale_t` (falling back to plain `strftime` when unavailable).

#### `NSLocale( BSD)`

```objc
+ (NSString *) systemLocalePath;
+ (instancetype) _systemLocale;
+ (instancetype) _currentLocale;
- (id) _localeInfoForKey:(id) key;
```

- `+systemLocalePath`: returns the BSD system locale directory (`@"/usr/share/locale"`).
- `+_systemLocale`: the global (`LC_GLOBAL_LOCALE`) system locale.
- `+_currentLocale`: the current thread/process locale (`querylocale` with a `NULL` base).
- `-_localeInfoForKey:`: answers only keys needing a `querylocale()` / `localeconv()` lookup (language, conversion values, identifier); the remaining identifier-derived keys are answered platform-independently by `NSLocale` itself.

#### `NSProcessInfo( BSD)`

```objc
- (NSString *) processName;
- (void) setProcessName:(NSString *) name;
```

- `-processName`: wraps `getprogname()`.
- `-setProcessName:`: wraps `setprogname()` with a deliberately persistent (`strdup`) buffer, since the man page states the string must outlive the process name.

#### `NSTask( BSD)`

- Empty override category. Process control is implemented generically in `NSTask( Posix)`; this category only exists to establish the `( BSD)` load-order dependency.

#### `NSTimeZone( BSD)`

```objc
- (NSTimeInterval) _timeIntervalSince1970ForTM:(struct tm *) tm;
```

- Overrides the POSIX conversion using the compiled timezone data (the dependency's `mulle_get_timeinterval_for_tm`), throwing `MulleObjCThrowInvalidArgumentException` when the time cannot be converted.

#### `_MulleGMTTimeZone( BSD)`

```objc
- (NSTimeInterval) _timeIntervalSince1970ForTM:(struct tm *) tm;
```

- The GMT timezone maps `struct tm` to an interval with `timegm` directly.

#### `MulleObjCDeps( MulleObjCBSDFoundation)`

```objc
+ (struct _mulle_objc_dependency *) dependencies;
```

- Exposes the category load-order dependencies (`NSDate( BSD)` after `NSDate( Posix)`, etc.) to the mulle-objc runtime.

### 3.3. Generic Import Headers

- `src/generic/include.h` / `src/generic/import.h`: public central include/import headers that pull in the generated `_MulleObjCBSDFoundation-include.h` / `_MulleObjCBSDFoundation-import.h` files. `import.h` adds the dependency umbrella `<MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>`.
- `src/generic/include-private.h` / `src/generic/import-private.h`: private counterparts used by `.c`/`.m` files only.
- `src/reflect/_MulleObjCBSDFoundation-export.h`: currently exports no headers.
- `src/reflect/_MulleObjCBSDFoundation-provide.h`: includes `mulle-bsd-tm.h`.

## 4. Performance Characteristics

- `mulle_bsd_tm_init_with_*` and `mulle_bsd_tm_get_*` are O(1); they only copy/convert fields.
- `mulle_bsd_tm_from_string_with_format` is O(n) in the length of the parsed string; `_printTM:...` is O(n) in the length of the formatted output.
- `timegm` is O(1) relative to the number of calendar fields, but can be slower than the reverse (local time) conversion.
- Memory: the API works on caller-provided `struct tm`; the library itself allocates only for `-setProcessName:` (an intentional, once-per-call leak) and for returned Objective-C objects.
- Thread-safety: the C `mulle_bsd_tm_*` functions are reentrant and stateless (they operate on a caller-owned `struct tm`), so they are safe to call concurrently. `NSLocale`'s `locale_t` is created once and immutable, so it can be shared across threads. `-setProcessName:` mutates process-global state and is not synchronised against concurrent `getprogname`/`setprogname` use. The `( BSD)` categories themselves are not an additional synchronisation layer.

## 5. AI Usage Recommendations & Patterns

- Best practices:
  - Prefer calling the public Foundation API (`NSDate`, `NSTimeZone`, `NSLocale`, `NSProcessInfo`); the `( BSD)` categories are installed automatically when the library is linked on a BSD/Darwin platform.
  - When writing platform glue, prefer the `mulle_bsd_tm_*` C functions over raw `timegm`/`strptime_l`, since they maintain the library's invalid-`tm` sentinel and augmentation semantics.
  - Always `#include <MulleObjCBSDFoundation/mulle-bsd-tm.h>` (or the project's `import.h`) rather than declaring the C functions yourself.
  - Use the `mulle_bsd_tm_status` return value of `mulle_bsd_tm_from_string_with_format` to distinguish "no timezone found" from "parse error".
- Common pitfalls:
  - Do not call the underscore-prefixed methods (`-_initWithTM:...`, `-_printTM:...`, `-_timeIntervalSince1970ForTM:`, `-_localeInfoForKey:`) from application code; they are the platform override surface.
  - Do not assume the library does anything on non-BSD platforms. The CMake gate makes it an empty interface library there; the `( Posix)` behaviour remains in effect.
  - Do not free or modify the string returned by `-processName`; treat it as autoreleased. `-setProcessName:` copies and intentionally leaks the backing C string.
  - The `locale_t` argument to `mulle_bsd_tm_from_string_with_format` is required for `strptime_l`; pass `LC_GLOBAL_LOCALE` (from `<locale.h>`) if no `NSLocale` is available.
  - `timegm` normalises out-of-range fields; do not rely on `mulle_bsd_tm_get_time` to reject invalid dates.
- Idiomatic usage: import the dependency umbrella and, if C helpers are needed, the public C header; never re-declare the category methods.

## 6. Integration Examples

### Example 1: Converting a seconds-since-1970 interval to UTC and back

```c
#include <MulleObjCBSDFoundation/mulle-bsd-tm.h>
#include <stdio.h>
#include <time.h>

void
print_utc( double interval)
{
   struct tm   tm;
   time_t      back;

   mulle_bsd_tm_init_with_interval1970( &tm, interval, 0);

   printf( "%04d-%02d-%02d %02d:%02d:%02dZ\n",
           tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
           tm.tm_hour, tm.tm_min, tm.tm_sec);

   back = mulle_bsd_tm_get_time( &tm);
   printf( "round-trip: %ld\n", (long) back);
}
```

### Example 2: Lenient parsing of a date string

```c
#include <MulleObjCBSDFoundation/mulle-bsd-tm.h>
#include <locale.h>
#include <stdio.h>
#include <time.h>

void
parse_date( char *s)
{
   struct tm                  tm;
   char                      *rest;
   enum mulle_bsd_tm_status   status;

   rest   = s;
   status = mulle_bsd_tm_from_string_with_format( &tm,
                                                  &rest,
                                                  "%Y-%m-%d %H:%M:%S",
                                                  LC_GLOBAL_LOCALE,
                                                  1);
   if( status == mulle_bsd_tm_error)
   {
      printf( "parse failed\n");
      return;
   }

   printf( "parsed, rest: \"%s\", tz present: %d\n",
           rest, status == mulle_bsd_tm_with_tz);
}
```

### Example 3: Reading and setting the process name via the category

```objc
#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>
#import <MulleObjCBSDFoundation/mulle-bsd-tm.h>
#include <stdio.h>

void
rename_process( void)
{
   NSProcessInfo   *info;
   NSString        *name;

   info = [NSProcessInfo processInfo];
   name = [info processName];
   printf( "current: %s\n", [name UTF8String]);

   [info setProcessName:@"my-tool"];
}
```

### Example 4: Querying the BSD system locale

```objc
#import <MulleObjCPosixFoundation/MulleObjCPosixFoundation.h>
#include <stdio.h>

void
print_system_locale( void)
{
   NSLocale   *locale;
   NSString   *identifier;

   locale     = [NSLocale systemLocale];
   identifier = [locale localeIdentifier];

   printf( "locale dir: %s\n", [[NSLocale systemLocalePath] UTF8String]);
   printf( "identifier: %s\n", [identifier UTF8String]);
}
```

## 7. Dependencies

- `MulleObjCPosixFoundation` (direct, from `.mulle/etc/sourcetree/config` and `clib.json`)
