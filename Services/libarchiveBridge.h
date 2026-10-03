//
//  libarchiveBridge.h
//  ComicReader
//
//  libarchive C 库桥接头文件。
//  使用方法：
//  1. 将此文件加入 Xcode 项目
//  2. Target → Build Settings → Objective-C Bridging Header 设置为 $(SRCROOT)/ComicReader/libarchiveBridge.h
//  3. Target → Build Phases → Link Binary With Libraries 添加 libarchive.tbd
//

#ifndef libarchiveBridge_h
#define libarchiveBridge_h

#include <archive.h>
#include <archive_entry.h>

#endif /* libarchiveBridge_h */
