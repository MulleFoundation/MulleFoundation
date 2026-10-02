# `cmake/` overrides

Three modules here shadow their `cmake/share/` originals (a module in `cmake/`
wins on the module path and survives `mulle-sde` upgrades). Each is a verbatim
copy of the stock module plus a marked delta. All three deltas serve one case:
building the amalgamation from source via `add_subdirectory()` (no prebuilt SDK,
no `mulle-craft`), where dependencies are CMake targets instead of files.

They form a chain:

```
Headers.cmake  ──▶  InstallCMakeInclude.cmake  ──▶  Library.cmake
 collect the         copy them into a single         link dep targets into
 full public         ${CMAKE_BINARY_DIR}/include     BOTH object stages so
 header set          under the RIGHT prefix          each inherits that
                     dir, expose as INTERFACE         include dir + ordering
```

## `Headers.cmake` — include the platform buckets in the export set

Stock `Headers.cmake` folds only the generic constituents into
`INSTALL_PUBLIC_HEADERS`. But `<MulleFoundation.h>` unconditionally
imports the platform constituents (`MulleObjCPosixFoundation`,
`MulleObjCLinuxFoundation`, …), which live in the `POSIX_HEADERS` /
`LINUX_HEADERS` / `BSD_HEADERS` / `DARWIN_HEADERS` / `WINDOWS_HEADERS` buckets.
Left out of the export set, they never reach `include/`, and the umbrella fails
with `'MulleObjCPosixFoundation/...' file not found`.

**Delta** (`=== OVERRIDE DELTA ===`): build `PLATFORM_PUBLIC_HEADERS` for the
current platform (same chain the top-level `CMakeLists.txt` uses for sources:
`Posix <- Linux/BSD <- Darwin`, or `Windows`) and append it to the set feeding
`INSTALL_PUBLIC_HEADERS`.

## `InstallCMakeInclude.cmake` — route each header to the right prefix dir

This is what makes a `MulleObjC` header land in `include/MulleObjC/` and **not**
in `include/MulleFoundation/`.

For each header in `INSTALL_PUBLIC_HEADERS` / `INSTALL_PRIVATE_HEADERS` it looks
at the header's own relative directory:

```cmake
if( HEADER_REL_DIR MATCHES "^Mulle|^mulle-")
    set( DEST_DIR "${CMAKE_BINARY_DIR}/include/${HEADER_REL_DIR}")   # e.g. include/MulleObjC
else()
    set( DEST_DIR "${CMAKE_BINARY_DIR}/include/${LIBRARY_NAME}")     # include/MulleFoundation
endif()
```

So a source header at `src/MulleObjC/foo.h` is copied to
`include/MulleObjC/foo.h`, `src/mulle-objc-runtime/...` (via a dep) keeps its
`mulle-objc-runtime/` prefix, and anything without a `Mulle`/`mulle-` prefix
falls back under the library's own name. This matches the `<MulleObjC/foo.h>`
form the sources actually `#import`, and mirrors the layout an installed SDK
dependency would have — one amalgamated include root, correctly prefixed.

It then bundles the copies into a `${LIBRARY_NAME}-headers` target, makes the
library depend on it (copy runs before compile), and sets
`${CMAKE_BINARY_DIR}/include` as the library's `INTERFACE_INCLUDE_DIRECTORIES`.

(The `copy_if_different` per-header logic is the delta; the commented block at
the bottom is the inert stock alternative.)

## `Library.cmake` — propagate deps to stage 2, not just stage 1

The library builds as two OBJECT libraries: `_1_${LIBRARY_NAME}` (stage 1) and
`_2_${LIBRARY_NAME}` (stage 2, e.g. the `MulleObjC*Foundation` sources). OBJECT
libraries don't link, so they don't inherit a dependency's include dirs on their
own. The stock module compensates with a `foreach` that does
`target_link_libraries( _1_... PRIVATE dep)` for every dependency that resolved
to a target — inheriting its `INTERFACE_INCLUDE_DIRECTORIES` (the
`include/` dir from `InstallCMakeInclude`) and its build ordering.

Stock applies that to **stage 1 only**. Stage-2 sources that
`#include <mulle-objc-runtime/...>` then fail with `file not found` in the
from-source build.

**Delta** (`OVERRIDE FIX`): duplicate the exact stage-1 `foreach` onto
`${LIBRARY_STAGE2_TARGET}`, so stage 2 gets the same include dirs and ordering.

The same file also handles INTERFACE re-export for `add_subdirectory` consumers
(ordinary dep targets re-exported by name; all-load deps wrapped in
`$<LINK_LIBRARY:WHOLE_ARCHIVE,...>`; file deps and per-constituent `INCLUDE_DIRS`
deliberately not re-exported — see the `MEMO` comment).

## Maintenance

On upgrade, diff the new `cmake/share/<name>.cmake` against the override and
re-apply the marked delta.
