# MulleObjCArchiverFoundation Library Documentation for AI
<!-- Keywords: serialization, archiver, unarchiver, coder, keyed, binary, buffer -->
## 1. Introduction & Purpose

MulleObjCArchiverFoundation provides binary object serialization ("archiving")
and deserialization ("unarchiving") for mulle-objc. It implements the
**NSCoding protocol API**: an object encodes itself by sending
`encodeWithCoder:` to a coder, and decodes itself with `initWithCoder:`.

It solves the problem of storing or transporting object graphs (including
cyclic references and shared sub-objects) as compact binary data, e.g. for
caches or files. Two archive styles are supported:

- **Unkeyed (sequential)** archiving, via `NSArchiver` / `NSUnarchiver`. Values
  are encoded in a fixed order and decoded in the same order. This mirrors the
  classic `NSCoder` API.
- **Keyed archiving**, via `NSKeyedArchiver` / `NSKeyedUnarchiver`. Every value
  is stored under a `NSString *` key, which is more forgiving when the object
  schema evolves (decoders can query `containsValueForKey:`).

The project is a foundational component of the `MulleFoundation` library set.
It depends on `MulleObjCStandardFoundation`. C-level buffer helpers
(`mulle-buffer-archiver.h`) build on the `mulle-buffer` C library.

## 2. Key Concepts & Design Philosophy

- **NSCoding is user implemented**: A class that wants to be archived conforms
  to the `NSCoding` protocol (defined in `MulleObjCStandardFoundation`) by
  implementing `- (void) encodeWithCoder:(NSCoder *) coder` and
  `- (id) initWithCoder:(NSCoder *) decoder`. The coder classes here supply the
  primitives (`encodeInt:forKey:`, `decodeObjectForKey:`, etc.) that those
  methods call.
- **A coder is either keyed or unkeyed, not both**: `NSCoder` documents that
  "Your NSCoder object will either support keyed archiving or regular archiving
  but not both in this Foundation." `NSArchiver`/`NSUnarchiver` are the unkeyed
  pair; `NSKeyedArchiver`/`NSKeyedUnarchiver` are the keyed pair.
- **Shared/cyclic reference handling**: Every distinct object is assigned an
  integer handle when first encoded (`MulleObjCPointerHandleMap`). Later
  references encode just the handle, so a shared or cyclic object graph is
  encoded exactly once. Identical byte blobs (`struct blob`) are deduplicated
  through a blob table keyed by hashed content.
- **Backwards/forwards compatible class names**: Both archiver and unarchiver
  keep a "class name substitution" map. `encodeClassName:intoClassName:` maps a
  runtime class name to an archive name; `decodeClassName:asClassName:`
  reverses this on read. The archive stores class versions and an ivar-hash for
  pedantic consistency checks.
- **Archive layout**: `encodeRootObject:` writes a 16-byte magic
  (`"mulle-obj-stream"` for unkeyed, `"mulle-key-stream"` for keyed), the
  `systemVersion` integer, the data section (`"**dta**"`), then the object
  (`"**obj**"`), class (`"**cls**"`), selector (`"**sel**"`), and blob
  (`"**blb**"`) tables, and finally a table-offsets trailer (`"**off**"`).
  The unarchiver reads the tables in reverse order by seeking to the trailer
  offsets.
- **Binary primitives**: integers are stored as a variable-length 7-bit
  continuation encoding (`mulle_buffer_add_integer` /
  `mulle_buffer_next_integer`); `long long`, `float`, `double` (and optionally
  `long double`) are stored big-endian. `C` primitive types are encoded without
  a type tag; the type descriptor comes from the caller's `@encode( ... )`.

## 3. Core API & Data Structures

All signatures below are copied verbatim from the headers in `src/`.

### 3.1. `src/MulleObjCArchiverFoundation.h`

- Defines the library version:

```c
#define MULLE_OBJC_ARCHIVER_FOUNDATION_VERSION   ((0UL << 20) | (22 << 8) | 6)
```

- Imports the public header, the reflect-generated export header and an
  optional version check. This is the umbrella header users import via
  `<MulleObjCArchiverFoundation/MulleObjCArchiverFoundation.h>`.

### 3.2. `src/NSCoder.h`

#### `@interface NSCoder : NSObject`

The abstract base class for all coders/archivers. Coders are refined by
protocol categories below; subclasses (e.g. `MulleObjCArchiver`,
`MulleObjCUnarchiver`) pick up whole sets of methods.

- **Purpose:** Provide the common coder interface and default method bodies for
  unkeyed archiving/unarchiving.
- **Core functions:**
  - `- (BOOL) allowsKeyedCoding;` — returns `YES` for keyed coders. Default
    (`NSCoder`) implementation returns `NO`.
  - `- (NSInteger) systemVersion;` — returns `MULLE_OBJC_VERSION`; the version
    written into the archive header and verified on decode.

##### `@interface NSCoder ( Common)`
  - `- (NSInteger) versionForClassName:(NSString *) className;` — declared for
    querying a class' version for a given archive class name. (No implementation
    in this Foundation at HEAD; do not rely on it.)

##### `@interface NSCoder ( UnkeyedArchivingUnarchiving)` — "future support"
  - `- (void) encodeDecodeValueOfObjCType:(char *) type at:(void *) addr;`
  - `- (void) encodeDecodeObject:(id) obj;`
  - `- (void) encodeDecodeConditionalObject:(id) obj;`
  - `- (void) encodeDecodeValuesOfObjCTypes:(char *) types, ...;`

##### `@interface NSCoder ( UnkeyedArchiving)`
  - `- (void) encodeValueOfObjCType:(char *) type at:(void *) addr;`
  - `- (void) encodeObject:(id) obj;`
  - `- (void) encodeRootObject:(id) obj;`
  - `- (void) encodeBycopyObject:(id) obj;`
  - `- (void) encodeByrefObject:(id) obj;`
  - `- (void) encodeConditionalObject:(id) obj;`
  - `- (void) encodeValuesOfObjCTypes:(char *) types, ...;`
  - `- (void) encodeArrayOfObjCType:(char *) type count:(NSUInteger) count at:(void *) array;`
  - `- (void) encodeBytes:(void *) bytes length:(NSUInteger) length;`
  - `- (void) encodePropertyList:(id) aPropertyList;`

##### `@interface NSCoder ( UnkeyedUnarchiving)`
  - `- (void) decodeValueOfObjCType:(char *) type at:(void *)data;`
  - `- (id) decodeObject;`
  - `- (void) decodeValuesOfObjCTypes:(char *) types, ...;`
  - `- (void) decodeArrayOfObjCType:(char *) itemType count:(NSUInteger) count at:(void *) array;`
  - `- (void *) decodeBytesWithReturnedLength:(NSUInteger *) len_p;` — returns
    memory allocated via `MulleObjCInstanceAllocateMemory`.
  - `- (id) decodePropertyList;`

##### `@interface NSCoder ( KeyedArchiving)`
  - `- (void) encodeObject:(id)obj forKey:(NSString *) key;`
  - `- (void) encodeConditionalObject:(id)obj forKey:(NSString *) key;`
  - `- (void) encodeBool:(BOOL) value forKey:(NSString *) key;`
  - `- (void) encodeInt:(int)value forKey:(NSString *) key;`
  - `- (void) encodeInt32:(int32_t)value forKey:(NSString *) key;`
  - `- (void) encodeInt64:(int64_t)value forKey:(NSString *) key;`
  - `- (void) encodeFloat:(float)value forKey:(NSString *) key;`
  - `- (void) encodeDouble:(double)value forKey:(NSString *) key;`
  - `- (void) encodeBytes:(void *) bytes length:(NSUInteger) len forKey:(NSString *) key;`
  - `- (void) encodeInteger:(NSInteger)value forKey:(NSString *) key;` — declared,
    no implementation at HEAD; use `encodeInt:forKey:`.

##### `@interface NSCoder ( KeyedUnarchiving)`
  - `- (BOOL) containsValueForKey:(NSString *) key;`
  - `- (id) decodeObjectForKey:(NSString *) key;`
  - `- (BOOL) decodeBoolForKey:(NSString *) key;`
  - `- (int) decodeIntForKey:(NSString *) key;`
  - `- (int32_t) decodeInt32ForKey:(NSString *) key;`
  - `- (int64_t) decodeInt64ForKey:(NSString *) key;`
  - `- (float) decodeFloatForKey:(NSString *) key;`
  - `- (double) decodeDoubleForKey:(NSString *) key;`
  - `- (void *) decodeBytesForKey:(NSString *) key returnedLength:(NSUInteger *) len_p;` — the
    returned byte pointer is owned by the unarchiver (see 3.8).
  - `- (NSInteger) decodeIntegerForKey:(NSString *) key;` — declared, no
    implementation at HEAD; use `decodeIntForKey:`.

##### Mixins (default implementations for subclasses)

`@mixin MulleObjCUnkeyedArchiver < NSObject` supplies default bodies for
`encodeObject:`, `encodePropertyList:`, `encodeBycopyObject:`,
`encodeByrefObject:`, `encodeConditionalObject:`, `encodeArrayOfObjCType:...`,
`encodeBytes:length:`, `encodeValuesOfObjCTypes:...`. The `@required` method a
subclass must implement is:

  - `- (void) encodeValueOfObjCType:(char *) type at:(void *) data;`

`@mixin MulleObjCUnkeyedUnarchiver < NSObject` supplies default bodies for
`decodeObject`, `decodePropertyList`, `decodeArrayOfObjCType:...`,
`decodeValuesOfObjCTypes:...`. The `@required` method is:

  - `- (void) decodeValueOfObjCType:(char *) type at:(void *) data;`

### 3.3. `src/MulleObjCArchiver.h`

#### `struct MulleObjCPointerHandleMap`
- **Purpose:** pairs a `struct mulle_map` (object pointer -> handle) with a
  `struct mulle_pointerarray` (ordered handle -> object). Used internally by the
  archiver for object, class, selector and blob tables.
- **Key Fields:**
  - `struct mulle_map map;`
  - `struct mulle_pointerarray array;`

#### Globals (declared `MULLE_OBJC_ARCHIVER_FOUNDATION_GLOBAL`)
- `NSString *NSInconsistentArchiveException;` — raised when an archive is
  structurally inconsistent, damaged, or operations are misused (e.g., unknown
  key, `encodeObject:` on a keyed archiver, failed version check).
- `NSString *NSInvalidArchiveOperationException;` — declared here for invalid
  archive operations.

#### `@interface MulleObjCArchiver : NSCoder`

The actual encoding engine. Holds a growable `struct mulle_buffer _buffer`, the
handle maps, class/object substitution maps and an optional copy-to
`NSMutableData`. It "supplies the mechanics but actually does not do the NSCoder
protocol stuff except `encodeRootObject`".

- **Lifecycle Functions:**
  - `- (instancetype) initForWritingWithMutableData:(NSMutableData *) data;` —
    initialize for writing, copying the finished archive into `data` when
    encoding completes. Raises `NSInvalidArgumentException` if `data` is nil.
  - `- (instancetype) init` (from `.m`) — plain init: initializes the buffer
    and maps. Subclasses (`NSArchiver`, `NSKeyedArchiver`) usually do not need
    more than this.
- **Core Operations:**
  - `+ (NSData *) archivedDataWithRootObject:(id) rootObject;` — convenience
    class factory: `[[self new] autorelease]`, then `encodeRootObject:`, then
    `archiverData`.
  - `- (void) encodeRootObject:(id) rootObject;` — resets the buffer, writes
    the header and data section, encodes the whole object graph plus the
    object/class/selector/blob tables and the `"**off**"` trailer. Raises
    `NSInconsistentArchiveException` on overflow.
  - `- (NSString *) classNameEncodedForTrueClassName:(NSString *) trueName;` —
    returns the archive class name previously registered for `trueName`
    (nil if none).
  - `- (void) encodeClassName:(NSString *) runtime intoClassName:(NSString *) archive;` —
    register a class-name substitution used when writing the class table.
  - `- (void) replaceObject:(id) original withObject:(id) replacement;` —
    register an object substitution: references to `original` are encoded as
    `replacement` thereafter.
- **Inspection/Result:**
  - `- (NSMutableData *) archiverData;` — the encoded data. Returns `_copyTo` if
    `initForWritingWithMutableData:` was used, else a new `NSMutableData` copy;
    nil if the buffer is empty.

### 3.4. `src/MulleObjCUnarchiver.h`

#### `@interface MulleObjCUnarchiver : NSCoder`

The decoding engine. Reads the archive in-place from an `NSData` (backed by a
static/inflexible `struct mulle_buffer`), allocates instances of the archived
classes, and drives their `initWithCoder:`.

- **Lifecycle Functions:**
  - `- (instancetype) initForReadingWithData:(NSData *)data;` — reads and
    validates the header, seeks through the `"**off**"` trailer, and parses the
    blob/selector/class/object tables. Returns nil if any validation fails.
  - `+ (id) unarchiveObjectWithData:(NSData *) data;` — convenience class
    factory: `initForReadingWithData:`, then `decodeObject`, returning the
    decoded root object (autoreleased).
- **Inspection Functions:**
  - `- (BOOL) atEnd;` — true when the underlying buffer is fully consumed.
- **Core Operations:**
  - `- (id) decodeObject;` — decodes the next (or, on first call, the root)
    object from the data section. Returns an autoreleased object.
  - `- (void) decodeClassName:(NSString *) inArchiveName asClassName:(NSString *) trueName;` —
    register a class-name substitution used when resolving classes from the
    class table.
  - `- (NSString *) classNameDecodedForArchiveClassName:(NSString *) inArchiveName;` —
    return the substituted runtime class name for an archive class name.
  - `- (void) replaceObject:(id) object withObject:(id) newObject;` — register
    an object substitution used while decoding.
- **Internals (underscore-prefixed, use with care):**
  - `- (void *) _decodeBytesWithReturnedLength:(NSUInteger *) len_p;`

### 3.5. `src/NSArchiver.h`

```objc
@interface NSArchiver : MulleObjCArchiver < MulleObjCUnkeyedArchiver>
```

The unkeyed (sequential) archiver. Declares nothing itself: the
`MulleObjCUnkeyedArchiver` mixin and `NSCoder` defaults supply the unkeyed
encoder methods. Use `archivedDataWithRootObject:` to encode.

### 3.6. `src/NSUnarchiver.h`

```objc
@interface NSUnarchiver : MulleObjCUnarchiver < MulleObjCUnkeyedUnarchiver>
```

The unkeyed (sequential) unarchiver. Implements the required unkeyed decoder
methods:

- `- (void) decodeValueOfObjCType:(char *) type at:(void *) p;`
- `- (void *) decodeBytesWithReturnedLength:(NSUInteger *) len_p;`

### 3.7. `src/NSKeyedArchiver.h`

```objc
@interface NSKeyedArchiver : MulleObjCArchiver
@end
```

The keyed archiver. Writes the `"mulle-key-stream"` magic. It implements the
`NSCoder (KeyedArchiving)` methods on top of a generic
`- (void) encodeValueOfObjCType:(char *) type at:(void *) p key:(NSString *) key`
which prefixes the key and the length of the encoded value. Calling unkeyed
`encodeObject:` after the root is encoded raises
`NSInconsistentArchiveException` ("don't use encodeObject: with
NSKeyedArchiver"). Keys must not be nil.

### 3.8. `src/NSKeyedUnarchiver.h`

```objc
@interface NSKeyedUnarchiver : MulleObjCUnarchiver
{
   NSMapTable   *_scope;
}
@end
```

The keyed unarchiver. On `initForReadingWithData:` it scans the data section of
the root object and stores each key's byte offset into the `_scope` map. The
`NSCoder (KeyedUnarchiving)` methods then seek to the key's offset on demand:

- `- (BOOL) containsValueForKey:(NSString *) key;`
- `- (id) decodeObjectForKey:(NSString *) key;` — returns an autoreleased
  object; raises `NSInconsistentArchiveException` for unknown keys.
- `- (BOOL) decodeBoolForKey:(NSString *) key;`
- `- (int) decodeIntForKey:(NSString *) key;`
- `- (int32_t) decodeInt32ForKey:(NSString *) key;`
- `- (int64_t) decodeInt64ForKey:(NSString *) key;`
- `- (float) decodeFloatForKey:(NSString *) key;`
- `- (double) decodeDoubleForKey:(NSString *) key;`
- `- (void *) decodeBytesForKey:(NSString *) key returnedLength:(NSUInteger *) len_p;` —
  the returned pointer is owned by the `NSKeyedUnarchiver` (blob table storage);
  do not free it, do not use it after the unarchiver is deallocated.

Unkeyed `decodeObject` is only legal before the keys are scanned (i.e., it
decodes the root object); afterwards it raises
`NSInconsistentArchiveException`.

### 3.9. `src/NSArchiver+OSBase.h`

#### `@interface NSArchiver (OSBase)`

- `+ (BOOL) archiveRootObject:(NSObject *) rootObject toFile:(NSString *) path;` —
  convenience: encode `rootObject` and write the archive atomically to `path`.
  Returns `YES` on success.

### 3.10. `src/NSObject+NSCoder.h`

#### `@interface NSObject( NSCoder)`

- `- (Class) classForCoder;` — returns the class recorded in the archive's
  object table. Default implementation returns `[self class]`. Override to
  archive an object under a different class (e.g. a proxy class).

### 3.11. `src/mulle-buffer-archiver.h`

C-level inline helpers that extend `struct mulle_buffer` (from `mulle-buffer`)
for archiving. They are the primitive writers/readers used by the coder
implementations and are public (`#include
<MulleObjCArchiverFoundation/mulle-buffer-archiver.h>`).

- **Reading:**
  - `static inline uint64_t mulle_buffer_next_integer( struct mulle_buffer *buffer)` —
    7-bit continuation variable-length integer.
  - `static inline long long mulle_buffer_next_long_long( struct mulle_buffer *buffer)` —
    big-endian 64-bit.
  - `static inline float mulle_buffer_next_float( struct mulle_buffer *buffer)`
  - `static inline double mulle_buffer_next_double( struct mulle_buffer *buffer)`
  - `static inline long double mulle_buffer_next_long_double( struct mulle_buffer *buffer)`
    (only `#ifdef _C_LNG_DBL`)
- **Writing:**
  - `static inline void mulle_buffer_add_integer( struct mulle_buffer *buffer, uint64_t v)` —
    emits the minimal variable-length encoding (1..10 bytes).
  - `static inline void mulle_buffer_add_integer_N( struct mulle_buffer *buffer, <type> v)`
    for `N` in { 7, 14, 21, 28, 35, 42, 49, 56, 63, 64 } — fixed-width
    variable-length variants.
  - `static inline void mulle_buffer_add_long_long( struct mulle_buffer *buffer, long long v)`
  - `static inline void mulle_buffer_add_float( struct mulle_buffer *buffer, float v)`
  - `static inline void mulle_buffer_add_double( struct mulle_buffer *buffer, double v)`
  - `static inline void mulle_buffer_add_long_double( struct mulle_buffer *buffer, long double v)`
    (only `#ifdef _C_LNG_DBL`)

### 3.12. `src/MulleObjCArchiver-Private.h` (private)

Internal shared helpers, imported by implementations only:

- `struct blob { size_t _length; void *_storage; }` — a byte range; used for
  blob-table deduplication.
- `static inline uintptr_t blob_hash(const struct mulle_container_keycallback *ignore, const struct blob *blob)` — hashes at most the first 256 bytes.
- `static inline int blob_is_equal(const struct mulle_container_keycallback *ignore, const struct blob *a, const struct blob *b)`
- `static inline char *blob_describe(const struct mulle_container_keycallback *ignore, void *_blob, struct mulle_allocator **p_allocator)`
- `MulleObjCPointerHandleMapInit/Done/GetOrAdd` — handle-map helpers.

Do not use these from application code.

## 4. Performance Characteristics

- **Encoding/decoding is linear** in the size of the object graph / archive:
  each object is encoded once (O(1) map ops per object for handle assignment),
  and each value is appended/read with amortized O(1) buffer
  grow/seek-default operations.
- **Blob deduplication:** byte strings are hashed (first 256 bytes) and stored
  once per unique content. Hash cost is bounded by the first 256 bytes;
  large identical blobs benefit from dedup, dissimilar blobs pay only a
  bounded hash.
- **Integer coding:** variable-length 7-bit continuation — 1 byte for values
  < 0x7F, up to 10 bytes for full 64-bit. Compact for small values; not optimal
  for large signed/negative values (comment: "not efficient for negative
  numbers").
- **Floating point / 64-bit integers:** fixed-size big-endian IEEE — fast, but
  not compact.
- **Memory:** the archiver appends into a growable `mulle_buffer`; the
  unarchiver reads the `NSData` in place (no copy) and allocates one instance
  per archived object, retained until the unarchiver is deallocated.
- **Thread safety:** not thread-safe. Coder instances hold mutable seek
  position, tables and maps. Use one archiver per thread, or use the class
  factory methods which create a fresh instance. The C helpers operate on
  caller-owned buffers and are as thread-safe as the buffer's owner.

## 5. AI Usage Recommendations & Patterns

### Best Practices

- **Let objects implement NSCoding.** A class stored in an archive must
  conform to `NSCoding` (protocol from `MulleObjCStandardFoundation`):
  implement `- (void) encodeWithCoder:(NSCoder *) coder` and
  `- (id) initWithCoder:(NSCoder *) decoder`. `NSParameterAssert`s in
  `_appendClass` require it.
- **Prefer the class factories.** `[NSKeyedArchiver archivedDataWithRootObject:x]`
  and `[NSKeyedUnarchiver unarchiveObjectWithData:data]` (or the unkeyed
  equivalents) manage the whole lifecycle and return autoreleased results.
- **Choose keyed vs. unkeyed deliberately.** Use keyed
  (`NSKeyedArchiver`/`NSKeyedUnarchiver`) when field sets may evolve or when
  each value should be addressable by name; use unkeyed
  (`NSArchiver`/`NSUnarchiver`) for simple sequential objects (classic
  `NSCoder` style).
- **Use exact-width integer methods** (`encodeInt32:forKey:` /
  `decodeInt32ForKey:` etc.) for portable data; `encodeInt:forKey:` encodes an
  `int` with platform-dependent width.
- **Register class-name substitutions** with `encodeClassName:intoClassName:`
  (archiver) / `decodeClassName:asClassName:` (unarchiver) to keep old archives
  loadable when class names change.
- **Guard optional keyed fields** with `containsValueForKey:` before decoding.
- **Copy what you need from `decodeBytesForKey:`** — the returned pointer is
  owned by the unarchiver. `decodeBytesWithReturnedLength:` (unkeyed) returns
  fresh instance-allocated memory.
- **In `initWithCoder:`** call `[self init]` first, decode fields, and return
  `self` (or `[self init]`). Always return a non-nil object; the unarchiver
  raises `NSInconsistentArchiveException` on nil.

### Common Pitfalls

- **Mixing keyed and unkeyed APIs on one coder.** A coder supports only one
  style. Calling unkeyed `encodeObject:` on `NSKeyedArchiver` (after the root)
  or `decodeObject` on a keyed unarchiver raises
  `NSInconsistentArchiveException`.
- **Wrong signatures / types.** The keyed methods take `forKey:` as the last
  parameter segment (e.g. `encodeInt:_i forKey:@"i"]`); the unkeyed ones do
  not. Decoding with a mismatched type misreads the stream.
- **Forgetting the NUL terminator when encoding C strings.** A `char *` is
  encoded as a blob including its terminating zero — encode with
  `length:strlen(s) + 1`.
- **`initWithCoder:` returning a different object.** Only classes implementing
  `-decodeWithCoder:` may change `self`; the unarchiver enforces this for
  regular objects.
- **Keeping `decodeBytesForKey:` pointers.** They point into unarchiver-owned
  blob storage; do not free or retain them past the unarchiver's lifetime.
- **Version/class drift.** The unarchiver checks `systemVersion`, class
  versions (`[cls version] < version` fails) and ivar hashes; a mismatch fails
  decoding. Old archives should be decoded with a compatible runtime or with
  class-name substitutions in place.
- **Untrusted archives.** Decoding instantiates arbitrary archived classes and
  calls their `initWithCoder:`. Treat archives as trusted.

### Idiomatic Usage

- Encode: build object graph -> call
  `[<ArchiverClass> archivedDataWithRootObject:root]` -> `NSData` in hand.
- Decode: `<Class> *obj = [<UnarchiverClass> unarchiveObjectWithData:data]`
  (autoreleased, use inside `@autoreleasepool`).
- Custom NSCoding class: encode with `encodeInt:forKey:`, `encodeDouble:forKey:`,
  `encodeObject:forKey:`, `encodeBytes:length:forKey:`; decode symmetrically
  with `decodeIntForKey:` etc. in the same order.

## 6. Integration Examples

### Example 1: Unkeyed (sequential) archiving of a custom object

```objc
#import <MulleObjCArchiverFoundation/MulleObjCArchiverFoundation.h>

@interface Foo : NSObject <NSCoding>

@property char    *str;
@property double  d;
@property int     i;

@end


@implementation Foo

- (id) initWithCoder:(NSCoder *) aDecoder
{
   [self init];

   [aDecoder decodeValueOfObjCType:@encode( int)
                                at:&_i];
   [aDecoder decodeValueOfObjCType:@encode( double)
                                at:&_d];
   [aDecoder decodeValueOfObjCType:@encode( char *)
                                at:&_str];
   return( self);
}


- (void) encodeWithCoder:(NSCoder *) coder
{
   [coder encodeValueOfObjCType:@encode( int)
                             at:&_i];
   [coder encodeValueOfObjCType:@encode( double)
                             at:&_d];
   [coder encodeValueOfObjCType:@encode( char *)
                             at:&_str];
}

@end


int main( int argc, const char * argv[])
{
   Foo      *foo;
   Foo      *foo2;
   NSData   *data;

   @autoreleasepool
   {
      foo  = [[Foo new] autorelease];
      [foo setStr:"VfL Bochum 1848"];
      [foo setD:18.48];
      [foo setI:1848];

      // encode
      data = [NSArchiver archivedDataWithRootObject:foo];

      // decode (returns autoreleased object)
      foo2 = [NSUnarchiver unarchiveObjectWithData:data];

      printf( "%s\n", [foo2 str]);
      printf( "%f\n", [foo2 d]);
      printf( "%d\n", [foo2 i]);
   }
   return( 0);
}
```

### Example 2: Keyed archiving — round trip with named keys

```objc
#import <MulleObjCArchiverFoundation/MulleObjCArchiverFoundation.h>

@interface Foo : NSObject <NSCoding>

@property char    *str;
@property double  d;
@property int     i;

@end


@implementation Foo

- (id) initWithCoder:(NSCoder *) aDecoder
{
   NSUInteger   len;
   void         *buf;

   [self init];

   _d = [aDecoder decodeDoubleForKey:@"d"];
   _i = [aDecoder decodeIntForKey:@"i"];

   buf = [aDecoder decodeBytesForKey:@"str"
                      returnedLength:&len];
   if( buf)
      _str = MulleObjCInstanceDuplicateUTF8String( self, buf);
   else
      _str = NULL;
   return( self);
}


- (void) encodeWithCoder:(NSCoder *) coder
{
   [coder encodeInt:_i
             forKey:@"i"];
   [coder encodeDouble:_d
                forKey:@"d"];
   [coder encodeBytes:_str
               length:strlen( _str) + 1
               forKey:@"str"];
}

@end


int   main( int argc, const char * argv[])
{
   Foo      *foo;
   Foo      *foo2;
   NSData   *data;

   @autoreleasepool
   {
      foo  = [[Foo new] autorelease];
      [foo setStr:"VfL Bochum 1848"];
      [foo setD:18.48];
      [foo setI:1848];

      data = [NSKeyedArchiver archivedDataWithRootObject:foo];
      foo2 = [NSKeyedUnarchiver unarchiveObjectWithData:data];

      if( ! foo2)
      {
         printf( "Failed\n");
         return( 1);
      }
      printf( "%s\n", [foo2 str]);
      printf( "%f\n", [foo2 d]);
      printf( "%d\n", [foo2 i]);
   }
   return( 0);
}
```

### Example 3: Archive an object graph to a file (OSBase)

```objc
#import <MulleObjCArchiverFoundation/MulleObjCArchiverFoundation.h>

int   main( int argc, const char * argv[])
{
   BOOL     ok;
   NSArray  *array;
   NSArray  *restored;
   NSData   *data;

   @autoreleasepool
   {
      array = [NSArray arrayWithObjects:@"one", @"two", @"three", nil];

      // convenience: encode and write atomically to a file
      ok = [NSArchiver archiveRootObject:array
                       toFile:@"/tmp/data.archive"];

      // read back
      data     = [NSData dataWithContentsOfFile:@"/tmp/data.archive"];
      restored = [NSUnarchiver unarchiveObjectWithData:data];

      printf( "%s\n", ok && restored ? [restored UTF8String] : "Failed");
   }
   return( 0);
}
```

### Example 4: Low-level variable-length integer coding (mulle-buffer-archiver)

```c
#import <MulleObjCArchiverFoundation/MulleObjCArchiverFoundation.h>
#import <MulleObjCArchiverFoundation/mulle-buffer-archiver.h>

int   main( int argc, const char * argv[])
{
   struct mulle_buffer   buffer;
   uint64_t              read;

   mulle_buffer_init_default( &buffer);

   mulle_buffer_add_integer( &buffer, 0x1fffffffffULL);
   mulle_buffer_set_seek( &buffer, 0, SEEK_SET);
   read = mulle_buffer_next_integer( &buffer);

   printf( "%llu\n", (unsigned long long) read);

   mulle_buffer_done( &buffer);
   return( 0);
}
```

## 7. Dependencies

Direct `mulle-sde` library dependencies (from `.mulle/etc/sourcetree/config`
and `clib.json`):

- `MulleObjCStandardFoundation` — provides `NSObject`, `NSString`, `NSData`,
  `NSMutableData`, `NSMapTable`, the `NSCoding` protocol, and the mulle-objc
  runtime. Transitively supplies the underlying C libraries used directly by
  this project's public headers (e.g. `mulle-buffer` for
  `mulle-buffer-archiver.h`, `mulle-container` for the handle maps).
- `mulle-objc-list` — tooling dependency (lists mulle-objc runtime info;
  `no-link`, `no-import`).