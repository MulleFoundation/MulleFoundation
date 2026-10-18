# MulleFoundation

#### 🧱 MulleFoundation amalgamates Foundations projects

This is an almagamation of the MulleFoundation libraries that do not 
depend on platform specific code (below MulleObjCOSFoundation),
See the [constituting projects](#Constituents) for documentation, 
bug reports, pull requests.

The advantages of **MulleFoundationBase** are:

* compiles faster than almost a dozen individual projects
* you only need to link against one library file
* `#import` statements of the individual libraries can remain unchanged or can be simplified to `#import <MulleFoundationBase/MulleFoundationBase.h>`







## Documentation & Guides

* [API Summary](asset/dox/api/toc)
* [Coder Guide](asset/howto/coder/mulle-foundation-base)




## Constituents

Add another constituent to the amalgamation with:

``` bash
mulle-sde dependency add --amalgamated \
                         --fetchoptions "clibmode=copy" \
                         --address src/MulleObjCWhateverFoundation \
                         clib:MulleFoundation/MulleObjCWhateverFoundation
```

Then edit `MulleFoundationBase.h` and add the envelope header to the others.



| Constituent                                  | Description
|----------------------------------------------|-----------------------
| [MulleObjCArchiverFoundation](https://github.com/MulleFoundation/MulleObjCArchiverFoundation) | 🚪 NSCoding classes like NSArchiver/NSUnarchiver
| [MulleObjCBSDFoundation](https://github.com/MulleFoundation/MulleObjCBSDFoundation) | 
| [MulleObjCCalendarFoundation](https://github.com/MulleFoundation/MulleObjCCalendarFoundation) | 📆 Calendar class NSCalendar
| [MulleObjCDarwinFoundation](https://github.com/MulleFoundation/MulleObjCDarwinFoundation) | 
| [MulleObjCFreeBSDFoundation](https://github.com/MulleFoundation/MulleObjCFreeBSDFoundation) | 
| [MulleObjCLinuxFoundation](https://github.com/MulleFoundation/MulleObjCLinuxFoundation) | 
| [MulleObjCOSBaseFoundation](https://github.com/MulleFoundation/MulleObjCOSBaseFoundation) | 
| [MulleObjCOSFoundation](https://github.com/MulleFoundation/MulleObjCOSFoundation) | 💻 Platform-dependent classes and categories like NSTask, NSPipe
| [MulleObjCPosixFoundation](https://github.com/MulleFoundation/MulleObjCPosixFoundation) | 
| [MulleObjCWindowsFoundation](https://github.com/MulleFoundation/MulleObjCWindowsFoundation) | 


## Add

**This project is a component of the [MulleFoundation](//github.com/MulleFoundation/MulleFoundation) library.
As such you usually will *not* add or install it individually, unless you
specifically do not want to link against `MulleFoundation`.**


### Add as an individual component

Use [mulle-sde](//github.com/mulle-sde) to add MulleFoundation to your project:

``` sh
mulle-sde add github:MulleFoundation/MulleFoundation
```


## Install

Use [mulle-sde](//github.com/mulle-sde) to build and install MulleFoundation and all dependencies:

``` sh
mulle-sde install --prefix /usr/local \
   https://github.com/MulleFoundation/MulleFoundation/archive/latest.tar.gz
```

### Manual Installation

Install the requirements:

| Requirements                                 | Description
|----------------------------------------------|-----------------------
| [MulleFoundationBase](https://github.com/MulleFoundation/MulleFoundationBase)             | 🧱 MulleFoundationBase amalgamates Foundations projects

Download the latest [tar](https://github.com/MulleFoundation/MulleFoundation/archive/refs/tags/latest.tar.gz) or [zip](https://github.com/MulleFoundation/MulleFoundation/archive/refs/tags/latest.zip) archive and unpack it.

Install **MulleFoundation** into `/usr/local` with [cmake](https://cmake.org):

``` sh
PREFIX_DIR="/usr/local"
cmake -B build                               \
      -DMULLE_SDK_PATH="${PREFIX_DIR}"       \
      -DCMAKE_INSTALL_PREFIX="${PREFIX_DIR}" \
      -DCMAKE_PREFIX_PATH="${PREFIX_DIR}"    \
      -DCMAKE_BUILD_TYPE=Release &&
cmake --build build --config Release &&
cmake --install build --config Release
```

## Author

[Nat!](https://mulle-kybernetik.com/weblog) for Mulle kybernetiK  


