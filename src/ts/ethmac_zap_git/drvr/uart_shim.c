#include "uart.h"

// Simple wrappers expected by the EthMAC demo

void uart_puts(const char* s) {
    // Reuse existing UARTWrite from your uart.c
    UARTWrite((char*)s);
}

static inline char hex_nibble(unsigned v) {
    v &= 0xF;
    return (v < 10) ? ('0' + v) : ('A' + (v - 10));
}

void uart_puthex(unsigned x) {
    char buf[11];
    buf[0] = '0';
    buf[1] = 'x';
    for (int i = 0; i < 8; i++) {
        buf[2 + i] = hex_nibble(x >> (28 - 4 * i));
    }
    buf[10] = '\0';
    uart_puts(buf);
}
