#include "ethmac_zap.h"
#include <string.h>

/* ------------ MII management (MDIO) ------------ */
static inline void mdio_wait_idle(void){
    while (eth_readl(ETH_MIICOMMAND) & (MIICOMMAND_RSTAT | MIICOMMAND_WCTRLDATA)) { /* spin */ }
}

// MDC <= 2.5 MHz. For many OC drops: MDC = SYS / (2*(CLKDIV+1))
static inline uint32_t mdio_clkdiv(uint32_t sys_hz){
    uint32_t target = 2500000u;
    uint32_t div = (sys_hz/(2*target));
    if (div) div -= 1;
    if (div > 0xFF) div = 0xFF;
    return div;
}

static void mdio_init(void){
    eth_writel(mdio_clkdiv(SYS_CLK_HZ), ETH_MIIMODER);
}

int eth_mdio_write(uint8_t phy, uint8_t reg, uint16_t val){
    mdio_wait_idle();
    eth_writel(((uint32_t)phy << MIIADDR_PHY_SHIFT) | ((uint32_t)reg << MIIADDR_REG_SHIFT), ETH_MIIADDRESS);
    eth_writel(val, ETH_MIITX_DATA);
    eth_writel(MIICOMMAND_WCTRLDATA, ETH_MIICOMMAND);
    mdio_wait_idle();
    return 0;
}

int eth_mdio_read(uint8_t phy, uint8_t reg){
    mdio_wait_idle();
    eth_writel(((uint32_t)phy << MIIADDR_PHY_SHIFT) | ((uint32_t)reg << MIIADDR_REG_SHIFT), ETH_MIIADDRESS);
    eth_writel(MIICOMMAND_RSTAT, ETH_MIICOMMAND);
    mdio_wait_idle();
    return (int)(eth_readl(ETH_MIIRX_DATA) & 0xFFFF);
}

/* ------------ PHY helpers for DP83848J ------------ */
static int phy_read(unsigned reg){ return eth_mdio_read(PHY_ADDR, reg); }
static int phy_write(unsigned reg, unsigned val){ return eth_mdio_write(PHY_ADDR, reg, val); }

static int phy_wait_link(unsigned timeout_ms){
    // Enable and restart autoneg
    int bmcr = phy_read(PHY_BMCR);
    phy_write(PHY_BMCR, (bmcr | BMCR_AN_ENABLE | BMCR_RESTART_AN) & ~BMCR_RESET);

    for (unsigned t=0;t<timeout_ms;t++){
        (void)phy_read(PHY_BMSR);                    // latch-clear
        int b = phy_read(PHY_BMSR);
        if ((b & BMSR_AN_COMPLETE) && (b & BMSR_LINK_STATUS))
            return 0;
        // TODO: platform sleep 1 ms if available
        // zap_sleep_ms(1);
    }
    return -1;
}

// Returns 1 if full duplex, 0 otherwise
static int phy_full_duplex(void){
    // DP83848J: PHYSTS bit2 = DUPLEX (1=Full)
    int st = phy_read(PHY_PHYSTS);
    return (st >> 2) & 1;
}

/* ------------ MAC config ------------ */
static void eth_set_mac(const uint8_t mac[6]){
    uint32_t lo = (mac[3]) | (mac[2]<<8) | (mac[1]<<16) | (mac[0]<<24);
    uint32_t hi = (mac[5]) | (mac[4]<<8);
    eth_writel(lo, ETH_MAC_ADDR0);
    eth_writel(hi, ETH_MAC_ADDR1);
}

static void eth_config_defaults(void){
    eth_writel(0x12, ETH_IPGT);                      // IFG
    eth_writel(0x0C, ETH_IPGR1);
    eth_writel(0x12, ETH_IPGR2);
    eth_writel((64u<<16) | 1518u, ETH_PACKETLEN);    // min/max frame
    eth_writel(ETH_TX_BD_NUM, ETH_TX_BD_NUM_REG);    // first N BDs TX
}

static void eth_init_bds(void){
    // Zero all BDs
    for (unsigned i=0;i<ETH_BD_COUNT;i++){ BD(i)->stat = 0; BD(i)->ptr = 0; }
    // Mark wrap bits (last TX and last RX descriptors)
    BD(ETH_TX_BD_NUM-1)->stat = BD_WRAP;           // TX wrap
    BD(ETH_BD_COUNT-1)->stat |= BD_WRAP;           // RX wrap

    // Initialize RX descriptors to EMPTY with buffers
    const unsigned RX_START = ETH_TX_BD_NUM;
    const unsigned RX_COUNT = ETH_BD_COUNT - ETH_TX_BD_NUM;
    unsigned offs = 0;
    const unsigned rx_buf_size = 2048; // adjust
    for (unsigned i=0;i<RX_COUNT;i++){
        uintptr_t buf = ETH_DMA_MEM_BASE + offs;
        BD(RX_START+i)->ptr  = (uint32_t)buf;
        BD(RX_START+i)->stat = (BD(RX_START+i)->stat & BD_WRAP) | BD_IRQ | BD_E_R; // EMPTY=1
        offs += rx_buf_size;
    }
}

//Same function can be used for both Tx and Rx ...
static inline void eth_set_bd(unsigned index, uint16_t length, uint16_t flags, uint32_t payload_addr) {
    volatile uint32_t *bd = (volatile uint32_t *)(ETH_BD_BASE + (index * 8u));
    uint32_t status = ((uint32_t)length << 16) | (uint32_t)flags;

    bd[1] = (uint32_t)payload_addr;          // payload pointer word (address)
    bd[0] = status;                          // status/length word
}

//For Repeat transactions we only need to set ready bit. Hence writing to offset 0.
void eth_set_bd_addr0(unsigned index, uint16_t length, uint16_t flags, uint32_t payload_addr) {
    volatile uint32_t *bd = (volatile uint32_t *)(ETH_BD_BASE + (index * 8u));
    uint32_t status = ((uint32_t)length << 16) | (uint32_t)flags;

    bd[0] = status;                          // status/length word
}

void eth_rx_init_ring(void) {
  //TX_BD_NUM
  //eth_writel(64, ETH_TX_BD_NUM_REG);    // first 0x40(64) BDs TX i.e. remaining 0x40(64) BDs for RX

  //Enable RX
  //eth_writel((MODER_RXEN | MODER_FULLD | MODER_IFG | MODER_PRO | MODER_BRO), ETH_MODER);

  uint32_t len = eth_readl(ETH_PACKETLEN);
  uint16_t max_len = (uint16_t)(len & 0xFFFF);
  uint16_t min_len = (uint16_t)((len >> 16) & 0xFFFF);

  //RX BD ...
  uint16_t i_length = (min_len - 4); 

  uint16_t flags = 0;
  flags |= BD_E_R; //E=1 i.e. ready to receive data ...
  flags |= BD_IRQ; //1= When data is received, an RXF interrupt will be generated ...
  flags |= BD_WRAP; //1= this BD is the last ...

  //Set Buffer Descriptor
  (void)eth_set_bd(64, i_length, flags, ETHMAC_RX_BUF_RAM_BASE); //Rx Data Buffer located at BASE + 4K
}

/* ------------ Public API ------------ */
int eth_init(const uint8_t mac[6]){
    // Disable MAC
    eth_writel(0, ETH_MODER);

    // MDIO
    mdio_init();

    // PHY bring-up
    (void)phy_wait_link(3000);

    // Program MAC + BDs
    eth_set_mac(mac);
    eth_config_defaults();
    //eth_init_bds();

    eth_rx_init_ring();

    //Unmask Interrupts ...
    eth_writel((ETH_INT_TXB | ETH_INT_TXE | ETH_INT_RXB | ETH_INT_RXE | ETH_INT_BUSY | ETH_INT_TXC | ETH_INT_RXC), ETH_INT_MASK);

    // Duplex from PHY
    uint32_t m = eth_readl(ETH_MODER);
    if (phy_full_duplex()) m |= MODER_FULLD; else m &= ~MODER_FULLD;
    m |= (MODER_RXEN | MODER_TXEN | MODER_FULLD | MODER_PRO | MODER_BRO | MODER_PAD | MODER_CRCEN);
    //m |= (MODER_RXEN | MODER_TXEN | MODER_FULLD | MODER_PAD | MODER_CRCEN);
    eth_writel(m, ETH_MODER);
    return 0;
}

// Enqueue a TX buffer (blocking; picks first free BD)
/*
int eth_tx_enqueue(const void* buf, unsigned len){
    dcache_clean_range((void*)buf, len);

    for (unsigned i=0;i<ETH_TX_BD_NUM;i++){
        uint32_t st = BD(i)->stat;
        if ((st & BD_E_R)==0){ // READY==0 → free
            BD(i)->ptr  = (uint32_t)buf;  // physical address expected
            BD(i)->stat = (st & BD_WRAP) | BD_IRQ | BD_TX_PAD | BD_TX_CRC | BD_E_R | (len & BD_LEN_MASK);
            return 0;
        }
    }
    return -1; // no free TX descriptor
}

static inline void write_payload_to_bufram32(const uint8_t *src, unsigned len)
{
    volatile uint32_t *dst = (volatile uint32_t *)ETHMAC_BUF_RAM_BASE;
    unsigned i = 0;
    while (i < len) {
        uint32_t word = 0;
        for (int b = 0; b < 4 && i < len; b++, i++)
            word |= ((uint32_t)src[i]) << (b * 8);
        *dst++ = word;
    }
}
*/

static inline void write_payload_to_bufram32_be(const uint8_t *src, unsigned len)
{
    volatile uint32_t *dst = (volatile uint32_t *)ETHMAC_BUF_RAM_BASE;
    unsigned i = 0;

    while (i < len) {
        uint32_t word = 0;
        for (int b = 0; b < 4 && i < len; b++, i++)
            word |= ((uint32_t)src[i]) << ((3 - b) * 8);  // <-- reverse order
        *dst++ = word;
    }
}

int eth_tx_enqueue(const void* buf, unsigned buf_len) {
  //Write Payload data to buffer ram ...
  write_payload_to_bufram32_be(buf, buf_len);

  //TX_BD_NUM
  //eth_writel(ETH_TX_BD_NUM, ETH_TX_BD_NUM_REG);    // first N BDs TX

  //Unmask Interrupts ...
  //eth_writel((ETH_INT_TXB | ETH_INT_TXE | ETH_INT_RXB | ETH_INT_RXE | ETH_INT_BUSY | ETH_INT_TXC | ETH_INT_RXC), ETH_INT_MASK);

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

  //Set Buffer Descriptor
  (void)eth_set_bd(0, i_length, flags, ETHMAC_BUF_RAM_BASE);

  //Set WR bit to 1 in TXBD ...
  //uint32_t m = eth_readl();

  //uint32_t m = (MODER_RXEN | MODER_TXEN | MODER_PRO | MODER_BRO | MODER_PAD | MODER_FULLD | MODER_CRCEN);
  //uint32_t m = (MODER_TXEN | MODER_PAD | MODER_FULLD | MODER_CRCEN);
  //eth_writel(m, ETH_MODER);

  return 0;
}

/*
// Poll for one RX frame; copies into out_buf if provided.
// Return: 1 if a frame delivered, 0 if none, <0 on error.
int eth_rx_poll(void* out_buf, unsigned* out_len){
    for (unsigned i=ETH_TX_BD_NUM;i<ETH_BD_COUNT;i++){
        uint32_t st = BD(i)->stat;
        if ((st & BD_E_R)==0){ // EMPTY==0 → filled by MAC
            unsigned len = st & BD_LEN_MASK;
            dcache_inval_range((void*)BD(i)->ptr, len);
            if (out_len) *out_len = len;
            if (out_buf) memcpy(out_buf, (void*)BD(i)->ptr, len);
            // hand BD back to MAC
            ;BD(i)->stat = (st & BD_WRAP) | BD_IRQ | BD_E_R;
            return 1;
        }
    }
    return 0;
}
*/

int eth_rx_poll(unsigned index, void* out_buf, unsigned* out_len){
    uint32_t st = BD(index)->stat;
    if ((st & BD_E_R)==0){ // EMPTY==0 → filled by MAC
        unsigned len = st & BD_LEN_MASK;
        dcache_inval_range((void*)BD(index)->ptr, len);
        if (out_len) *out_len = len;
        if (out_buf) memcpy(out_buf, (void*)BD(index)->ptr, len);
        // hand BD back to MAC
        BD(index)->stat = (st & BD_WRAP) | BD_IRQ | BD_E_R;
        return 1;
    }
    return 0;
}
