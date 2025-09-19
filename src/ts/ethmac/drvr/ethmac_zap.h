#pragma once
// ethmac_zap.h — OpenCores EthMAC driver (Wishbone) for ZAP ARM
// Board: Arty A7 + DP83848J PHY (MII, PHY addr = 1)
// Author: <you>
// Notes:
//  - This driver assumes the OpenCores EthMAC classic register map with 32‑bit word spacing.
//  - Buffer Descriptors (BDs) are in the MAC's slave window at ETH_BD_BASE (see macro below).
//  - The MAC masters Wishbone to access actual packet buffers in system RAM (ETH_DMA_MEM_BASE).

#include <stdint.h>

/* ================= Platform glue (EDIT THESE) ================= */

// EthMAC Wishbone slave base (your map: 0xFFFF_E000 .. 0xFFFF_EFFF)
#define ETH_BASE            0xFFFFE000u

// BD RAM base inside the same window. Two common options:
#define ETH_BD_BASE         (ETH_BASE + 0x0400u)   // common wrapper (BDs inside 4KB)
/* Alternatively, if your wrapper uses OC's historical word-index 0x400:
   #define ETH_BD_BASE     (ETH_BASE + 0x1000u)    // 0x400 << 2
*/

// Descriptor counts (2 KB BD RAM / 8 B per BD ⇒ up to 256 BDs)
#define ETH_BD_COUNT        8u
#define ETH_TX_BD_NUM       2u    // first N are TX, remaining are RX

// System RAM (packet buffers) accessible by EthMAC Wishbone master
#define ETH_DMA_MEM_BASE    0x0A000000u   // TODO: set to a valid uncached/phys region
#define ETH_DMA_MEM_SIZE    0x2000u    // 1 MiB example

// CPU clock (for MDIO divisor)
#define SYS_CLK_HZ          100000000u    // 100 MHz

// PHY details (Arty A7 default DP83848J)
#define PHY_ADDR            1u            // DP83848J strapping on Arty A7
#define MII_MODE            1             // 1=MII, 0=RMII

// IRQ number (hook to your ZAP vector table)
#define ETH_IRQ_NUM         2            // TODO: set actual

// Cache maintenance (no-ops by default)
static inline void dcache_clean_range(void* p, unsigned len){ (void)p; (void)len; }
static inline void dcache_inval_range(void* p, unsigned len){ (void)p; (void)len; }

/* ================= MMIO helpers ================= */
static inline void eth_writel(uint32_t v, uintptr_t a){ *(volatile uint32_t*)a = v; }
static inline uint32_t eth_readl(uintptr_t a){ return *(volatile uint32_t*)a; }

/* ================= Register indices (32-bit word spaced) ================= */
#define ETH_REG(idx)         (ETH_BASE + ((idx) << 2))

#define ETH_MODER            ETH_REG(0x00)  // Mode
#define ETH_INT_SOURCE       ETH_REG(0x01)
#define ETH_INT_MASK         ETH_REG(0x02)
#define ETH_IPGT             ETH_REG(0x03)
#define ETH_IPGR1            ETH_REG(0x04)
#define ETH_IPGR2            ETH_REG(0x05)
#define ETH_PACKETLEN        ETH_REG(0x06)
#define ETH_COLLCONF         ETH_REG(0x07)
#define ETH_TX_BD_NUM_REG    ETH_REG(0x08)
#define ETH_CTRLMODER        ETH_REG(0x09)
#define ETH_MIIMODER         ETH_REG(0x0A)
#define ETH_MIICOMMAND       ETH_REG(0x0B)
#define ETH_MIIADDRESS       ETH_REG(0x0C)
#define ETH_MIITX_DATA       ETH_REG(0x0D)
#define ETH_MIIRX_DATA       ETH_REG(0x0E)
#define ETH_MIISTATUS        ETH_REG(0x0F)
#define ETH_MAC_ADDR0        ETH_REG(0x10)  // low 32 bits
#define ETH_MAC_ADDR1        ETH_REG(0x11)  // high 16 bits in low half

/* ================= MODER bits (common OC EthMAC) ================= */
#define MODER_RXEN           (1u<<0)
#define MODER_TXEN           (1u<<1)
#define MODER_PAD            (1u<<2)
#define MODER_CRCEN          (1u<<3)
#define MODER_FULLD          (1u<<10)
#define MODER_PRO            (1u<<11)

/* ================= MII management ================= */
#define MIICOMMAND_RSTAT      (1u<<1)
#define MIICOMMAND_WCTRLDATA  (1u<<2)

#define MIIADDR_PHY_SHIFT     0
#define MIIADDR_REG_SHIFT     8

/* ================= PHY (DP83848J) registers ================= */
#define PHY_BMCR              0x00
#define PHY_BMSR              0x01
#define PHY_ID1               0x02
#define PHY_ID2               0x03
#define PHY_ANAR              0x04
#define PHY_ANLPAR            0x05
#define PHY_PHYSTS            0x10   // DP83848: status (link/duplex/speed)

// BMCR bits
#define BMCR_RESET            (1u<<15)
#define BMCR_AN_ENABLE        (1u<<12)
#define BMCR_RESTART_AN       (1u<<9)

// BMSR bits
#define BMSR_100B_T_FULL      (1u<<14)
#define BMSR_100B_T_HALF      (1u<<13)
#define BMSR_10B_T_FULL       (1u<<12)
#define BMSR_10B_T_HALF       (1u<<11)
#define BMSR_AN_COMPLETE      (1u<<5)
#define BMSR_LINK_STATUS      (1u<<2)

/* ================= Buffer Descriptors ================= */
typedef struct {
    volatile uint32_t stat;   // control/status + length (low bits)
    volatile uint32_t ptr;    // buffer pointer (physical)
} eth_bd_t;

#define BD(i)                 ((eth_bd_t*)(ETH_BD_BASE) + (i))

// Common EthMAC BD bits (names vary; adjust if your drop differs)
#define BD_WRAP               (1u<<13)
#define BD_IRQ                (1u<<14)
#define BD_E_R                (1u<<15)   // RX: EMPTY (1=owned by MAC), TX: READY (1=start TX)
#define BD_TX_PAD             (1u<<12)
#define BD_TX_CRC             (1u<<11)
#define BD_LEN_MASK           0x7FFu     // length field bits (typical 11-bit)

/* ================= Public API ================= */
int  eth_init(const uint8_t mac[6]);
int  eth_tx_enqueue(const void* buf, unsigned len);
int  eth_rx_poll(void* out_buf, unsigned* out_len);

// Optional helpers if you want to expose MDIO
int  eth_mdio_write(uint8_t phy, uint8_t reg, uint16_t val);
int  eth_mdio_read(uint8_t phy, uint8_t reg);
