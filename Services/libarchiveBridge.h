//
//  libarchiveBridge.h
//  ComicReader
//
//  libarchive C 库桥接头文件。
//  iOS SDK 不包含 libarchive 头文件，这里手动声明所需函数和常量。
//  使用方法：
//  1. 将此文件加入 Xcode 项目
//  2. Target → Build Settings → Objective-C Bridging Header 设置为此文件
//  3. Target → Build Phases → Link Binary With Libraries 添加 libarchive.tbd
//

#ifndef libarchiveBridge_h
#define libarchiveBridge_h

#include <stdint.h>
#include <stddef.h>

// MARK: - 常量
#define ARCHIVE_EOF    1
#define ARCHIVE_OK     0
#define ARCHIVE_RETRY  (-10)
#define ARCHIVE_WARN   (-20)
#define ARCHIVE_FAILED (-25)
#define ARCHIVE_FATAL  (-30)

// 文件类型（与 sys/stat.h 的 AE_IFxxx 对应）
#define AE_IFMT   0170000
#define AE_IFREG  0100000
#define AE_IFDIR  0040000
#define AE_IFLNK  0120000

// MARK: - 不透明类型
struct archive;
struct archive_entry;

// MARK: - archive_read 函数
struct archive *archive_read_new(void);
int archive_read_support_filter_all(struct archive *);
int archive_read_support_format_all(struct archive *);
int archive_read_open_filename(struct archive *, const char *filename, size_t block_size);
int archive_read_next_header(struct archive *, struct archive_entry **);
ssize_t archive_read_data(struct archive *, void *buff, size_t len);
int archive_read_data_skip(struct archive *);
int archive_read_close(struct archive *);
int archive_read_free(struct archive *);
const char *archive_error_string(struct archive *);

// MARK: - archive_entry 函数
const char *archive_entry_pathname(struct archive_entry *);
int archive_entry_filetype(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);

#endif /* libarchiveBridge_h */
