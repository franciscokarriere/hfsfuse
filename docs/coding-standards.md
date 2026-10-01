#### 3. `docs/coding-standards.md`

````markdown
# Estándares de Código y Refactorización

## Manejo de Macros de Plataforma

Todo código dependiente del sistema operativo debe aislarse de la siguiente manera:

```c
#ifdef _WIN32
    #include <windows.h>
    #include <winfsp/winfsp.h>
    // Parches para tipos ausentes en MSVC/MinGW
    typedef unsigned int mode_t;
#else
    #include <sys/param.h>
    #include <sys/mount.h>
#endif
```
````
