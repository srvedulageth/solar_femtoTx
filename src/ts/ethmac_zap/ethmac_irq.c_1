#include "ethmac_zap.h"

/* Optional IRQ bits — adjust to your ethmac_defines if different */
#define INT_TXB    (1u<<0)
#define INT_TXE    (1u<<1)
#define INT_RXF    (1u<<3)
#define INT_BUSY   (1u<<4)

/* Weak UART shims so this builds even without your uart.c */
__attribute__((weak)) void uart_puts(const char* s){ (void)s; }
__attribute__((weak)) void uart_puthex(unsigned x){
    (void)x;
}

void irq_handler(void)
{
    /* Read and clear MAC interrupt source */
    unsigned src = eth_readl(ETH_INT_SOURCE);
    if (src) eth_writel(src, ETH_INT_SOURCE); /* W1C */

    /* RX handling: drain a few frames */
    if (src & INT_RXF){
        unsigned len;
        /* In a real ISR you would push into a queue; here we just drain */
        for (int i=0; i<4; ++i){
            if (eth_rx_poll(0, &len) == 1){
                uart_puts("eth: RX frame, len=");
                uart_puthex(len);
                uart_puts("\n");
            } else {
                break;
            }
        }
    }

    /* TX complete */
    if (src & INT_TXB){
        uart_puts("eth: TX complete\n");
    }
    if (src & INT_TXE){
        uart_puts("eth: TX error\n");
    }
}
