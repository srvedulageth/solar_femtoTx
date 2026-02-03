// ethmac_irq.c — EthMAC ISR helper (no top-level irq_handler here)
#include "ethmac_zap.h"
#include "uart.h"   // for UARTWrite()
#include "rx_queue.h"

/* If your ethmac_defines differ, adjust the bits: */
#define INT_TXB  (1u<<0)
#define INT_TXE  (1u<<1)
#define INT_RXB  (1u<<2)
#define INT_RXE  (1u<<3)

/* Call this from your existing uart.c irq_handler() when ETH IRQ is pending */
void eth_irq_handler(void)
{
    unsigned src = 0;
    src = eth_readl(ETH_INT_SOURCE);

    if (!src) return;

    /* Clear (W1C) */
    //eth_writel(src, ETH_INT_SOURCE);

    //uart_puts("eth: Int Src=");
    //uart_puthex(src);
    //uart_puts("\r\n");

    if (src & (INT_RXB | INT_RXE)) {
/*
        unsigned len;
        for (int k=0; k<4; ++k) {
           if (eth_rx_poll_1(0, &len) == 1) {
               //debug_rx_bd(64, len);
               //uart_puts("eth: RX len=");
               //uart_puthex(len);
               //uart_puts("\r\n");
           } //else break;
       }
*/
       rx_drain_isr(8);  // drain a few to keep up; tune as needed
       eth_writel(src, ETH_INT_SOURCE); //W1C Clear interrupt
    }

/*
    if (src & INT_TXB) {
       //Read MODER ...
       unsigned moder = eth_readl(ETH_MODER);
       moder &= ~MODER_TXEN;
       eth_writel(moder, ETH_MODER);
    }

    if (src & INT_TXB) uart_puts("eth: TX complete\r\n");
    if (src & INT_TXE) uart_puts("eth: TX error\r\n");
*/
}
