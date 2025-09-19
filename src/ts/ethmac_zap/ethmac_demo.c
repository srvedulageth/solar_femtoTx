// ethmac_demo.c — init + optional polling helpers for EthMAC demo
#include "ethmac_zap.h"
#include "uart.h"

// Simple UART helpers
static void uart_puts(const char* s) { UARTWrite((char*)s); }

static inline char hex_nibble(unsigned v) {
    v &= 0xF;
    return (v < 10) ? ('0' + v) : ('A' + (v - 10));
}

static void uart_puthex(unsigned x) {
    char buf[11];
    buf[0] = '0'; buf[1] = 'x';
    for (int i=0; i<8; i++) buf[2+i] = hex_nibble(x >> (28 - 4*i));
    buf[10] = 0;
    uart_puts(buf);
}

// Initialize EthMAC with a fixed MAC address
void eth_demo_init(void)
{
    const unsigned char mac[6] = {0x02,0x12,0x34,0x56,0x78,0x9A};
    uart_puts("eth: init\n");
    eth_init(mac);
    uart_puts("eth: init done\n");
}

// Optional: call from your main loop if you want RX polling
void eth_demo_poll(void)
{
    unsigned len;
    if (eth_rx_poll(0, &len) == 1) {
        uart_puts("eth: polled RX len=");
        uart_puthex(len);
        uart_puts("\n");
    }
}
