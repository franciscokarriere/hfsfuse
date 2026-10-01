# Instrucciones de Compilación (MSYS2 + MinGW-w64)

## Entorno Requerido

- Entorno recomendado: **MSYS2 MINGW64**.
- Herramientas: `gcc`, `make`, `pkg-config`.
- WinFSP: instalado en el sistema anfitrión con el componente "FUSE for Cygwin/MSYS2".
- Si se usa la copia local del proyecto, la biblioteca y los headers deben quedar bajo `third_party/winfsp/lib`.

## Rutas de Inclusión y Vinculación (Flags de Compilador)

- **Includes locales del proyecto:** `-I$(pwd)/third_party/winfsp/lib`
- **Bibliotecas locales del proyecto:** `-L$(pwd)/third_party/winfsp/lib -l:libfuse-2.8.dll.a`
- **Ruta de sistema WinFSP real:** `C:/Program Files (x86)/WinFsp/usr/include/fuse` y `C:/Program Files (x86)/WinFsp/usr/lib`

## Comandos de Compilación Estándar

```bash
# En MSYS2 MINGW64
cd /c/REPOSITORIES/hfsfuse/hfsfuse

gcc -std=gnu11 -O2 -Wall -Wextra -pedantic \
    -D_FILE_OFFSET_BITS=64 -D_POSIX_THREAD_SAFE_FUNCTIONS \
    -I"/c/REPOSITORIES/hfsfuse/hfsfuse/third_party/winfsp/lib" \
    -L"/c/REPOSITORIES/hfsfuse/hfsfuse/third_party/winfsp/lib" \
    src/hfsfuse.c lib/libhfs/libhfs.a lib/libhfsuser/libhfsuser.a \
    -l:libfuse-2.8.dll.a -lpthread -o hfsfuse.exe
```

> Si se usa la instalación nativa de WinFSP en lugar de la copia local, sustituir `third_party/winfsp/lib` por `"/c/Program Files (x86)/WinFsp/usr/lib"` y el include por `"/c/Program Files (x86)/WinFsp/usr/include/fuse"`.
