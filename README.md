# What is this ?

This is a project were various already produced bits get wrapped into
a format, that is convenient on OS.X.

On OS X, you don't usually install libraries, you have Frameworks. The
Framework contains the headers and the shared library and possibly some other
resources.

To wrap it all together and make the headers of the consituent libraries also
available, each library headers are wrapped into a sub-framework and all
libraries together are part of Foundation.framework.

The headers and libraries are not built by this project, they are all grabbed
from "dependencies", built by `mulle-bootstrap`.


# How to build it

Currently out of the box the Foundation library is a shared library on non-OS X
platfors. It contains all the dependent library code.

> This makes it easy to develop, but maybe not _quite_ as easy to distribute.
> Creating a  static Foundation library isn't impossible though.


### Compiling the Foundation on non OS X Unixes

```
mulle-bootstrap
( cd build; cmake ..;  make; cd ..)
```


### Installing the Foundation on non OS X Unixes

and then install the shared library and it's headers with

```
( cd build ; make install )
```


> The sub-frameworks are just containers for the headers, they have no actual
library code.

# Where is the code ?

The code gets downloaded by `mulle-bootstrap` into the .repos directory. If
you want to develop the Foundation itself. It will be better to checkout the
following three projects:

MulleObjCOSFoundation
MulleObjCStandardFoundation
MulleObjC


# Where are the headers ?

Xcode silently adds a RemoveHeadersOnCopy setting to the embedded frameworks.
This has been hand-edited out. But more than likely, this will be helpfully
added again by another Xcode version automatically. (Scumbags)


> Memo: A framework, where the executable is named differently than the framework
doesn't work. The linker can't deal with it.


## Author

[Nat!](//www.mulle-kybernetik.com/weblog) for
[Mulle kybernetiK](//www.mulle-kybernetik.com) and
[Codeon GmbH](//www.codeon.de)
