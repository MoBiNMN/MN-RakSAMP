#ifndef PLATFORM_COMPAT_H
#define PLATFORM_COMPAT_H
#include <chrono>
#include <cstdint>

inline uint64_t GETTICKCOUNT()
{
    auto now = std::chrono::steady_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                  now.time_since_epoch())
                  .count();
    return (uint64_t)ms;
}

#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#include <ws2tcpip.h>

#define SPRINTF_S sprintf_s
#define VSPRINTF_S vsprintf_s
#define strnicmp _strnicmp
#else
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <sys/time.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <errno.h>
#include <stdlib.h>

typedef uint16_t WORD;
typedef uint32_t DWORD;
typedef uint8_t BYTE;
typedef int SOCKET;
typedef int32_t BOOL;

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif
#ifndef NULL
#define NULL 0
#endif

#define strnicmp strncasecmp

#define FIONBIO 0x8004667e
typedef void *LPVOID;
typedef void *PVOID;
typedef unsigned char *PBYTE;
typedef char *PCHAR;

#define ZeroMemory(Destination, Length) memset((Destination), 0, (Length))
#define strcpy_s(dest, len, src) strncpy(dest, src, len)

#endif

#endif
