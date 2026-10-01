#ifndef WIN_COMPAT_H
#define WIN_COMPAT_H

/*
 * <fuse.h> must be included before any compatibility macro so that WinFSP
 * declares struct fuse_stat / struct fuse_statvfs untouched.
 */
#if defined(_WIN32)
#ifndef FUSE_USE_VERSION
#define FUSE_USE_VERSION 29
#endif
#include <fuse.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/*
 * Do not redefine `stat` or `statvfs` to the WinFSP types in this header.
 * WinFSP already defines its own structures and the global alias breaks the
 * inclusion of <fuse.h> / winfsp_fuse.h by causing redefinitions of
 * `struct fuse_stat`.
 *
 * This header should only provide POSIX shims that are missing in MSYS2/UCRT64
 * and must not touch the FUSE structures.
 */

#if defined(_WIN32)
/* Mapeo de Syslog a stderr */
#define LOG_ERR 3
#define LOG_INFO 6
#define LOG_DEBUG 7
#define openlog(ident, option, facility) ((void)0)
#define syslog(priority, format, ...) fprintf(stderr, format "\n", ##__VA_ARGS__)
#define closelog() ((void)0)

/* Implementaciones POSIX faltantes en MinGW/UCRT64 */
static inline char *stpcpy(char *dest, const char *src) {
    size_t len = strlen(src);
    return (char *)memcpy(dest, src, len + 1) + len;
}

static inline struct tm *localtime_r(const time_t *timep, struct tm *result) {
    if (localtime_s(result, timep) == 0) return result;
    return NULL;
}

#ifndef ST_RDONLY
#define ST_RDONLY 1
#endif
#endif

#endif