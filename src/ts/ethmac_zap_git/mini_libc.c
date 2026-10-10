// mini_libc.c — minimal libc for freestanding firmware
#include <stddef.h>

void *memcpy(void *dst, const void *src, size_t n) {
    unsigned char *d = (unsigned char*)dst;
    const unsigned char *s = (const unsigned char*)src;
    while (n--) { *d++ = *s++; }
    return dst;
}

void *memmove(void *dst, const void *src, size_t n) {
    unsigned char *d = (unsigned char*)dst;
    const unsigned char *s = (const unsigned char*)src;
    if (d == s || n == 0) return dst;
    if (d < s) {
        while (n--) { *d++ = *s++; }
    } else {
        d += n; s += n;
        while (n--) { *--d = *--s; }
    }
    return dst;
}

void *memset(void *dst, int c, size_t n) {
    unsigned char *d = (unsigned char*)dst;
    unsigned char v = (unsigned char)c;
    while (n--) { *d++ = v; }
    return dst;
}

int memcmp(const void *a, const void *b, size_t n) {
    const unsigned char *p = (const unsigned char*)a;
    const unsigned char *q = (const unsigned char*)b;
    while (n--) {
        unsigned char x = *p++, y = *q++;
        if (x != y) return (int)x - (int)y;
    }
    return 0;
}

size_t strlen(const char *s) {
    const char *p = s;
    while (*p) ++p;
    return (size_t)(p - s);
}
