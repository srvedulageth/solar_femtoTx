// net_minip.c — tiny LAN stack for OpenCores EthMAC
#include <stdint.h>
#include <string.h>   // for memset if you link it; else hand-roll
#include "ethmac_zap.h"
#include "eth_structs.h"
#include "uart.h"

// ---------------- CONFIG ----------------
static const uint8_t MY_MAC[6] = {0x02,0x12,0x34,0x56,0x78,0x9A};
#define MY_IP   0xC0A80114u   // 192.168.1.20
#define PC_IP   0xC0A8010Au   // 192.168.1.10 (your Windows box)
// ----------------------------------------

// Helpers (endianness)
static inline uint16_t bswap16(uint16_t x){ return (uint16_t)((x<<8)|(x>>8)); }
static inline uint32_t bswap32(uint32_t x) {
    return ((x & 0x000000FFu) << 24) |
           ((x & 0x0000FF00u) <<  8) |
           ((x & 0x00FF0000u) >>  8) |
           ((x & 0xFF000000u) >> 24);
}
static inline uint16_t htons(uint16_t x){ return bswap16(x); }
static inline uint16_t ntohs(uint16_t x){ return bswap16(x); }
static inline uint32_t htonl(uint32_t x){
    return ((x&0x000000FFu)<<24)|((x&0x0000FF00u)<<8)|((x&0x00FF0000u)>>8)|((x&0xFF000000u)>>24);
}
static inline uint32_t ntohl(uint32_t x){ return htonl(x); }
static inline uint16_t ntohs16(uint16_t x){ return bswap16(x); }
static inline uint32_t ntohl32(uint32_t x){ return bswap32(x); }

static inline uint16_t load_ethertype(const void *base) {
/*
    const uint8_t *p = (const uint8_t*)base;
    // On wire: p[12] = high, p[13] = low (network order)
    //uint16_t net = ((uint16_t)p[12] << 8) | p[13];
    uint16_t net = ((uint16_t)p[15] << 8) | p[14];
*/

    const uint32_t *p = (const uint32_t *)((const uint8_t *)base + 12);
    uint32_t temp = *p; //Reading from Base + 'h C
    uint8_t byte3 = (temp >> 24) & 0xFF; uint8_t byte2 = (temp >> 16) & 0xFF;
    uint16_t net = ((uint16_t)byte3 << 8) | byte2;

    return net;                // this is already in network order
}

// Checksums (RFC 1071)
static uint16_t csum16(const void* data, unsigned len){
    const uint8_t* p = (const uint8_t*)data;
    uint32_t sum = 0;
    while (len > 1){ sum += ((uint16_t)p[0]<<8) | p[1]; p+=2; len-=2; }
    if (len) sum += ((uint16_t)p[0]<<8);
    while (sum>>16) sum = (sum & 0xFFFF) + (sum>>16);
    return (uint16_t)~sum;
}
static uint16_t csum16_add(uint32_t sum, const void* data, unsigned len){
    const uint8_t* p = (const uint8_t*)data;
    while (len > 1){ sum += ((uint16_t)p[0]<<8) | p[1]; p+=2; len-=2; }
    if (len) sum += ((uint16_t)p[0]<<8);
    while (sum>>16) sum = (sum & 0xFFFF) + (sum>>16);
    return (uint16_t)sum;
}
static uint16_t csum16_finalize(uint32_t sum){
    while (sum>>16) sum = (sum & 0xFFFF) + (sum>>16);
    return (uint16_t)~sum;
}

// ICMP
#define IPPROTO_ICMP 1
#define ICMP_ECHO_REQUEST 8
#define ICMP_ECHO_REPLY   0

// UDP
#define IPPROTO_UDP 17

static inline void arp_load_info(const void *arp_base, struct arp_pkt_t *out) {
    const volatile uint32_t *src = (const volatile uint32_t*)arp_base;

    // Read 8 words so we get full TPA (C0A80114)
    uint32_t w0 = src[0]; // 0x08060001  -> [08][06][00][01]
    uint32_t w1 = src[1]; // 0x08000604  -> [08][00][06][04]
    uint32_t w2 = src[2]; // 0x0001A4BB  -> [00][01][A4][BB]
    uint32_t w3 = src[3]; // 0x6D52E453  -> [6D][52][E4][53]
    uint32_t w4 = src[4]; // 0xC0A8010A  -> [C0][A8][01][0A]
    uint32_t w5 = src[5]; // 0x00000000  -> [00][00][00][00]
    uint32_t w6 = src[6]; // 0x0000C0A8  -> [00][00][C0][A8]
    uint32_t w7 = src[7]; // should contain last two bytes of TPA (0x0114....)

    // Interpret words as big-endian byte packs:
    // High 16 bits of w0 are EtherType (0x0806), low 16 bits are htype (0x0001)
    uint16_t htype_net = (uint16_t)(w0 & 0xFFFF);
    uint16_t ptype_net = (uint16_t)(w1 >> 16);

    uint8_t hlen = (uint8_t)((w1 >> 8) & 0xFF);   // 0x06
    uint8_t plen = (uint8_t)(w1 & 0xFF);         // 0x04

    //uint16_t oper_net = (uint16_t)(w2 >> 16);    // 0x0001
    uint16_t oper_net = (uint16_t)(w2 & 0xFFFF);    // 0x0001

    // Sender MAC (sha): A4 BB 6D 52 E4 53
    out->sha[0] = (uint8_t)((w2 >> 8) & 0xFF);   // A4
    out->sha[1] = (uint8_t)(w2 & 0xFF);         // BB
    out->sha[2] = (uint8_t)(w3 >> 24);          // 6D
    out->sha[3] = (uint8_t)(w3 >> 16);          // 52
    out->sha[4] = (uint8_t)(w3 >> 8);           // E4
    out->sha[5] = (uint8_t)(w3 & 0xFF);         // 53

    // Sender IP: w4 already holds 0xC0A8010A in network order
    uint32_t spa_net = w4;

    // Target MAC (tha): 6 bytes, here all zero in your capture
    out->tha[0] = (uint8_t)(w5 >> 24);          // 00
    out->tha[1] = (uint8_t)(w5 >> 16);          // 00
    out->tha[2] = (uint8_t)(w5 >> 8);           // 00
    out->tha[3] = (uint8_t)(w5 & 0xFF);         // 00
    out->tha[4] = (uint8_t)(w6 >> 24);          // 00
    out->tha[5] = (uint8_t)(w6 >> 16);          // 00

    // Target IP (tpa): C0 A8 01 14
    // From pattern: low 16 bits of w6 are C0A8, high 16 bits of w7 are 0114
    //uint32_t tpa_net = ((w6 & 0x0000FFFFu) << 16) | (w7 >> 16);
    uint32_t tpa_net = ((w6 & 0xFFFF0000u)  | (w7 & 0x0000FFFF));

    // Convert everything to host-endian fields in out:
    out->htype = ntohs16(htype_net);   // 0x0001
    out->ptype = ntohs16(ptype_net);   // 0x0800
    out->hlen  = hlen;                 // 6
    out->plen  = plen;                 // 4
    //out->oper  = ntohs16(oper_net);    // 1 (request)
    out->oper  = oper_net;    // 1 (request)

    out->spa   = ntohl32(spa_net);     // host-endian 192.168.1.10
    //out->tpa   = ntohl32(tpa_net);     // host-endian 192.168.1.20
    out->tpa   = tpa_net;     // host-endian 192.168.1.20
}

static uint8_t rx_buf[2048];

// Transmit helper
static int eth_send(const void* buf, unsigned len){
    // If your cache needs cleaning, do it here
    return eth_tx_enqueue(buf, len);
}

// ---------------- ARP ----------------
static void send_arp_reply(const uint8_t req_src_mac[6], uint32_t req_spa, uint32_t req_tpa){
    uint8_t pkt[64];
    struct eth_hdr_t* eth = (struct eth_hdr_t*)pkt;
    struct arp_pkt_t* arp = (struct arp_pkt_t*)(pkt + sizeof(*eth));

    // Ethernet
    memcpy(eth->dst, req_src_mac, 6);
    memcpy(eth->src, MY_MAC, 6);
    eth->type = htons(ETH_P_ARP);

    // ARP
    arp->htype = htons(1);
    arp->ptype = htons(ETH_P_IP);
    arp->hlen  = 6;
    arp->plen  = 4;
    arp->oper  = htons(2); // reply
    memcpy(arp->sha, MY_MAC, 6);
    arp->spa = htonl(MY_IP);
    memcpy(arp->tha, req_src_mac, 6);
    arp->tpa = req_spa; // requester IP (be)

    eth_send(pkt, sizeof(*eth) + sizeof(*arp));
}

// ---------------- ICMP Echo ----------------
static void send_icmp_echo_reply(const uint8_t src_mac[6], uint32_t saddr_be,
                                 const uint8_t* req_icmp, unsigned icmp_len)
{
    uint8_t pkt[1518];
    struct eth_hdr_t* eth = (struct eth_hdr_t*)pkt;
    struct ip_hdr_t*  ip  = (struct ip_hdr_t*)(pkt + sizeof(*eth));
    struct icmp_hdr_t* icmp = (struct icmp_hdr_t*)((uint8_t*)ip + sizeof(*ip));

    // Ethernet
    memcpy(eth->dst, src_mac, 6);
    memcpy(eth->src, MY_MAC, 6);
    eth->type = htons(ETH_P_IP);

    // IP
    ip->ver_ihl = 0x45;
    ip->tos     = 0;
    ip->tot_len = htons(sizeof(*ip) + icmp_len);
    ip->id      = 0;
    ip->frag_off= 0;
    ip->ttl     = 64;
    ip->proto   = IPPROTO_ICMP;
    ip->hdr_csum= 0;
    ip->saddr   = htonl(MY_IP);
    ip->daddr   = saddr_be;

    // ICMP
    memcpy(icmp, req_icmp, icmp_len);
    icmp->type = ICMP_ECHO_REPLY;
    icmp->code = 0;
    icmp->csum = 0;
    icmp->csum = csum16(icmp, icmp_len);

    // IP checksum
    ip->hdr_csum = csum16(ip, sizeof(*ip));

    eth_send(pkt, sizeof(*eth) + sizeof(*ip) + icmp_len);
}

// ---------------- Poller: handle ARP + ICMP ----------------
void net_init(void){
    // program MAC into EthMAC HW (you already do this in eth_init, shown here for clarity)
    uint32_t lo = (MY_MAC[3]) | (MY_MAC[2]<<8) | (MY_MAC[1]<<16) | (MY_MAC[0]<<24);
    uint32_t hi = (MY_MAC[5]) | (MY_MAC[4]<<8);
    eth_writel(lo, ETH_MAC_ADDR0);
    eth_writel(hi, ETH_MAC_ADDR1);
}

// assumes you already have:
//   struct eth_hdr_t { uint8_t dst[6]; uint8_t src[6]; uint16_t type; } __attribute__((packed));
//   uint16_t ntohs(uint16_t);

static inline void print_mac(const uint8_t mac[6]){
    for (int i=0;i<6;i++){ uart_puthex8(mac[i]); if (i!=5) UARTWriteByte(':'); }
}

// print eth header + first up-to-32 bytes of payload (starting at dst)
static void debug_eth_frame(const struct eth_hdr_t* eth, uint16_t len) {
    // Header sanity
    if (len < sizeof(*eth)) return;

    uint16_t etype = ntohs(eth->type);

    uart_puts("ETH dst=");
    print_mac(eth->dst);
    uart_puts(" src=");
    print_mac(eth->src);
    uart_puts(" type=0x"); uart_puthex8((uint8_t)(etype>>8)); uart_puthex8((uint8_t)etype);

    if (etype == 0x0806) uart_puts(" (ARP)");
    else if (etype == 0x0800) uart_puts(" (IP)");
    uart_puts("\r\n");

    // Dump first 32 bytes of the frame (including L2 header)
    const uint8_t* p = (const uint8_t*)eth;
    uint16_t n = (len < 32) ? len : 32;

    // 16B rows
    for (uint16_t i=0; i<n; i++){
        if ((i & 0x0F) == 0){
            uart_puts("  ");
            uart_puthex8((i >> 8) & 0xFF);
            uart_puthex8(i & 0xFF);
            uart_puts(": ");
        }
        uart_puthex8(p[i]); UARTWriteByte(' ');
        if ((i & 0x0F) == 0x0F) uart_puts("\r\n");
    }
    if ((n & 0x0F) != 0) uart_puts("\r\n");
}

// Processes completed RX BDs in order, zero-copy (directly from BRAM),
// re-arms each BD, and stops when no more ready or budget consumed.
void net_poll_drain(unsigned budget) {
    unsigned done = 0;

    while (done < budget) {
        volatile uint32_t *bd = (volatile uint32_t*)(ETH_BD_BASE + rx_tail*8u);
        uint32_t st = bd[0];

        if (st & BD_E_R) break;                 // not ready yet

        uint16_t len  = (uint16_t)(st >> 16);   // actual frame length
        uint32_t ptr  = bd[1];

        // Ensure CPU sees fresh data
        dcache_inval_range((void*)ptr, len);

        // --- process directly from BRAM (zero-copy) ---
        if (len >= sizeof(struct eth_hdr_t)) {
            const uint8_t *pkt = (const uint8_t*)ptr;
            const uint32_t *pkt1 = (const uint32_t*)ptr;
            const struct eth_hdr_t *eth = (const struct eth_hdr_t*)pkt;
            //uint16_t etype = ntohs(eth->type);
            uint16_t etype = load_ethertype(pkt1);   // this should be 0x0806 for ARP

            // (Optional) brief debug; avoid long UART here
            // debug_eth_frame(eth, len);

            if (etype == ETH_P_ARP) {
                if (len >= sizeof(struct eth_hdr_t)+sizeof(struct arp_pkt_t )) {
                    //const struct arp_pkt_t* arp = (const struct arp_pkt_t*)(pkt + sizeof(*eth));
                    struct arp_pkt_t info;
                    arp_load_info(pkt + sizeof(struct eth_hdr_t), &info);

                    //if (ntohs(arp->oper)==1 && arp->tpa == htonl(MY_IP)) {
                    //if (info.oper==1 && info.tpa == MY_IP) {
                    if (info.oper==1) {
                      eth_writel(info.tpa, ETH_MAC_HASH0); eth_writel(MY_IP, ETH_MAC_HASH1);
                      if (info.tpa == MY_IP) {
                        //send_arp_reply(eth->src, arp->spa, arp->tpa);
                        send_arp_reply(eth->src, info.spa, info.tpa);
                      }
                    }
                }
            } else if (etype == ETH_P_IP) {
                if (len >= sizeof(struct eth_hdr_t)+sizeof(struct ip_hdr_t)) {
                    const struct ip_hdr_t* ip = (const struct ip_hdr_t*)(pkt + sizeof(*eth));
                    if (ip->ver_ihl == 0x45 && ip->proto == IPPROTO_ICMP && ip->daddr == htonl(MY_IP)) {
                        unsigned ihl = 20;
                        if (len >= sizeof(*eth)+ihl+sizeof(struct icmp_hdr_t)) {
                            const struct icmp_hdr_t* icmp = (const struct icmp_hdr_t*)(pkt + sizeof(*eth) + ihl);
                            unsigned icmp_len = ntohs(ip->tot_len) - ihl;
                            if (icmp->type == ICMP_ECHO_REQUEST) {
                                send_icmp_echo_reply(eth->src, ip->saddr, (const uint8_t*)icmp, icmp_len);
                            }
                        }
                    }
                }
            }
        }
        // ----------------------------------------------

        // Re-arm BD (capacity back in [31:16])
        uint16_t wrap = (uint16_t)(st & BD_WRAP);
        bd[0] = ((uint32_t)RX_BUF_SIZE << 16) | (wrap | BD_IRQ | BD_E_R);

        // advance ring
        rx_tail = (rx_tail == RX_BD_FIRST + RX_BD_COUNT - 1) ? RX_BD_FIRST : (rx_tail + 1);
        done++;
    }

    // Finished draining → allow new interrupts
    rx_poll_scheduled = 0;

    // If you masked RX in the ISR, unmask here:
    // uint32_t mask = eth_readl(ETH_INT_MASK);
    // eth_writel(mask | (ETH_INT_RXB | ETH_INT_RXF), ETH_INT_MASK); // if 1=en
}
