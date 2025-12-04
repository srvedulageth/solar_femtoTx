#include "rx_queue.h"

volatile uint32_t rxq_head = 0, rxq_tail = 0;
rx_msg_t rxq[RXQ_DEPTH];

void rx_queue_init(void){
    rxq_head = rxq_tail = 0;
    for (unsigned i=0;i<RXQ_DEPTH;i++){ rxq[i].ready = 0; rxq[i].len = 0; }
}

int rxq_is_full(void){
    uint32_t next = (rxq_head + 1U) % RXQ_DEPTH;
    return next == rxq_tail;
}

int rxq_push_isr(uint16_t len, const uint8_t* data){
    if (len < RX_MIN_LEN) return -1;
    if (rxq_is_full())    return -1;

    uint32_t h = rxq_head;
    rxq[h].ready = 0;

    uint32_t n = (len > RX_MTU) ? RX_MTU : len;
    for (uint32_t i=0;i<n;i++) rxq[h].buf[i] = data[i];
    rxq[h].len = (uint16_t)n;

    __asm__ volatile ("" ::: "memory");
    rxq[h].ready = 1;
    __asm__ volatile ("" ::: "memory");
    rxq_head = (h + 1U) % RXQ_DEPTH;
    return 0;
}

int rxq_pop(uint8_t** out_ptr, uint16_t* out_len){
    uint32_t t = rxq_tail;
    if (rxq[t].ready == 0) return 0;

    __asm__ volatile("" ::: "memory");
    if (out_ptr) *out_ptr = rxq[t].buf;
    if (out_len) *out_len = rxq[t].len;

    rxq[t].ready = 0;
    __asm__ volatile ("" ::: "memory");
    rxq_tail = (t + 1U) % RXQ_DEPTH;
    return 1;
}
