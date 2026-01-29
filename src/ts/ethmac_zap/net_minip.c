// net_minip.c — tiny LAN stack for OpenCores EthMAC
#include <stdint.h>
#include <string.h>   // for memset if you link it; else hand-roll
#include "uart.h"
#include "ethmac_zap.h"
#include "eth_structs.h"
#include "ethmac_shared.h"

// ---------------- CONFIG ----------------
static const uint8_t MY_MAC[6] = {0x02,0x12,0x34,0x56,0x78,0x9A};
#define PC_IP   0xC0A8010Au   // 192.168.1.10 (your Windows box)
#define MY_IP   0xC0A80114u   // 192.168.1.20
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

//Loading Eth Packet Type ...
static inline uint16_t load_ethertype(const void *base) {
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

static uint16_t csum16_add(uint32_t sum, const void* data, unsigned len) {
    const uint8_t* p = (const uint8_t*)data;
    while (len > 1){ sum += ((uint16_t)p[0]<<8) | p[1]; p+=2; len-=2; }
    if (len) sum += ((uint16_t)p[0]<<8);
    while (sum>>16) sum = (sum & 0xFFFF) + (sum>>16);
    return (uint16_t)sum;
}

static uint16_t csum16_finalize(uint32_t sum) {
    while (sum>>16) sum = (sum & 0xFFFF) + (sum>>16);
    return (uint16_t)~sum;
}

// ICMP
#define IPPROTO_ICMP 1
#define ICMP_ECHO_REQUEST 8
#define ICMP_ECHO_REPLY   0

// UDP
#define IPPROTO_UDP 17

static inline void load_arp_info(const void *arp_base, struct arp_pkt_t *out) {
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

#ifdef DEBUG_1
    uart_puts("ARP Info = ");
    uart_puts("0x"); uart_puthex32(w0); uart_puts(" ");
    uart_puts("0x"); uart_puthex32(w1); uart_puts(" ");
    uart_puts("0x"); uart_puthex32(w2); uart_puts(" ");
    uart_puts("0x"); uart_puthex32(w3); uart_puts(" ");
    uart_puts("0x"); uart_puthex32(w4); uart_puts(" ");
    uart_puts("0x"); uart_puthex32(w5); uart_puts(" ");
    uart_puts("0x"); uart_puthex32(w6); uart_puts(" ");
    uart_puts("0x"); uart_puthex32(w7);
    uart_puts("\r\n");
#endif
    
    // Interpret words as big-endian byte packs:
    // High 16 bits of w0 are EtherType (0x0806), low 16 bits are htype (0x0001)
    uint16_t htype_net = (uint16_t)(w0 & 0xFFFF);
    uint16_t ptype_net = (uint16_t)(w1 >> 16);

    uint8_t hlen = (uint8_t)((w1 >> 8) & 0xFF);   // 0x06
    uint8_t plen = (uint8_t)(w1 & 0xFF);         // 0x04

    //uint16_t oper_net = (uint16_t)(w2 >> 16);    // 0x0001
    uint16_t oper_net = (uint16_t)(w2 & 0xFFFF);    // 0x0001

    // Sender MAC (sha): A4 BB 6D 52 E4 53
    out->sha[0] = (uint8_t)((w2 >> 24) & 0xFF);   // A4
    out->sha[1] = (uint8_t)((w2 >> 16) & 0xFF);   // BB
    out->sha[2] = (uint8_t)((w3 >> 8) & 0xFF);    // 6D
    out->sha[3] = (uint8_t)((w3 >> 0) & 0xFF);   // 52
    out->sha[4] = (uint8_t)((w3 >> 24) & 0xFF);    // E4
    out->sha[5] = (uint8_t)((w3 >> 16) & 0xFF);    // 53

    // Sender IP: w4 already holds 0xC0A8010A in network order
    uint32_t spa_net = (((w4 << 16) & 0xFFFF0000u) | ((w4 >> 16) & 0x0000FFFFu));

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

// Decode *only* source MAC into out_src[6].
// eth_base points at the first byte of the Ethernet header in BRAM.
static inline void load_eth_dst(const void *eth_base, uint8_t out_dst[6]) {
    const volatile uint32_t *src = (const volatile uint32_t*)eth_base;
    uint32_t w1 = src[1];  // 0x02123456
    uint32_t w2 = src[2];  // 0x789AA4BB

    // -------------------------
    // Reconstruct DESTINATION MAC
    // -------------------------
    // dst[0..1] = low 16 bits of w1 (A4 BB)
    out_dst[0] = (uint8_t)(w1 >> 8);
    out_dst[1] = (uint8_t)(w1);
    // dst[2..5] = all bytes of w2 (6D 52 E4 53)
    out_dst[2] = (uint8_t)(w2 >> 24);
    out_dst[3] = (uint8_t)(w2 >> 16);
    out_dst[4] = (uint8_t)(w2 >>  8);
    out_dst[5] = (uint8_t)(w2);
}

// ip_base points to the first byte of the IPv4 header
// (i.e. immediately after EtherType 0x0800 in the frame buffer).
static inline void load_ip_info(const void *ip_base, struct ip_hdr_t *out) {

    const volatile uint32_t *src = (const volatile uint32_t*)ip_base;

    uint32_t w0 = src[0];  // 0x45000800
    uint32_t w1 = src[1];  // 0xD706003C
    uint32_t w2 = src[2];  // 0x80010000
    uint32_t w3 = src[3];  // 0xC0A80000
    uint32_t w4 = src[4];  // 0xC0A8010A
    uint32_t w5 = src[5];  // 0x08000114

    // Layout on the wire (no options):
    //  0: ver_ihl
    //  1: tos
    //  2-3: tot_len  (network order)
    //  4-5: id       (network order)
    //  6-7: frag_off (network order)
    //  8: ttl
    //  9: proto
    // 10-11: hdr_csum (network order)
    // 12-15: saddr   (network order)
    // 16-19: daddr   (network order)

    // ver_ihl and tos live in high 16 bits of w0
    out->ver_ihl   = (uint8_t)(w0 >> 24);   // 0x45
    out->tos       = (uint8_t)(w0 >> 16);   // 0x00
    out->icmp_type = (uint8_t)(w0 >> 8);   // 0x08

    // From your observed pattern:
    // - ID is upper 16 bits of w1
    // - total length is lower 16 bits of w1
    uint16_t id_net      = (uint16_t)(w1 >> 16);   // 0xD706
    uint16_t tot_len_net = (uint16_t)(w1 & 0xFFFF); // 0x003C

    // Fragment offset seems to be 0 in your captures; if later you
    // see it non-zero, we can refine this mapping.
    uint16_t frag_net    = 0;

    // Header checksum appears as low 16 bits of w2 (currently 0x0000)
    uint16_t csum_net    = (uint16_t)(w2 & 0xFFFF);

    // Convert multibyte fields to host order
/*
    out->id       = ntohs16(id_net);
    out->tot_len  = ntohs16(tot_len_net);
    out->frag_off = ntohs16(frag_net);
    out->hdr_csum = ntohs16(csum_net);
*/

    out->id       = id_net;
    out->tot_len  = tot_len_net;
    out->frag_off = frag_net;
    out->hdr_csum = csum_net;

    // TTL and proto are high bytes of w2
    out->ttl   = (uint8_t)(w2 >> 24);  // 0x80
    out->proto = (uint8_t)(w2 >> 16);  // 0x01

    // Source IP: you have the full 0xC0A8010A in w4
    uint32_t saddr_net = w4;

    // Dest IP: top 16 bits C0A8 in w3, low 16 bits 0x0114 in w5
    uint32_t daddr_net = (w3 & 0xFFFF0000u) | (w5 & 0x0000FFFFu);

    //out->saddr = ntohl32(saddr_net);
    //out->daddr = ntohl32(daddr_net);
    out->saddr = saddr_net;
    out->daddr = daddr_net;
/*
    eth_writel(out->ver_ihl, ETH_MAC_HASH0);
    eth_writel(out->tos, ETH_MAC_HASH0);
    eth_writel(out->icmp_type, ETH_MAC_HASH0);
    eth_writel(out->id, ETH_MAC_HASH0);
    eth_writel(out->tot_len, ETH_MAC_HASH0);
    eth_writel(out->frag_off, ETH_MAC_HASH0);
    eth_writel(out->hdr_csum, ETH_MAC_HASH0);
    eth_writel(out->ttl, ETH_MAC_HASH0);
    eth_writel(out->proto, ETH_MAC_HASH0);
    eth_writel(saddr_net, ETH_MAC_HASH0);
    eth_writel(daddr_net, ETH_MAC_HASH0);
*/
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
    //memcpy(eth->dst, req_src_mac, 6);
    //memcpy(eth->src, MY_MAC, 6);
    for (volatile unsigned k = 0; k < 6; ++k) { pkt[k] = req_src_mac[k]; }
    for (volatile unsigned k = 0; k < 6; ++k) { pkt[k+6] = MY_MAC[k]; }
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

    //for (volatile unsigned k = 0; k < 8; ++k) {
    //  uint32_t word = (pkt[(k*4) + 3] << 24) | (pkt[(k*4) + 2] << 16) | (pkt[(k*4) + 1] << 8) | (pkt[(k*4) + 0] << 0);
    //  eth_writel(word, ETH_MAC_HASH1);
    //}
    eth_send(pkt, sizeof(*eth) + sizeof(*arp));
}

// ---------------- ICMP Echo ----------------
static void send_icmp_echo_reply(const uint8_t src_mac[6], uint32_t saddr_be,
                                 const uint8_t* req_icmp, unsigned icmp_len)
{
    uint8_t pkt[256];

    struct eth_hdr_t* eth = (struct eth_hdr_t*)pkt;
    struct ip_hdr_r_t* ip  = (struct ip_hdr_r_t*)(pkt + sizeof(*eth));
    struct icmp_hdr_t* icmp = (struct icmp_hdr_t*)((uint8_t*)ip + sizeof(*ip));
    uint8_t *d = (uint8_t*)icmp + sizeof(struct icmp_hdr_t);
    volatile uint32_t *srcw = (volatile uint32_t *)req_icmp;

    // Ethernet
    //memcpy(eth->dst, src_mac, 6);
    //memcpy(eth->src, MY_MAC, 6);
    for (volatile unsigned k = 0; k < 6; ++k) { pkt[k] = src_mac[k]; }
    for (volatile unsigned k = 0; k < 6; ++k) { pkt[k+6] = MY_MAC[k]; }
    eth->type = htons(ETH_P_IP);

    // IP
    ip->ver_ihl = 0x45;
    ip->tos     = 0;
    ip->tot_len = htons(sizeof(*ip) + icmp_len);
    //ip->tot_len = sizeof(*ip) + icmp_len;
    ip->id      = 0;
    ip->frag_off= 0;
    ip->ttl     = 64;
    ip->proto   = IPPROTO_ICMP;
    ip->hdr_csum= 0;
    ip->saddr   = htonl(MY_IP);
    //ip->daddr   = saddr_be;
    ip->daddr   = htonl(saddr_be);

    // ICMP
    //memcpy(icmp, req_icmp, icmp_len); //First icmp_len bytes copied from req_icmp to icmp. Then first 4 bytes are overwritten below.
    for (volatile unsigned i = 0; i < 11; i++) {
      uint32_t dstw = srcw[i];
      //eth_writel(dstw, ETH_MAC_HASH1);

      if(i == 0) { //First word upper 16 bits
        icmp->type = (uint8_t)((dstw >> 24) & 0xFF); //1 Byte 34th byte in pkt
        icmp->code = (uint8_t)((dstw >> 16) & 0xFF); //1 Byte 35th byte in pkt
      }
      else if(i == 1) {  //csum and id
        icmp->csum = (uint16_t)(dstw & 0xFFFF); //2 Bytes 36 and 37 th byte in pkt
        icmp->id = (uint16_t)((dstw >> 16) & 0xFFFF); //2 Bytes 38 and 39 th byte in pkt
        icmp->id = bswap16(icmp->id);
      }
      else if (i == 2) {
        icmp->seq = (uint16_t)(dstw & 0xFFFF); //2 bytes 40th and 41st byte in pkt
        icmp->seq = bswap16(icmp->seq); //2 bytes 40th and 41st byte in pkt
        //eth_writel(icmp->seq, ETH_MAC_HASH0);

        //eth_writel(dstw, ETH_MAC_HASH0);
        // data starts in lower 16 bits of dstw[3]
        d[0] = (dstw >> 24) & 0xFF; //42nd byte in pkt
        d[1] = (dstw >> 16) & 0xFF;
      }
      else if (i >= 3) {
        // copy all 4 bytes of each subsequent word
        unsigned base = 2 + (i - 3)*4;   // position in data[]
        //eth_writel(dstw, ETH_MAC_HASH1);

        d[base + 0] = (dstw >> 8) & 0xFF;
        d[base + 1] = (dstw << 0) & 0xFF;
        d[base + 2] = (dstw >> 24) & 0xFF;
        d[base + 3] = (dstw >> 16) & 0xFF;
      }
    }

    icmp->type = ICMP_ECHO_REPLY; //1 Byte
    icmp->code = 0; //1 Byte
    icmp->csum = 0; //2 Bytes
    //icmp->csum = csum16(icmp, icmp_len);
    icmp->csum = bswap16(csum16(icmp, icmp_len));

    // IP checksum
    ip->hdr_csum = bswap16(csum16(ip, sizeof(*ip)));

    //eth_writel(icmp_len, ETH_MAC_HASH1);
    //eth_writel(sizeof(*ip), ETH_MAC_HASH1);
    //eth_writel(sizeof(*eth), ETH_MAC_HASH1);

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

// Processes completed RX BDs in order, zero-copy (directly from BRAM),
// re-arms each BD, and stops when no more ready or budget consumed.
//void net_poll_drain(unsigned budget) {
void net_poll_drain(void) {
    unsigned done = 0;

    while (done < 1) {
        volatile uint32_t *bd = (volatile uint32_t*)(ETH_BD_BASE + rx_tail*8u);
        uint32_t st = bd[0];

        if (st & BD_E_R)
            break;                 // BD still owned by MAC, nothing to do

        uint16_t len  = (uint16_t)((st >> 16) & 0xFFFF);   // actual frame length
        uint32_t ptr  = bd[1];
#ifdef DEBUG_1
        uart_puts("net_mini len=0x"); uart_puthex16(len); uart_puts("\r\n");
#endif

        // Re-arm BD (capacity back in [31:16]) *before* we start decoding.
        uint16_t wrap = (uint16_t)(st & BD_WRAP);
        bd[0] = ((uint32_t)RX_BUF_SIZE << 16) | (wrap | BD_IRQ | BD_E_R);

        // Advance ring index now
        rx_tail = (rx_tail == RX_BD_FIRST + RX_BD_COUNT - 1)
                  ? RX_BD_FIRST
                  : (rx_tail + 1);

        done++;

        // Ensure CPU sees fresh data
        dcache_inval_range((void*)ptr, len);

        // --- process directly from BRAM (zero-copy) ---
        if (len >= sizeof(struct eth_hdr_t)) {
            const uint8_t  *pkt  = (const uint8_t*)ptr;
            const uint32_t *pkt1 = (const uint32_t*)ptr;
            const struct eth_hdr_t *eth = (const struct eth_hdr_t*)pkt;

            uint16_t etype = load_ethertype(pkt1);   // 0x0806 ARP, 0x0800 IPv4, etc.

#ifdef DEBUG_1
            uart_puts("net_mini etype=0x"); uart_puthex16(etype); uart_puts("\r\n");
#endif

            // ----------------- ARP -----------------
            if (etype == ETH_P_ARP) {
                if (len >= sizeof(struct eth_hdr_t) + sizeof(struct arp_pkt_t)) {
                    struct arp_pkt_t info;
                    load_arp_info(pkt + sizeof(struct eth_hdr_t), &info);

#ifdef DEBUG2
                    uart_puts("ARP oper=0x"); uart_puthex16(info.oper);
                    uart_puts(" tpa=0x"); uart_puthex32(info.tpa);
                    uart_puts("\r\n");
#endif
                    // Only answer ARP request (oper = 1) for our IP
                    if (info.oper == 1 && info.tpa == MY_IP) {
                        // reply to sender MAC/IP
                        send_arp_reply(info.sha, info.spa, info.tpa);
                    }
                }
            }

            // ----------------- IPv4 -----------------
            else if (etype == ETH_P_IP) {
                if (len < sizeof(struct eth_hdr_t) + sizeof(struct ip_hdr_t)) {
                    // Too short to even contain full IPv4 header → drop
                    goto next_packet;
                }

                struct ip_hdr_t ip_info;
                load_ip_info(pkt + sizeof(struct eth_hdr_t), &ip_info);

                // Fast drop filters:
                //  - must be IPv4 header 0x45 (no options)
                //  - must be addressed to us
                if (ip_info.ver_ihl != 0x45)
                    goto next_packet;
                if (ip_info.daddr != MY_IP)
                    goto next_packet;

                // We only support ICMP. Drop UDP/TCP/others.
                if (ip_info.proto != IPPROTO_ICMP)
                    goto next_packet;

                unsigned ihl      = 20;                  // ver_ihl == 0x45 guaranteed
                unsigned icmp_len = ip_info.tot_len - ihl;

                if (len < sizeof(struct eth_hdr_t) + ihl + sizeof(struct icmp_hdr_t))
                    goto next_packet;   // truncated

                const uint8_t *ip_start  = pkt + sizeof(struct eth_hdr_t);
                const uint8_t *icmp_ptr  = ip_start + ihl;
                const struct icmp_hdr_t *icmp =
                    (const struct icmp_hdr_t*)icmp_ptr;

                // Only answer echo requests
                if (ip_info.icmp_type != ICMP_ECHO_REQUEST)
                    goto next_packet;

                // Extract destination MAC (sender of the request)
                uint8_t dst_mac[6];
                load_eth_dst(pkt1, dst_mac);

                // Send echo reply back
                send_icmp_echo_reply(dst_mac, ip_info.saddr,
                                     (const uint8_t*)icmp, icmp_len);
            }

            // Any other EtherType is silently ignored (IPv6, 802.1Q, etc.)
        }

next_packet:
        // Tiny barrier/delay
        for (volatile unsigned k = 0; k < 2; ++k)
            __asm__ volatile("" ::: "memory");
    }

    // Finished draining → allow new interrupts
    rx_poll_scheduled = 0;
}
