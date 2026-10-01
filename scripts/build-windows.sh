#!/usr/bin/env bash
# Build hfsfuse.exe and hfsdump.exe natively on Windows (MSYS2 UCRT64 + WinFsp).
# Usage (from any shell): C:\msys64\usr\bin\env.exe MSYSTEM=UCRT64 /usr/bin/bash -l <repo>/scripts/build-windows.sh
#   OUT=name.exe     output file name (default hfsfuse.exe)
#   WINFSP_BIN=dir   WinFsp bin directory (default: standard install location)
#
# The resulting hfsfuse.exe is self-contained: zlib/winpthread are linked statically and
# winfsp-x64.dll is delay-loaded from the WinFsp install directory found in the registry,
# so it runs from the WinFsp.Launcher service without any PATH setup.
set -euo pipefail

cd "$(dirname "$0")/.."

WINFSP_BIN="${WINFSP_BIN:-/c/Program Files (x86)/WinFsp/bin}"
WINFSP_DELAYLIB=third_party/winfsp/lib/libwinfsp-x64-delay.a

make lib/libhfsuser/libhfsuser.a lib/libhfs/libhfs.a lib/utf8proc/libutf8proc.a lib/LZVN/libFastCompression.a hfsdump

if [ ! -f "$WINFSP_DELAYLIB" ] || [ "$WINFSP_BIN/winfsp-x64.dll" -nt "$WINFSP_DELAYLIB" ]; then
	gendef - "$WINFSP_BIN/winfsp-x64.dll" > third_party/winfsp/lib/winfsp-x64.def 2>/dev/null
	dlltool --input-def third_party/winfsp/lib/winfsp-x64.def --dllname winfsp-x64.dll --output-delaylib "$WINFSP_DELAYLIB"
fi

gcc -std=gnu11 -O2 -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers -Werror=incompatible-pointer-types \
	-D_FILE_OFFSET_BITS=64 -D_POSIX_THREAD_SAFE_FUNCTIONS -D_WIN32_WINNT=0x0601 \
	-DFUSE_USE_VERSION=29 -DHAVE_UTF8PROC -DHAVE_LZVN -DHAVE_ZLIB -DXATTR_NAMESPACE=user. \
	-include win_compat.h -I. -Ithird_party/winfsp/lib \
	-iquote lib/libhfsuser -iquote lib/libhfs -iquote lib/utf8proc -iquote lib/LZVN \
	src/hfsfuse.c lib/libhfsuser/libhfsuser.a lib/libhfs/libhfs.a \
	lib/utf8proc/libutf8proc.a lib/LZVN/libFastCompression.a \
	"$WINFSP_DELAYLIB" -ldelayimp \
	-static -lz -lpthread -o "${OUT:-hfsfuse.exe}"

echo "built: $(pwd)/${OUT:-hfsfuse.exe} $(pwd)/hfsdump.exe"
