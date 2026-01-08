# MulleFoundation Library Documentation for AI

## 1. Introduction & Purpose

**MulleFoundation** is the top-level umbrella library that aggregates all MulleFoundation framework components into a single, unified import. It provides a complete Objective-C Foundation framework equivalent compatible with standard Objective-C conventions and NSObject runtime.

Rather than requiring developers to link against 15+ separate libraries and manage complex dependency chains, MulleFoundation consolidates everything:
- All value types (NSNumber, NSString, NSData, NSValue, NSNull)
- All collection types (NSArray, NSDictionary, NSSet with mutable variants)
- Time/calendar operations (NSDate, NSTimeZone, NSCalendar, NSDateComponents)
- Standard utility classes (NSFormatter, NSScanner, NSLocale, NSUndoManager, NSException, NSError)
- OS integration (NSTask, NSPipe, file I/O, environment access)
- Advanced features (serialization, regex, UUID, math, Unicode operations)
- Web/networking components (HTTP, JSON, XML parsing, Base64, Zlib compression)

This is the **primary import** for virtually all MulleFoundation-based applications.

## 2. Key Concepts & Design Philosophy

### Unified Foundation Framework
MulleFoundation exists to provide a single, stable API surface that encapsulates the complete ecosystem without requiring end-users to understand the internal component hierarchy. It's the "System.Framework" equivalent for mulle-objc.

### Component Aggregation Pattern
Rather than implementing each class directly, MulleFoundation serves as a **forwarding header** that:
1. Imports all component libraries in dependency order
2. Re-exports their public APIs
3. Ensures all symbols are available through one canonical import
4. Maintains binary compatibility across versions

### Layered Dependency Resolution
Internal structure follows a careful dependency ordering:
- **Layer 1**: Core ObjC runtime (MulleObjC)
- **Layer 2**: Base value types (Time, Value, UUID, Container)
- **Layer 3**: Mid-level utilities (Calendar, Math, Unicode, Archiving)
- **Layer 4**: High-level abstractions (Standard Foundation, OS, KVC)
- **Layer 5**: Advanced features (Regex, Plist, Expat XML)
- **Layer 6**: Framework integration and startup

Each layer builds upon the previous without circular dependencies.

### Single-Import Principle
Developers using MulleFoundation should never need to import individual component libraries. All public APIs are re-exported through the umbrella header, providing a consistent, discoverable interface.

## 3. Core API & Data Structures

### 3.1 Umbrella Import Header

#### Purpose
Single `#import <MulleFoundation/MulleFoundation.h>` provides access to all Foundation functionality.

#### What Gets Imported

**Layer 1: ObjC Foundation**
- `MulleObjC` - Objective-C runtime
- `MulleObjCStandardFoundation` - Core Foundation classes

**Layer 2: Basic Types**
- `MulleObjCTimeFoundation` - NSDate, NSTimeZone, NSTimer
- `MulleObjCValueFoundation` - NSNumber, NSString, NSData, NSValue, NSNull
- `MulleObjCUUIDFoundation` - NSUUID generation
- `MulleObjCContainerFoundation` - NSArray, NSDictionary, NSSet, mutable variants

**Layer 3: Mid-Level**
- `MulleObjCCalendarFoundation` - NSCalendar, NSDateComponents
- `MulleObjCMathFoundation` - NSDecimalNumber, math functions
- `MulleObjCUnicodeFoundation` - Unicode character properties, operations
- `MulleObjCArchiverFoundation` - NSCoder, NSKeyedArchiver serialization
- `MulleObjCPlistFoundation` - Property list encoding/decoding (NSPropertyListSerialization)

**Layer 4: High-Level**
- `MulleObjCKVCFoundation` - Key-value coding (KVC)
- `MulleObjCOSFoundation` - File I/O, environment, platform services (NSTask, NSPipe)
- `MulleObjCRegexFoundation` - Regular expression support (NSRegularExpression)
- `MulleObjCExpatFoundation` - XML parsing via libexpat

**Layer 5: Framework Integration**
- `MulleFoundationBase` - Base container for all Foundation components
- All standard classes and protocols documented in component libraries

#### Visibility & Scope
MulleFoundation **re-exports** all public symbols from component libraries. Private symbols (prefixed with `_` or marked internal) are not intended for direct use and may change between releases.

### 3.2 Key Classes Available (Organized by Category)

#### Value Types
- `NSNumber` - Boxed numeric values (int, long, float, double, bool)
- `NSString` - Immutable Unicode text strings
- `NSMutableString` - Mutable strings
- `NSData` - Immutable binary data
- `NSMutableData` - Mutable binary data
- `NSValue` - Box arbitrary structs/values
- `NSNull` - Singleton representing null/nil value

#### Collections
- `NSArray` - Immutable ordered collection
- `NSMutableArray` - Mutable ordered collection
- `NSDictionary` - Immutable key-value mapping
- `NSMutableDictionary` - Mutable key-value mapping
- `NSSet` - Immutable unordered unique values
- `NSMutableSet` - Mutable set
- `NSCountedSet` - Set with multiplicity (frequency count)

#### Date & Time
- `NSDate` - Immutable point-in-time (seconds since epoch)
- `NSCalendarDate` - Date with timezone and calendar awareness
- `NSTimeZone` - Timezone information
- `NSCalendar` - Calendar system (Gregorian, Islamic, etc.)
- `NSDateComponents` - Decomposed date parts (year, month, day, etc.)
- `NSTimer` - Scheduled callbacks

#### Formatting & Parsing
- `NSFormatter` - Base class for format conversions
- `NSDateFormatter` - NSDate ↔ NSString
- `NSNumberFormatter` - NSNumber ↔ NSString with locale support
- `NSScanner` - Parse structured text
- `NSLocale` - Localization settings

#### Exceptions & Errors
- `NSException` - Throwable exception for @throw/@catch
- `NSError` - Error object for return values
- `NSAssertionHandler` - Handles assertion failures

#### Utility Classes
- `NSCharacterSet` - Character membership/classification sets
- `NSMutableCharacterSet` - Mutable character set
- `NSUndoManager` - Undo/redo operation stacks
- `NSNotificationCenter` - Publish-subscribe messaging
- `NSUUID` - Universally unique identifiers
- `NSDecimalNumber` - Arbitrary-precision decimal arithmetic
- `NSRange` - Range structure (location + length)

#### Serialization
- `NSCoder` - Abstract base for encoding/decoding
- `NSKeyedArchiver` / `NSKeyedUnarchiver` - Key-based serialization
- `NSPropertyListSerialization` - Property list encoding/decoding

#### Platform/OS Services
- `NSTask` - Execute external processes
- `NSPipe` - Pipe for process I/O
- `NSFileManager` - File system operations
- `NSFileHandle` - Low-level file I/O
- `NSBundle` - Application bundle access
- `NSProcessInfo` - Process information and environment
- `NSEnvironment` - Environment variable access

#### Advanced Features
- `NSRegularExpression` - Regular expression pattern matching
- Unicode character properties and operations
- XML parsing via libexpat
- Base64 encoding/decoding (MulleBase64)
- Zlib compression (MulleZlib)

### 3.3 Framework Initialization

#### Automatic Initialization
When you import `<MulleFoundation/MulleFoundation.h>`, all component libraries are automatically initialized in correct dependency order via constructor functions. This happens before `main()` is called.

#### Custom Startup Initialization
If needed, call the component startup functions explicitly:
- The framework handles this automatically in most cases
- Only relevant if using special initialization sequences or embedding

#### Usage Pattern
```objc
#import <MulleFoundation/MulleFoundation.h>

int main(void) {
    // All Foundation classes and methods are immediately available
    NSString *greeting = @"Hello, MulleFoundation!";
    NSLog(@"%@", greeting);
    return 0;
}
```

---

## 4. Performance Characteristics

### Memory & Initialization
- **Startup overhead**: All component libraries loaded and initialized (typically < 100ms)
- **Binary size**: ~500KB-1MB depending on included components
- **Runtime footprint**: ~50-100 MB for typical application with loaded classes

### Class Lookup Performance
- `NSClassFromString()` - O(log n) hash table lookup where n = total classes (~300-500)
- Method dispatch - O(1) via receiver's isa pointer lookup table (standard ObjC)
- Dynamic property access - O(1) hash table lookup per property name

### Memory Efficiency
- String interning reduces duplicate string storage
- Value types (NSNumber, NSString) use class cluster optimization
- Collections use hash tables and balanced trees for efficiency

---

## 5. AI Usage Recommendations & Patterns

### Best Practices

**Always Use MulleFoundation Import:**
- Never import individual component libraries directly in application code
- Use `#import <MulleFoundation/MulleFoundation.h>` as your canonical import
- This ensures stability and allows internal reorganization without breaking code

**Type-Safe Collection Usage:**
- Use typed containers where possible (all elements same type)
- NSArray of NSNumber, NSDictionary with NSString keys, etc.
- Avoids runtime type checking overhead

**Immutable Types First:**
- Use immutable variants (NSString, NSArray, NSDictionary) as defaults
- Switch to mutable only when modifications are necessary
- Immutable objects are inherently thread-safe and more efficient

**Memory Management:**
- Follow standard ObjC retain/release/autorelease patterns
- Use `@autoreleasepool { }` blocks in loops that generate temporary objects
- Be aware that some Foundation methods return autoreleased objects

**Error Handling:**
- Use NSError for recoverable errors (I/O, parsing, user input)
- Use NSException for invariant violations and programming errors
- Always check return values and error out-parameters

### Common Pitfalls

**Incorrect Import Paths:**
- Don't write `#import <MulleObjCTimeFoundation/NSDate.h>` or similar in application code
- Use single umbrella import; let internal component structure remain private

**Assuming Component Availability:**
- Don't import component-specific headers; they're internal implementation
- All needed functionality is available through MulleFoundation

**Thread Safety Assumptions:**
- Most Foundation classes are NOT thread-safe; use external synchronization
- NSNotificationCenter is NOT thread-safe
- NSMutableArray, NSMutableDictionary are NOT thread-safe
- Use locks, GCD, or immutable types for multi-threaded access

**Memory Leaks:**
- Remember to unregister NSNotificationCenter observers (major leak source)
- Don't forget to release NSUndoManager or leave dangling references
- Check for cyclic retain chains

**Forgetting Locale/Timezone:**
- NSDateFormatter, NSNumberFormatter use current locale
- NSCalendarDate and NSTimeZone handle timezone calculations
- Test with multiple locales/timezones for correct behavior

### Idiomatic Usage Patterns

**Pattern 1: Complete Application Structure**
```objc
#import <MulleFoundation/MulleFoundation.h>

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // All Foundation classes immediately available
        NSArray *args = [NSArray arrayWithObjects:argv + 1 count:argc - 1];
        NSLog(@"Arguments: %@", args);
        
        // Create and use Foundation objects
        NSDictionary *data = @{@"key": @"value"};
        return 0;
    }
}
```

**Pattern 2: Safe Exception Handling**
```objc
@try {
    NSArray *items = [NSArray arrayWithObject:nil];
    [NSException raise:NSInvalidArgumentException format:@"nil not allowed"];
}
@catch (NSException *e) {
    NSLog(@"Exception: %@ - %@", [e name], [e reason]);
}
@finally {
    // Cleanup always happens
}
```

**Pattern 3: Error Handling with Out-Parameter**
```objc
NSError *error = nil;
NSString *contents = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
if (!contents && error) {
    NSLog(@"Failed to read file: %@", [error localizedDescription]);
}
```

**Pattern 4: Safe Collection Access**
```objc
NSArray *items = @[@1, @2, @3];
if ([items count] > index) {
    id value = [items objectAtIndex:index];
    NSLog(@"Item: %@", value);
} else {
    NSLog(@"Index out of bounds");
}
```

---

## 6. Integration Examples

### Example 1: Mixed Type Collection with Safe Access

```objc
#import <MulleFoundation/MulleFoundation.h>

int main(void) {
    @autoreleasepool {
        // Create a mixed collection
        NSDictionary *person = @{
            @"name": @"Alice",
            @"age": [NSNumber numberWithInt:30],
            @"uuid": [NSUUID UUID],
            @"tags": @[@"engineer", @"music", @"science"]
        };
        
        // Safe access with type checking
        NSString *name = [person objectForKey:@"name"];
        NSNumber *age = [person objectForKey:@"age"];
        NSArray *tags = [person objectForKey:@"tags"];
        
        NSLog(@"Person: %@ (%@ years old)", name, age);
        NSLog(@"Tags: %@", [tags componentsJoinedByString:@", "]);
        
        return 0;
    }
}
```

### Example 2: Date Formatting with Locale

```objc
#import <MulleFoundation/MulleFoundation.h>

int main(void) {
    @autoreleasepool {
        NSDate *now = [NSDate date];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] 
                                     initWithDateFormat:@"%A, %B %d, %Y"
                                        allowNaturalLanguage:NO];
        
        NSString *formatted = [formatter stringFromDate:now];
        NSLog(@"Today: %@", formatted);
        
        [formatter release];
        return 0;
    }
}
```

### Example 3: Error Handling with Collections

```objc
#import <MulleFoundation/MulleFoundation.h>

int main(void) {
    @autoreleasepool {
        NSMutableArray *items = [NSMutableArray array];
        
        // Safely add items
        for (int i = 0; i < 5; i++) {
            [items addObject:[NSNumber numberWithInt:i * 10]];
        }
        
        // Safe iteration and access
        NSEnumerator *enumerator = [items objectEnumerator];
        NSNumber *item;
        while ((item = [enumerator nextObject])) {
            NSLog(@"Item: %@", item);
        }
        
        return 0;
    }
}
```

### Example 4: Notification-Based Event System

```objc
#import <MulleFoundation/MulleFoundation.h>

// Register for notifications
void setup_observer(id observer) {
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(onChange:)
                                                 name:@"DataChanged"
                                               object:nil];
}

// Cleanup observer
void cleanup_observer(id observer) {
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

// Post notification
void notify_change(NSString *key, id value) {
    NSDictionary *userInfo = @{@"key": key, @"value": value};
    [[NSNotificationCenter defaultCenter] 
        postNotificationName:@"DataChanged"
                      object:nil
                    userInfo:userInfo];
}
```

### Example 5: Advanced Error Handling with Serialization

```objc
#import <MulleFoundation/MulleFoundation.h>

int main(void) {
    @autoreleasepool {
        // Create data structure
        NSDictionary *data = @{
            @"users": @[
                @{@"id": @1, @"name": @"Alice"},
                @{@"id": @2, @"name": @"Bob"}
            ],
            @"timestamp": [NSDate date]
        };
        
        // Serialize to property list
        NSError *error = nil;
        NSData *plist = [NSPropertyListSerialization 
                        dataFromPropertyList:data
                        format:NSPropertyListXMLFormat_v1_0
                        errorDescription:NULL];
        
        if (plist) {
            NSLog(@"Serialized: %lu bytes", (unsigned long)[plist length]);
        } else if (error) {
            NSLog(@"Serialization error: %@", [error localizedDescription]);
        }
        
        return 0;
    }
}
```

---

## 7. Dependencies

**MulleFoundation** directly aggregates and re-exports all of the following component libraries:

### Core Runtime
- **MulleObjC** - Objective-C runtime foundation
- **MulleObjCStandardFoundation** - Core Foundation classes

### Basic Value Types
- **MulleObjCTimeFoundation** - NSDate, NSTimeZone, NSTimer
- **MulleObjCValueFoundation** - NSNumber, NSString, NSData, NSValue, NSNull
- **MulleObjCUUIDFoundation** - NSUUID
- **MulleObjCContainerFoundation** - NSArray, NSDictionary, NSSet, mutable variants

### Mid-Level Components
- **MulleObjCCalendarFoundation** - NSCalendar, NSDateComponents
- **MulleObjCMathFoundation** - NSDecimalNumber, math functions
- **MulleObjCUnicodeFoundation** - Unicode operations
- **MulleObjCArchiverFoundation** - NSCoder, NSKeyedArchiver, serialization
- **MulleObjCPlistFoundation** - Property list encoding/decoding

### High-Level & Specialized
- **MulleObjCKVCFoundation** - Key-value coding
- **MulleObjCOSFoundation** - File I/O, NSTask, environment variables
- **MulleObjCRegexFoundation** - Regular expressions
- **MulleObjCExpatFoundation** - XML parsing

### Integration Container
- **MulleFoundationBase** - Meta-package that bundles all Foundation components

All component APIs are re-exported through this single umbrella library, eliminating the need for end-user code to manage individual dependencies. This is the single, stable import surface for all MulleFoundation functionality.
