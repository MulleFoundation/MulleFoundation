/*
 *  MulleFoundation - the mulle-objc class library
 *
 *  NSFileManager+Windows.m is a part of MulleObjCOSFoundation
 *
 *  Copyright (C) 2024 Mulle kybernetiK.
 *  All rights reserved.
 *
 */

#import "import-private.h"
#import "NSFileManager+Windows.h"

// other files in this library
#import "NSErrorWindows.h"
#import <MulleObjCOSBaseFoundation/NSFileManager-Private.h>

// Windows headers
#include <windows.h>
// windows.h temporarily defines 'interface' as 'struct' for COM headers, but
// restores it via push/pop_macro on exit, leaving 'interface' undefined.
// shlwapi.h uses 'interface' via DECLARE_INTERFACE (combaseapi.h), so we must
// redefine it as 'struct' for the duration of this include.
#pragma push_macro("interface")
#define interface struct
#include <shlwapi.h>
#pragma pop_macro("interface")
#include <winioctl.h>
#include <string.h>


#ifndef SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE
# define SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE 0x2
#endif


#define MULLE_WINDOWS_EPOCH_OFFSET  11644473600.0


//
// llvm-mingw does not expose REPARSE_DATA_BUFFER, define our own
//
typedef struct
{
   ULONG    ReparseTag;
   USHORT   ReparseDataLength;
   USHORT   Reserved;
   union
   {
      struct
      {
         USHORT   SubstituteNameOffset;
         USHORT   SubstituteNameLength;
         USHORT   PrintNameOffset;
         USHORT   PrintNameLength;
         ULONG    Flags;
         WCHAR    PathBuffer[ 1];
      } SymbolicLinkReparseBuffer;
      struct
      {
         USHORT   SubstituteNameOffset;
         USHORT   SubstituteNameLength;
         USHORT   PrintNameOffset;
         USHORT   PrintNameLength;
         WCHAR    PathBuffer[ 1];
      } MountPointReparseBuffer;
   } u;
} MulleReparseDataBuffer;


static void   set_integer_key_value( NSMutableDictionary *dictionary,
                                     NSString *key,
                                     long long value)
{
   NSNumber   *number;

   number = [NSNumber numberWithLongLong:value];
   [dictionary setObject:number
                  forKey:key];
}


static void   fileTimeToTimeInterval( FILETIME *filetime, NSTimeInterval *interval)
{
   ULARGE_INTEGER   value;

   value.LowPart  = filetime->dwLowDateTime;
   value.HighPart = filetime->dwHighDateTime;
   *interval = (NSTimeInterval) value.QuadPart / 10000000.0 - MULLE_WINDOWS_EPOCH_OFFSET;
}


static void   timeIntervalToFileTime( NSTimeInterval interval, FILETIME *filetime)
{
   ULARGE_INTEGER   value;

   value.QuadPart = (ULONGLONG) ((interval + MULLE_WINDOWS_EPOCH_OFFSET) * 10000000.0 + 0.5);
   filetime->dwLowDateTime  = value.LowPart;
   filetime->dwHighDateTime = value.HighPart;
}


static unsigned long long   volumeSerialNumberForPathUTF16( mulle_utf16_t *s_utf16)
{
   WCHAR    full[ MAX_PATH];
   WCHAR    root[ 4];
   DWORD    len;
   DWORD    serial;

   len = GetFullPathNameW( (LPCWSTR) s_utf16, MAX_PATH, full, NULL);
   if( ! len || len >= MAX_PATH)
      return( 0);

   if( full[ 1] != ':')
      return( 0);

   root[ 0] = full[ 0];
   root[ 1] = ':';
   root[ 2] = '\\';
   root[ 3] = 0;

   if( ! GetVolumeInformationW( root, NULL, 0, &serial, NULL, NULL, NULL, 0))
      return( 0);

   return( serial);
}


static unsigned long long   fileIndexForPathUTF16( mulle_utf16_t *s_utf16,
                                                   BOOL openReparse)
{
   BY_HANDLE_FILE_INFORMATION   info;
   unsigned long long           index;
   DWORD                        flags;
   HANDLE                       handle;

   flags = FILE_FLAG_BACKUP_SEMANTICS;
   if( openReparse)
      flags |= FILE_FLAG_OPEN_REPARSE_POINT;

   handle = CreateFileW( (LPCWSTR) s_utf16,
                         0,
                         FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                         NULL,
                         OPEN_EXISTING,
                         flags,
                         NULL);
   if( handle == INVALID_HANDLE_VALUE)
      return( 0);

   index = 0;
   if( GetFileInformationByHandle( handle, &info))
      index = ((unsigned long long) info.nFileIndexHigh << 32) | info.nFileIndexLow;

   CloseHandle( handle);
   return( index);
}


static NSString   *mulleStringFromReparseUTF16( WCHAR *buffer, USHORT offset, USHORT length)
{
   NSString   *s;

   s = [[[NSString alloc] mulleInitWithUTF16Characters:(mulle_utf16_t *) ((char *) buffer + offset)
                                               length:length / sizeof( WCHAR)] autorelease];
   return( s);
}


static NSString   *readLinkTargetUTF16( mulle_utf16_t *s_utf16)
{
   char                   raw[ MAXIMUM_REPARSE_DATA_BUFFER_SIZE];
   MulleReparseDataBuffer   *buffer;
   DWORD                  bytes;
   HANDLE                 handle;
   NSString               *target;

   handle = CreateFileW( (LPCWSTR) s_utf16,
                         0,
                         FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                         NULL,
                         OPEN_EXISTING,
                         FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS,
                         NULL);
   if( handle == INVALID_HANDLE_VALUE)
      return( nil);

   buffer = (MulleReparseDataBuffer *) raw;
   if( ! DeviceIoControl( handle, FSCTL_GET_REPARSE_POINT, NULL, 0,
                          buffer, sizeof( raw), &bytes, NULL))
   {
      CloseHandle( handle);
      return( nil);
   }
   CloseHandle( handle);

   target = nil;
   switch( buffer->ReparseTag)
   {
   case IO_REPARSE_TAG_SYMLINK :
      if( buffer->u.SymbolicLinkReparseBuffer.PrintNameLength)
         target = mulleStringFromReparseUTF16( buffer->u.SymbolicLinkReparseBuffer.PathBuffer,
                                               buffer->u.SymbolicLinkReparseBuffer.PrintNameOffset,
                                               buffer->u.SymbolicLinkReparseBuffer.PrintNameLength);
      else
         target = mulleStringFromReparseUTF16( buffer->u.SymbolicLinkReparseBuffer.PathBuffer,
                                               buffer->u.SymbolicLinkReparseBuffer.SubstituteNameOffset,
                                               buffer->u.SymbolicLinkReparseBuffer.SubstituteNameLength);
      break;

   case IO_REPARSE_TAG_MOUNT_POINT :
      target = mulleStringFromReparseUTF16( buffer->u.MountPointReparseBuffer.PathBuffer,
                                            buffer->u.MountPointReparseBuffer.SubstituteNameOffset,
                                            buffer->u.MountPointReparseBuffer.SubstituteNameLength);
      break;

   default :
      break;
   }

   if( target)
   {
      // strip the \??\ prefix Windows uses for absolute links
      if( [target hasPrefix:@"\\??\\"])
         target = [target substringFromIndex:4];
      target = [target mulleUnixFileSystemString];
   }
   return( target);
}


@implementation NSFileManager( Windows)

@dependency NSFileManager;


- (int) _isValidDirectoryContentsFilenameAsCString:(char *) s
{
   int  c;

   if( ! s || ! *s)
      return( _MulleObjCFilenameIsNoFile);
   if( *s != '.')
      return( _MulleObjCFilenameIsNormal);
   c = s[ 1];
   if( ! c)
      return( _MulleObjCFilenameIsDot);
   if( c == '_')
      return( _MulleObjCFilenameIsSystem);
   if( c == '.' && ! s[ 2])
      return( _MulleObjCFilenameIsDotDot);
   return( _MulleObjCFilenameIsHidden);
}


- (char *) fileSystemRepresentationWithPath:(NSString *) path
{
   NSString   *converted;

   converted = [path mulleWindowsFileSystemString];
   return( [converted UTF8String]);
}


- (mulle_utf16_t *) fileSystemRepresentationUTF16WithPath:(NSString *) path
{
   NSString   *converted;

   converted = [path mulleWindowsFileSystemString];
   return( [converted mulleUTF16String]);
}


- (NSString *) stringWithFileSystemRepresentation:(char *) s
                                           length:(NSUInteger) len
{
   NSString   *path;
   NSString   *converted;

   MULLE_C_UNUSED( len);
   if( ! s)
      return( nil);
   
   path      = [NSString stringWithUTF8String:s];
   converted = [path mulleUnixFileSystemString];
   
   return( converted);
}


- (NSString *) stringWithFileSystemRepresentationUTF16:(mulle_utf16_t *) s_utf16
                                                length:(NSUInteger) len
{
   NSString   *path;
   NSString   *converted;

   MULLE_C_UNUSED( len);
   if( ! s_utf16)
      return( nil);

   path      = [NSString mulleStringWithUTF16String:s_utf16];
   converted = [path mulleUnixFileSystemString];

   return( converted);
}


- (NSString *) pathContentOfSymbolicLinkAtPath:(NSString *) path
{
   mulle_utf16_t   *s_utf16;
   DWORD           attributes;

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( nil);

   attributes = GetFileAttributesW( (LPCWSTR) s_utf16);
   if( attributes == INVALID_FILE_ATTRIBUTES)
      return( nil);
   if( ! (attributes & FILE_ATTRIBUTE_REPARSE_POINT))
      return( nil);

   return( readLinkTargetUTF16( s_utf16));
}


- (BOOL) changeCurrentDirectoryPath:(NSString *) path
{
   BOOL            result;
   mulle_utf16_t   *s_utf16;

   MulleObjCSetWindowsErrorDomain();

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( NO);

   result = SetCurrentDirectoryW( s_utf16);

   return( result ? YES : NO);
}


- (NSString *) currentDirectoryPath
{
   WCHAR       buf[ MAX_PATH];
   DWORD       len;
   NSString    *path;

   MulleObjCSetWindowsErrorDomain();

   len = GetCurrentDirectoryW( MAX_PATH, buf);
   if( ! len)
      return( nil);

   // len is the number of characters excluding null terminator
   path = [[[NSString alloc] mulleInitWithUTF16Characters:(mulle_utf16_t *) buf
                                                   length:len] autorelease];
   // Convert Windows path to Unix format
   path = [path mulleUnixFileSystemString];
   return( path);
}



- (BOOL) fileExistsAtPath:(NSString *) path
{
   DWORD            attrs;
   mulle_utf16_t   *s_utf16;

   MulleObjCSetWindowsErrorDomain();

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16 || ! *s_utf16)
      return( NO);

   attrs = GetFileAttributesW( s_utf16);

   return( attrs != INVALID_FILE_ATTRIBUTES ? YES : NO);
}


- (BOOL) fileExistsAtPath:(NSString *) path
              isDirectory:(BOOL *) isDir
{
   DWORD            attrs;
   BOOL             dummy;
   mulle_utf16_t   *s_utf16;

   MulleObjCSetWindowsErrorDomain();

   if( ! isDir)
      isDir = &dummy;

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
   {
      *isDir = NO;
      return( NO);
   }

   attrs = GetFileAttributesW( s_utf16);

   if( attrs == INVALID_FILE_ATTRIBUTES)
   {
      *isDir = NO;
      return( NO);
   }

   *isDir = (attrs & FILE_ATTRIBUTE_DIRECTORY) ? YES : NO;
   return( YES);
}


- (BOOL) isReadableFileAtPath:(NSString *) path
{
   DWORD            attrs;
   mulle_utf16_t   *s_utf16;

   MulleObjCSetWindowsErrorDomain();

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( NO);

   attrs = GetFileAttributesW( s_utf16);

   return( attrs != INVALID_FILE_ATTRIBUTES ? YES : NO);
}


- (BOOL) isWritableFileAtPath:(NSString *) path
{
   DWORD            attrs;
   mulle_utf16_t   *s_utf16;

   MulleObjCSetWindowsErrorDomain();

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( NO);

   attrs = GetFileAttributesW( s_utf16);

   if( attrs == INVALID_FILE_ATTRIBUTES)
      return( NO);

   return( (attrs & FILE_ATTRIBUTE_READONLY) ? NO : YES);
}


- (BOOL) isDeletableFileAtPath:(NSString *) path
{
   return( [self isWritableFileAtPath:path]);
}


- (BOOL) isExecutableFileAtPath:(NSString *) path
{
   NSString   *ext;

   MulleObjCSetWindowsErrorDomain();

   if( ! [self fileExistsAtPath:path])
      return( NO);

   ext = [[path pathExtension] lowercaseString];
   return( [ext isEqualToString:@"exe"] || 
           [ext isEqualToString:@"bat"] || 
           [ext isEqualToString:@"cmd"] ||
           [ext isEqualToString:@"com"]);
}


- (int) _createDirectoryAtPath:(NSString *) path
                    attributes:(NSDictionary *) attributes
{
   BOOL             result;
   mulle_utf16_t   *s_utf16;

   MULLE_C_UNUSED( attributes);
   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( -1);

   result = CreateDirectoryW( s_utf16, NULL);

   if( result)
      return( 0);

   switch( GetLastError())
   {
   case ERROR_ALREADY_EXISTS : return( EEXIST);
   case ERROR_PATH_NOT_FOUND : return( ENOENT);
   default                   : return( -1);
   }
}


- (BOOL) createDirectoryAtPath:(NSString *) path
   withIntermediateDirectories:(BOOL) createIntermediates
                    attributes:(NSDictionary *) attributes
                         error:(NSError **) error
{
   NSArray          *components;
   NSMutableArray   *subComponents;
   NSString         *subpath;
   NSUInteger       i, n;
   int              rc;
   BOOL             isDirectory;

   MULLE_C_UNUSED( error);
   MulleObjCSetWindowsErrorDomain();

   rc = [self _createDirectoryAtPath:path
                          attributes:attributes];
   if( ! rc)
      return( YES);

   if( rc == EEXIST)
   {
      // an existing item is only an error, if we didn't want intermediates
      if( ! createIntermediates)
         return( NO);

      // Apple compatible: an existing directory is a success
      if( ! [self fileExistsAtPath:path
                       isDirectory:&isDirectory])
         return( NO);

      return( isDirectory);
   }

   if( rc != ENOENT)
      return( NO);

   if( ! createIntermediates)
      return( NO);

   subComponents = [NSMutableArray array];
   components    = [path pathComponents];
   n             = [components count];

   for( i = 0; i < n; i++)
   {
      [subComponents addObject:[components objectAtIndex:i]];
      subpath = [NSString pathWithComponents:subComponents];

      rc = [self _createDirectoryAtPath:subpath
                             attributes:attributes];
      if( rc == EEXIST)
         continue;

      if( rc)
         return( NO);
   }

   return( YES);
}


- (BOOL) _removeFileAtPath:(NSString *) path
{
   BOOL             result;
   mulle_utf16_t   *s_utf16;

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( NO);

   result = DeleteFileW( s_utf16);

   return( result ? YES : NO);
}


- (BOOL) _removeEmptyDirectoryItemAtPath:(NSString *) path
{
   BOOL             result;
   mulle_utf16_t   *s_utf16;

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( NO);

   result = RemoveDirectoryW( s_utf16);

   return( result ? YES : NO);
}


- (NSArray *) directoryContentsAtPath:(NSString *) path
{
   WIN32_FIND_DATAW   findData;
   HANDLE             hFind;
   NSMutableArray     *array;
   NSString           *searchPath;
   NSString           *filename;
   mulle_utf16_t      *s_utf16;

   MulleObjCSetWindowsErrorDomain();

   searchPath = [path stringByAppendingPathComponent:@"*"];
   s_utf16    = [self fileSystemRepresentationUTF16WithPath:searchPath];
   if( ! s_utf16)
      return( nil);

   array = [NSMutableArray array];
   hFind = FindFirstFileW( s_utf16, &findData);

   if( hFind == INVALID_HANDLE_VALUE)
      return( nil);

   do
   {
      if( findData.cFileName[ 0] == '.')
      {
         if( ! findData.cFileName[ 1])
            continue;
         if( findData.cFileName[ 1] == '.' && ! findData.cFileName[ 2])
            continue;
         if( findData.cFileName[ 1] == '_')
            continue;
      }

      filename = [self stringWithFileSystemRepresentationUTF16:findData.cFileName
                                                        length:wcslen( findData.cFileName)];
      [array addObject:filename];
   }
   while( FindNextFileW( hFind, &findData));

   FindClose( hFind);

   return( array);
}


- (NSDictionary *) _itemAttributesAtPath:(NSString *) path
                            traverseLink:(BOOL) traverseLink
{
   NSMutableDictionary         *dictionary;
   BY_HANDLE_FILE_INFORMATION  info;
   WIN32_FILE_ATTRIBUTE_DATA   attributeData;
   FILETIME                    creation;
   FILETIME                    modification;
   mulle_utf16_t               *s_utf16;
   NSTimeInterval              interval;
   unsigned long long          index;
   unsigned long long          serial;
   unsigned long long          size;
   DWORD                       attributes;
   HANDLE                      handle;
   BOOL                        isDirectory;
   BOOL                        isLink;
   NSString                    *type;
   int                         permissions;

   MulleObjCSetWindowsErrorDomain();

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( nil);

   attributes = GetFileAttributesW( (LPCWSTR) s_utf16);
   if( attributes == INVALID_FILE_ATTRIBUTES)
      return( nil);

   isLink      = (attributes & FILE_ATTRIBUTE_REPARSE_POINT) ? YES : NO;
   isDirectory = (attributes & FILE_ATTRIBUTE_DIRECTORY) ? YES : NO;
   size        = 0;
   index       = 0;
   creation.dwLowDateTime  = 0;
   creation.dwHighDateTime = 0;
   modification            = creation;

   if( isLink && ! traverseLink)
   {
      if( ! GetFileAttributesExW( (LPCWSTR) s_utf16, GetFileExInfoStandard, &attributeData))
         return( nil);

      creation     = attributeData.ftCreationTime;
      modification = attributeData.ftLastWriteTime;
      size         = ((unsigned long long) attributeData.nFileSizeHigh << 32) | attributeData.nFileSizeLow;
      index        = fileIndexForPathUTF16( s_utf16, YES);
   }
   else
   {
      handle = CreateFileW( (LPCWSTR) s_utf16,
                            0,
                            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                            NULL,
                            OPEN_EXISTING,
                            FILE_FLAG_BACKUP_SEMANTICS,
                            NULL);
      if( handle == INVALID_HANDLE_VALUE)
         return( nil);

      if( ! GetFileInformationByHandle( handle, &info))
      {
         CloseHandle( handle);
         return( nil);
      }
      CloseHandle( handle);

      creation     = info.ftCreationTime;
      modification = info.ftLastWriteTime;
      size         = ((unsigned long long) info.nFileSizeHigh << 32) | info.nFileSizeLow;
      index        = ((unsigned long long) info.nFileIndexHigh << 32) | info.nFileIndexLow;
      isDirectory  = (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? YES : NO;
   }

   serial = volumeSerialNumberForPathUTF16( s_utf16);

   if( isDirectory)
      permissions = 0755;
   else
      permissions = (attributes & FILE_ATTRIBUTE_READONLY) ? 0444 : 0644;

   dictionary = [NSMutableDictionary dictionary];

   set_integer_key_value( dictionary, NSFilePosixPermissions, permissions);
   set_integer_key_value( dictionary, NSFileReferenceCount, 1);
   set_integer_key_value( dictionary, NSFileSize, (long long) size);
   set_integer_key_value( dictionary, NSFileSystemFileNumber, (long long) index);
   set_integer_key_value( dictionary, NSFileSystemNumber, (long long) serial);

   if( isLink && ! traverseLink)
      type = NSFileTypeSymbolicLink;
   else
      type = isDirectory ? NSFileTypeDirectory : NSFileTypeRegular;

   [dictionary setObject:type
                  forKey:NSFileType];

   fileTimeToTimeInterval( &creation, &interval);
   [dictionary setObject:[NSDate dateWithTimeIntervalSince1970:interval]
                  forKey:NSFileCreationDate];

   fileTimeToTimeInterval( &modification, &interval);
   [dictionary setObject:[NSDate dateWithTimeIntervalSince1970:interval]
                  forKey:NSFileModificationDate];

   return( dictionary);
}


- (NSDictionary *) fileAttributesAtPath:(NSString *) path
                           traverseLink:(BOOL) flag
{
   return( [self _itemAttributesAtPath:path
                          traverseLink:flag]);
}


- (NSDictionary *) attributesOfItemAtPath:(NSString *) path
                                    error:(NSError **) error
{
   MULLE_C_UNUSED( error);
   MulleObjCSetWindowsErrorDomain();

   return( [self _itemAttributesAtPath:path
                          traverseLink:NO]);
}


- (BOOL) setAttributes:(NSDictionary *) attributes
          ofItemAtPath:(NSString *) path
                 error:(NSError **) error
{
   NSDate          *date;
   NSNumber        *number;
   mulle_utf16_t   *s_utf16;
   FILETIME        filetime;
   DWORD           attributeBits;
   HANDLE          handle;
   BOOL            success;

   MULLE_C_UNUSED( error);
   MulleObjCSetWindowsErrorDomain();

   if( ! [attributes count])
      return( YES);

   if( ! [self fileExistsAtPath:path])
      return( NO);

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( NO);

   number = [attributes objectForKey:NSFilePosixPermissions];
   if( number)
   {
      attributeBits = GetFileAttributesW( (LPCWSTR) s_utf16);
      if( attributeBits == INVALID_FILE_ATTRIBUTES)
         return( NO);

      // Windows has no permission bits, approximate with the readonly flag
      if( ([number unsignedIntValue] & 0222) == 0)
         attributeBits |= FILE_ATTRIBUTE_READONLY;
      else
         attributeBits &= ~FILE_ATTRIBUTE_READONLY;

      if( ! SetFileAttributesW( (LPCWSTR) s_utf16, attributeBits))
         return( NO);
   }

   date = [attributes objectForKey:NSFileModificationDate];
   if( date)
   {
      handle = CreateFileW( (LPCWSTR) s_utf16,
                            FILE_WRITE_ATTRIBUTES,
                            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                            NULL,
                            OPEN_EXISTING,
                            FILE_FLAG_BACKUP_SEMANTICS,
                            NULL);
      if( handle == INVALID_HANDLE_VALUE)
         return( NO);

      timeIntervalToFileTime( [date timeIntervalSince1970], &filetime);
      success = SetFileTime( handle, NULL, NULL, &filetime);
      CloseHandle( handle);
      if( ! success)
         return( NO);
   }

   return( YES);
}


- (NSDictionary *) fileSystemAttributesAtPath:(NSString *) path
{
   NSMutableDictionary  *dictionary;
   mulle_utf16_t        *s_utf16;
   ULARGE_INTEGER       freeBytes;
   ULARGE_INTEGER       totalBytes;
   ULARGE_INTEGER       totalFreeBytes;
   WCHAR                full[ MAX_PATH];
   WCHAR                root[ 4];
   DWORD                len;
   DWORD                serial;

   MulleObjCSetWindowsErrorDomain();

   if( ! [self fileExistsAtPath:path])
      return( nil);

   s_utf16 = [self fileSystemRepresentationUTF16WithPath:path];
   if( ! s_utf16)
      return( nil);

   len = GetFullPathNameW( (LPCWSTR) s_utf16, MAX_PATH, full, NULL);
   if( ! len || len >= MAX_PATH)
      return( nil);

   if( full[ 1] != ':')
      return( nil);

   root[ 0] = full[ 0];
   root[ 1] = ':';
   root[ 2] = '\\';
   root[ 3] = 0;

   if( ! GetDiskFreeSpaceExW( root, &freeBytes, &totalBytes, &totalFreeBytes))
      return( nil);

   if( ! GetVolumeInformationW( root, NULL, 0, &serial, NULL, NULL, NULL, 0))
      return( nil);

   dictionary = [NSMutableDictionary dictionary];

   set_integer_key_value( dictionary, NSFileSystemSize, (long long) totalBytes.QuadPart);
   set_integer_key_value( dictionary, NSFileSystemFreeSize, (long long) totalFreeBytes.QuadPart);
   // Windows has no inode counts, approximate from the capacity
   set_integer_key_value( dictionary, NSFileSystemNodes, (long long) (totalBytes.QuadPart / 4096));
   set_integer_key_value( dictionary, NSFileSystemFreeNodes, (long long) (totalFreeBytes.QuadPart / 4096));
   set_integer_key_value( dictionary, NSFileSystemNumber, (long long) serial);

   return( dictionary);
}


- (NSDictionary *) attributesOfFileSystemForPath:(NSString *) path
                                           error:(NSError **) error
{
   MULLE_C_UNUSED( error);
   MulleObjCSetWindowsErrorDomain();

   return( [self fileSystemAttributesAtPath:path]);
}


- (BOOL) createSymbolicLinkAtPath:(NSString *) path
              withDestinationPath:(NSString *) otherpath
                            error:(NSError **) error
{
   mulle_utf16_t   *s_path;
   mulle_utf16_t   *s_target;
   DWORD           flags;
   BOOL            isDirectory;

   MULLE_C_UNUSED( error);
   MulleObjCSetWindowsErrorDomain();

   s_path   = [self fileSystemRepresentationUTF16WithPath:path];
   s_target = [self fileSystemRepresentationUTF16WithPath:otherpath];
   if( ! s_path || ! s_target)
      return( NO);

   isDirectory = NO;
   [self fileExistsAtPath:otherpath
              isDirectory:&isDirectory];

   flags = isDirectory ? SYMBOLIC_LINK_FLAG_DIRECTORY : 0;

   if( CreateSymbolicLinkW( (LPCWSTR) s_path, (LPCWSTR) s_target, flags))
      return( YES);

   // Windows 10 permits unprivileged symlink creation with this flag
   if( CreateSymbolicLinkW( (LPCWSTR) s_path, (LPCWSTR) s_target,
                            flags | SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE))
      return( YES);

   return( NO);
}


- (NSString *) destinationOfSymbolicLinkAtPath:(NSString *) path
                                         error:(NSError **) error
{
   MULLE_C_UNUSED( error);
   MulleObjCSetWindowsErrorDomain();

   return( [self pathContentOfSymbolicLinkAtPath:path]);
}


- (BOOL) copyItemAtPath:(NSString *) fromPath
                 toPath:(NSString *) toPath
                  error:(NSError **) error
{
   NSArray         *contents;
   NSString        *destination;
   NSString        *name;
   NSString        *subFrom;
   NSString        *subTo;
   mulle_utf16_t   *s_from;
   mulle_utf16_t   *s_to;
   NSUInteger      i, n;
   BOOL            isDirectory;

   MULLE_C_UNUSED( error);
   MulleObjCSetWindowsErrorDomain();

   // a symbolic link is copied as a link, not as its destination
   destination = [self pathContentOfSymbolicLinkAtPath:fromPath];
   if( destination)
   {
      if( [self fileExistsAtPath:toPath])
         return( NO);
      return( [self createSymbolicLinkAtPath:toPath
                         withDestinationPath:destination
                                       error:error]);
   }

   if( ! [self fileExistsAtPath:fromPath
                    isDirectory:&isDirectory])
      return( NO);

   if( [self fileExistsAtPath:toPath])
      return( NO);

   s_from = [self fileSystemRepresentationUTF16WithPath:fromPath];
   s_to   = [self fileSystemRepresentationUTF16WithPath:toPath];
   if( ! s_from || ! s_to)
      return( NO);

   if( ! isDirectory)
      return( CopyFileW( (LPCWSTR) s_from, (LPCWSTR) s_to, TRUE) ? YES : NO);

   if( ! CreateDirectoryW( (LPCWSTR) s_to, NULL))
      return( NO);

   contents = [self directoryContentsAtPath:fromPath];
   n        = [contents count];
   for( i = 0; i < n; i++)
   {
      name    = [contents objectAtIndex:i];
      subFrom = [fromPath stringByAppendingPathComponent:name];
      subTo   = [toPath stringByAppendingPathComponent:name];
      if( ! [self copyItemAtPath:subFrom
                         toPath:subTo
                          error:error])
         return( NO);
   }

   return( YES);
}


- (BOOL) moveItemAtPath:(NSString *) srcPath
                 toPath:(NSString *) dstPath
                  error:(NSError **) error
{
   mulle_utf16_t   *s_src;
   mulle_utf16_t   *s_dst;
   BOOL            isDirectory;

   MULLE_C_UNUSED( error);
   MulleObjCSetWindowsErrorDomain();

   if( ! [self fileExistsAtPath:srcPath
                    isDirectory:&isDirectory])
      return( NO);

   if( [self fileExistsAtPath:dstPath])
      return( NO);

   s_src = [self fileSystemRepresentationUTF16WithPath:srcPath];
   s_dst = [self fileSystemRepresentationUTF16WithPath:dstPath];
   if( ! s_src || ! s_dst)
      return( NO);

   if( MoveFileW( (LPCWSTR) s_src, (LPCWSTR) s_dst))
      return( YES);

   if( [self copyItemAtPath:srcPath
                    toPath:dstPath
                     error:error])
   {
      [self removeItemAtPath:srcPath
                       error:NULL];
      return( YES);
   }

   return( NO);
}


- (BOOL) copyPath:(NSString *) src
           toPath:(NSString *) dest
          handler:(id) handler
{
   NSError   *error;

   if( [handler respondsToSelector:@selector( fileManager:willProcessPath:)])
      [handler fileManager:self
           willProcessPath:src];

   error = nil;
   if( [self copyItemAtPath:src
                    toPath:dest
                     error:&error] == NO)
   {
      if( [handler respondsToSelector:@selector( fileManager:shouldProceedAfterError:copyingItemAtPath:toPath:)])
         return( [handler fileManager:self
               shouldProceedAfterError:error
                     copyingItemAtPath:src
                                toPath:dest]);
      return( NO);
   }
   return( YES);
}


- (BOOL) movePath:(NSString *) src
           toPath:(NSString *) dest
          handler:(id) handler
{
   NSError   *error;

   if( [handler respondsToSelector:@selector( fileManager:willProcessPath:)])
      [handler fileManager:self
           willProcessPath:src];

   error = nil;
   if( [self moveItemAtPath:src
                    toPath:dest
                     error:&error] == NO)
   {
      if( [handler respondsToSelector:@selector( fileManager:shouldProceedAfterError:movingItemAtPath:toPath:)])
         return( [handler fileManager:self
               shouldProceedAfterError:error
                     movingItemAtPath:src
                                toPath:dest]);
      return( NO);
   }
   return( YES);
}

@end
