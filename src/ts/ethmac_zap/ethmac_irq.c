// ethmac_irq.c — EthMAC ISR helper (no top-level irq_handler here)
#include "ethmac_zap.h"
#include "uart.h"   // for UARTWrite()

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

    if (src & (INT_RXB | INT_RXE)) {
       rx_poll_scheduled = 1;  // schedule bottom-half
    }

    if (src & (INT_TXB | INT_TXE)) {
      if (src & INT_TXB) uart_puts("eth: TX complete\r\n");
      if (src & INT_TXE) uart_puts("eth: TX error\r\n");
    }

    eth_writel(src, ETH_INT_SOURCE);
}
