# MulleFoundation

#### 💍 Umbrella library for the MulleFoundation

MulleFoundation combines various Objective-C class libraries into one unifying
Foundation that you `#import` and link against.



| Release Version                                       | Release Notes  | AI Documentation
|-------------------------------------------------------|----------------|---------------
| ![Mulle kybernetiK tag](https://img.shields.io/github/tag/MulleFoundation/MulleFoundation.svg) [![Build Status](https://github.com/MulleFoundation/MulleFoundation/workflows/CI/badge.svg)](//github.com/MulleFoundation/MulleFoundation/actions) | [RELEASENOTES](RELEASENOTES.md) | [DeepWiki for MulleFoundation](https://deepwiki.com/MulleFoundation/MulleFoundation)


## API

| Class             | Description
|-------------------|-----------
| `NSConditionLock` |




## Requirements

|   Requirement         | Release Version  | Description
|-----------------------|------------------|---------------
| [MulleFoundationBase](https://github.com/MulleFoundation/MulleFoundationBase) | ![Mulle kybernetiK tag](https://img.shields.io/github/tag/MulleFoundation/MulleFoundationBase.svg) [![Build Status](https://github.com/MulleFoundation/MulleFoundationBase/workflows/CI/badge.svg?branch=release)](https://github.com/MulleFoundation/MulleFoundationBase/actions/workflows/mulle-sde-ci.yml) | 🧱 MulleFoundationBase amalgamates Foundations projects
| [MulleObjCOSFoundation](https://github.com/MulleFoundation/MulleObjCOSFoundation) | ![Mulle kybernetiK tag](https://img.shields.io/github/tag/MulleFoundation/MulleObjCOSFoundation.svg) [![Build Status](https://github.com/MulleFoundation/MulleObjCOSFoundation/workflows/CI/badge.svg?branch=release)](https://github.com/MulleFoundation/MulleObjCOSFoundation/actions/workflows/mulle-sde-ci.yml) | 💻 Platform-dependent classes and categories like NSTask, NSPipe
| [MulleObjCDecimalFoundation](https://github.com/MulleFoundation/MulleObjCDecimalFoundation) | ![Mulle kybernetiK tag](https://img.shields.io/github/tag/MulleFoundation/MulleObjCDecimalFoundation.svg) [![Build Status](https://github.com/MulleFoundation/MulleObjCDecimalFoundation/workflows/CI/badge.svg?branch=release)](https://github.com/MulleFoundation/MulleObjCDecimalFoundation/actions/workflows/mulle-sde-ci.yml) | 🤲🏻 Large Decimal Numbers
| [MulleObjCCalendarFoundation](https://github.com/MulleFoundation/MulleObjCCalendarFoundation) | ![Mulle kybernetiK tag](https://img.shields.io/github/tag/MulleFoundation/MulleObjCCalendarFoundation.svg) [![Build Status](https://github.com/MulleFoundation/MulleObjCCalendarFoundation/workflows/CI/badge.svg?branch=release)](https://github.com/MulleFoundation/MulleObjCCalendarFoundation/actions/workflows/mulle-sde-ci.yml) | 📆 Calendar class NSCalendar
| [mulle-objc-list](https://github.com/mulle-objc/mulle-objc-list) | ![Mulle kybernetiK tag](https://img.shields.io/github/tag/mulle-objc/mulle-objc-list.svg) [![Build Status](https://github.com/mulle-objc/mulle-objc-list/workflows/CI/badge.svg?branch=release)](https://github.com/mulle-objc/mulle-objc-list/actions/workflows/mulle-sde-ci.yml) | 📒 Lists mulle-objc runtime information contained in executables.

### You are here

![Overview](overview.dot.svg)

## Add

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

### Legacy Installation

Install the requirements:

| Requirements                                 | Description
|----------------------------------------------|-----------------------
| [MulleFoundationBase](https://github.com/MulleFoundation/MulleFoundationBase)             | 🧱 MulleFoundationBase amalgamates Foundations projects
| [MulleObjCOSFoundation](https://github.com/MulleFoundation/MulleObjCOSFoundation)             | 💻 Platform-dependent classes and categories like NSTask, NSPipe
| [MulleObjCDecimalFoundation](https://github.com/MulleFoundation/MulleObjCDecimalFoundation)             | 🤲🏻 Large Decimal Numbers
| [MulleObjCCalendarFoundation](https://github.com/MulleFoundation/MulleObjCCalendarFoundation)             | 📆 Calendar class NSCalendar
| [mulle-objc-list](https://github.com/mulle-objc/mulle-objc-list)             | 📒 Lists mulle-objc runtime information contained in executables.

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


