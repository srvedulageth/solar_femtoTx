// ethmac_demo.c — init + optional polling helpers for EthMAC demo
#include <stdint.h>
#include <stdint.h>
#include "uart.h"
#include "ethmac_zap.h"

// Tweak as needed (rough spin-loop timeout)
#define TX_TIMEOUT_ITERS  (1000000u)
#define TX_REPEAT_COUNT   (20u)
#define TX_BD_IDX 0 // Assume you used TX BD index 0

static inline void small_delay(void) {
    // cheap backoff (optional)
    for (volatile unsigned k = 0; k < 262144; ++k) __asm__ volatile("" ::: "memory");
}

static inline volatile uint32_t* tx_bd(void) {
    return (volatile uint32_t *)(ETH_BD_BASE + TX_BD_IDX*8);
}

// Initialize EthMAC with a fixed MAC address
void eth_demo_init(void)
{
    const unsigned char mac[6] = {0x02,0x12,0x34,0x56,0x78,0x9A};
#ifdef DEBUG_2
    uart_puts("eth: init\r\n");
#endif
    eth_init(mac);
#ifdef DEBUG_2
    uart_puts("eth: init done\r\n");
#endif
}

// put this near your other helpers
void eth_print_phy_status(void)
{
    int bmcr  = eth_mdio_read(PHY_ADDR, 0x00);  // BMCR
    int bmsr1 = eth_mdio_read(PHY_ADDR, 0x01);  // BMSR (1st read latches)
    int bmsr2 = eth_mdio_read(PHY_ADDR, 0x01);  // BMSR again (actual)
    int physts= eth_mdio_read(PHY_ADDR, 0x10);  // DP83848J PHYSTS

    uart_puts("phy: BMCR=0x"); uart_puthex(bmcr);  uart_puts("\r\n");
    uart_puts("phy: BMSR=0x"); uart_puthex(bmsr2); uart_puts("\r\n");
    uart_puts("phy: PHYSTS=0x"); uart_puthex(physts); uart_puts("\r\n");

    int link   = (bmsr2 & (1<<2)) ? 1 : 0;
    int full   = (physts >> 2) & 1;
    int speed  = (physts >> 1) & 1 ? 100 : 10;

    uart_puts("phy: link="); uart_puthex(link);
    uart_puts(" speed="); uart_puthex(speed);
    uart_puts(" duplex="); uart_puts(full ? "full\r\n" : "half\r\n");
}

void phy_hw_reset(void){
    // If your eth_rstn is on a GPIO, toggle it here.
    // Otherwise, use BMCR reset:
    int bmcr = eth_mdio_read(PHY_ADDR, 0x00);
    (void)bmcr;
    eth_mdio_write(PHY_ADDR, 0x00, 1u<<15);   // BMCR_RESET
    // poll until reset clears
    for (int i=0;i<1000;i++){
        int v = eth_mdio_read(PHY_ADDR, 0x00);
        if ((v & (1u<<15)) == 0) break;
    }
}

void phy_verify(int pa){
    int id1 = eth_mdio_read(pa, 0x02);   // PHYIDR1 (expect ~0x2000)
    int id2 = eth_mdio_read(pa, 0x03);   // PHYIDR2 (expect 0x5C90 for DP83848)
    // BMSR must be read twice
    (void)eth_mdio_read(pa, 0x01);
    int bmsr = eth_mdio_read(pa, 0x01);
    int physts = eth_mdio_read(pa, 0x10);

    uart_puts("verify pa="); uart_puthex(pa); uart_puts("\r\n");
    uart_puts("  ID1="); uart_puthex(id1); uart_puts(" ID2="); uart_puthex(id2); uart_puts("\r\n");
    uart_puts("  BMSR="); uart_puthex(bmsr); uart_puts(" PHYSTS="); uart_puthex(physts); uart_puts("\r\n");
}

// hammer PHY over MDIO so ILA can see activity
void mdio_burner(int pa) {
    for (int i = 0; i < 10; i++) {
        uart_puts("mdio_burner: Reading BMSR and Writing BMCR ...\r\n");
        (void)eth_mdio_read(pa, 0x01);       // BMSR read (causes MDIO read cycle)
        eth_mdio_write(pa, 0x00, 0x1200);    // BMCR write (AN enable) → write cycle
    }
}

void phy_scan_all(void){
    for (int pa=0; pa<32; pa++){
        int id1 = eth_mdio_read(pa, 0x02);
        int id2 = eth_mdio_read(pa, 0x03);
        if (id1 > 0 && id1 != 0xFFFF){
            uart_puts("phy@"); uart_puthex(pa);
            uart_puts(" ID1=0x"); uart_puthex(id1);
            uart_puts(" ID2=0x"); uart_puthex(id2);
            uart_puts("\r\n");
        }
    }
}

void phy_autoneg_and_wait(void){
    // Enable + restart AN
    int bmcr = eth_mdio_read(PHY_ADDR, 0x00);
    eth_mdio_write(PHY_ADDR, 0x00, (bmcr | (1u<<12) | (1u<<9)) & ~(1u<<15));

    // BMSR must be read twice (latch)
    for (int t=0; t<3000; t++){  // ~3s spin
        (void)eth_mdio_read(PHY_ADDR, 0x01);
        int bmsr = eth_mdio_read(PHY_ADDR, 0x01);
        if ((bmsr & (1u<<2)) && (bmsr & (1u<<5))){ // link up + AN complete
            int physts = eth_mdio_read(PHY_ADDR, 0x10);
            int full = (physts>>2) & 1;
            int sp100 = (physts>>1) & 1;
            uart_puts("phy: LINK UP ");
            uart_puts(sp100 ? "100" : "10");
            uart_puts(full ? " full\r\n" : " half\r\n");
            return;
        }
    }
    uart_puts("phy: link timeout\r\n");
}

static int wait_tx_bd_done(void) {
    uint32_t iters = 0;
    for (;;) {
        uint32_t st = tx_bd()[0];                 // status/len
        if ((st & BD_E_R) == 0) {                 // Ready cleared → TX completed
            if (st & (BD_TX_UR | BD_TX_RL | BD_TX_LC | BD_TX_CS))  // use your core’s TX error bits
                return -1;                        // error
            return 0;                             // success
        }
        if (++iters >= TX_TIMEOUT_ITERS) return -2; // timeout
        small_delay();
    }
}

void eth_transmit(void) {
    static const uint8_t test_frame[] = {
        0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,   // dst: broadcast
        0x02,0x12,0x34,0x56,0x78,0x9A,   // src: your MAC
        0x08,0x00,                       // EtherType IPv4 (example)
        0xDE,0xAD,0xBE,0xEF,0xCA,0xFE,
        0xBA,0xBE,0x00,0x01,0x02,0x03,
        0x04,0x05,0x06,0x07,0x08,0x09,
        0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,
        0x1A,0x1B,0x1C,0x1D,0x1E,0x1F,
        0x2A,0x2B,0x2C,0x2D,0x2E,0x2F,
        0x3A,0x3B,0x3C,0x3D,0x3E,0x3F,
        0x4A,0x4B,0x4C,0x4D,0x4E,0x4F
    };

    const uint32_t tx_done_mask = ETH_INT_TXB | ETH_INT_TXE;
    int r;
    unsigned tx_count = 0;
    uint32_t len = eth_readl(ETH_PACKETLEN);
    uint16_t max_len = (uint16_t)(len & 0xFFFF);
    uint16_t min_len = (uint16_t)((len >> 16) & 0xFFFF);

    //TX BD ...
    uint16_t i_length = (min_len - 4); 

    uint16_t flags = 0;
    flags |= (1u << 15); //rd ready
    flags |= (1u << 14); //irq en
    flags |= (1u << 13); //wrap set to 1 => this buffer descriptor is the last ...
    flags |= (1u << 12); //pad padding en
    flags |= (1u << 11); //crc append crc

    //for (tx_count = 0; tx_count < TX_REPEAT_COUNT; ++tx_count) {
    while(1) {
        // Clear stale interrupts
        //eth_writel(tx_done_mask, ETH_INT_SOURCE);

        // Queue frame
        if(tx_count == 0) {
          r = eth_tx_enqueue(test_frame, sizeof(test_frame));
        }
        else {
          (void) eth_set_bd_addr0(0, i_length, flags);
        }

        tx_count++;
        //int rc = wait_tx_bd_done();
        small_delay(); small_delay(); small_delay(); small_delay();

        //for( ;; ) __asm__ volatile("" ::: "memory");
    }
}
