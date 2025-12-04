#pragma once
#include <stdint.h>

#define RXQ_DEPTH   8
#define RX_MTU      1536
#define RX_MIN_LEN  14

typedef struct {
    volatile uint8_t ready;
    uint16_t len;
    uint8_t  buf[RX_MTU];
} rx_msg_t;

extern volatile uint32_t rxq_head, rxq_tail;
extern rx_msg_t rxq[RXQ_DEPTH];

void rx_queue_init(void);
int  rxq_is_full(void);
int  rxq_push_isr(uint16_t len, const uint8_t* data);  // returns 0 ok, -1 drop
int  rxq_pop(uint8_t** out_ptr, uint16_t* out_len);    // returns 1 ok, 0 empty
