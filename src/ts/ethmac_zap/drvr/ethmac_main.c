#include "ethmac_zap.h"
#include <string.h>

/* Weak UART shims if you don't link uart.c */
__attribute__((weak)) void uart_puts(const char* s){ (void)s; }
__attribute__((weak)) void uart_puthex(unsigned x){ (void)x; }

static void hexdump(const void* p, unsigned len){
    const unsigned char* b = (const unsigned char*)p;
    for (unsigned i=0;i<len;i++){
        static const char h[]="0123456789ABCDEF";
        char out[3] = { h[b[i]>>4], h[b[i]&0xF], 0 };
        uart_puts(out);
        if ((i&15)==15) uart_puts("\n"); else uart_puts(" ");
    }
    if ((len&15)!=0) uart_puts("\n");
}

int main(void)
{
    /* Example MAC address (locally administered) */
    const unsigned char mac[6] = {0x02,0x12,0x34,0x56,0x78,0x9A};

    uart_puts("eth: init\n");
    eth_init(mac);

    /* Build a tiny broadcast test frame (not a valid protocol, just a TX test) */
    static unsigned char tx[60];
    memset(tx, 0, sizeof(tx));
    /* DA = ff:ff:ff:ff:ff:ff */
    memset(tx+0, 0xFF, 6);
    /* SA = our MAC */
    memcpy(tx+6, mac, 6);
    /* Ethertype 0x88B5 (experimental) */
    tx[12]=0x88; tx[13]=0xB5;
    /* payload pattern */
    for (int i=14;i<60;i++) tx[i] = (unsigned char)i;

    uart_puts("eth: sending test frame (60B)\n");
    hexdump(tx, 60);
    eth_tx_enqueue(tx, 60);

    /* Poll for any RX frames and print length */
    uart_puts("eth: polling for RX...\n");
    unsigned len;
    unsigned char rxbuf[1600];
    for (;;){
        if (eth_rx_poll(rxbuf, &len) == 1){
            uart_puts("eth: RX len=");
            uart_puthex(len);
            uart_puts("\n");
        }
        /* spin; or sleep if you have a timer */
    }

    return 0;
}
