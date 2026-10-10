#ifndef ETHMAC_SHARED_H
#define ETHMAC_SHARED_H

#include <stdint.h>

extern volatile int rx_poll_scheduled;
extern volatile unsigned tx_head;
extern volatile unsigned rx_tail;

#endif
