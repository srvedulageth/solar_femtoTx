// ethmac_irq.c — EthMAC ISR helper (no top-level irq_handler here)
#include "ethmac_zap.h"
#include "uart.h"   // for UARTWrite()

/* If your ethmac_defines differ, adjust the bits: */
#define INT_TXB  (1u<<0)
#define INT_TXE  (1u<<1)
#define INT_RXF  (1u<<3)

static void uart_puts(const char* s){ UARTWrite((char*)s); }
static void uart_puthex(unsigned x){
  static const char h[]="0123456789ABCDEF";
  char buf[11]; buf[0]='0'; buf[1]='x';
  for (int i=0;i<8;i++) buf[2+i]=h[(x>>(28-4*i))&0xF];
  buf[10]=0; UARTWrite(buf);
}

/* Call this from your existing uart.c irq_handler() when ETH IRQ is pending */
void eth_irq_handler(void)
{
    unsigned src = eth_readl(ETH_INT_SOURCE);
    if (!src) return;

    /* Clear (W1C) */
    eth_writel(src, ETH_INT_SOURCE);

    if (src & INT_RXF) {
        unsigned len;
        for (int i=0;i<4;i++){
            if (eth_rx_poll(0, &len) == 1){
                uart_puts("eth: RX len=");
                uart_puthex(len);
                uart_puts("\n");
            } else break;
        }
    }
    if (src & INT_TXB) uart_puts("eth: TX complete\n");
    if (src & INT_TXE) uart_puts("eth: TX error\n");
}
