#ifndef ETH_STRUCTS_H
#define ETH_STRUCTS_H

#include <stdint.h>

// Ethernet header
struct __attribute__((packed)) eth_hdr_t {
    uint8_t  dst[6];
    uint8_t  src[6];
    uint16_t type;    // big-endian
};

// IPv4 header (no options)
struct __attribute__((packed)) ip_hdr_t {
    uint8_t  ver_ihl;     // 0x45
    uint8_t  tos;
    uint8_t  icmp_type;
    uint16_t tot_len;     // be
    uint16_t id;          // be
    uint16_t frag_off;    // be
    uint8_t  ttl;
    uint8_t  proto;
    uint16_t hdr_csum;    // be
    uint32_t saddr;       // be
    uint32_t daddr;       // be
};

// IPv4 header (no options)
struct __attribute__((packed)) ip_hdr_r_t {
    uint8_t  ver_ihl;     // 0x45
    uint8_t  tos;
    uint16_t tot_len;     // be
    uint16_t id;          // be
    uint16_t frag_off;    // be
    uint8_t  ttl;
    uint8_t  proto;
    uint16_t hdr_csum;    // be
    uint32_t saddr;       // be
    uint32_t daddr;       // be
};

// ICMP
struct __attribute__((packed)) icmp_hdr_t {
    uint8_t  type;
    uint8_t  code;
    uint16_t csum;        // be
    uint16_t id;          // be
    uint16_t seq;         // be
    // data...
};

// UDP
struct __attribute__((packed)) udp_hdr_t {
    uint16_t sport;   // be
    uint16_t dport;   // be
    uint16_t len;     // be
    uint16_t csum;    // be (0 allowed)
};

struct __attribute__((packed)) arp_pkt_t {
    uint16_t htype;
    uint16_t ptype;
    uint8_t  hlen;
    uint8_t  plen;
    uint16_t oper;
    uint8_t  sha[6];
    uint32_t spa;
    uint8_t  tha[6];
    uint32_t tpa;
};

#endif
