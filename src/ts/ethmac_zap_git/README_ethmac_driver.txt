# OpenCores EthMAC driver (ZAP ARM, Wishbone)

This is a minimal bring-up driver for the OpenCores 10/100 EthMAC on Arty A7 (DP83848J, MII, PHY addr=1).

## Files
- `ethmac_zap.h` — public API + platform config and register/BD definitions.
- `ethmac_zap.c` — implementation (MDIO, PHY bring-up, MAC config, TX/RX ring).

## What you MUST set
- `ETH_DMA_MEM_BASE` — system RAM region accessible by the EthMAC Wishbone master.
- `ETH_IRQ_NUM` — your interrupt number (if you hook interrupts later).
- Cache maintenance functions (if your CPU has data cache).

## BD placement
By default the BD RAM is assumed at `ETH_BASE + 0x400` inside the 4 KB window.
If your wrapper maps BDs at OC's index 0x400 (byte +0x1000), switch the macro in `ethmac_zap.h`.

## PHY
Assumes DP83848J (Arty A7 default) in MII mode, PHY addr=1, auto-neg enabled.
The driver reads PHYSTS to set MAC duplex.

## Usage
```c
#include "ethmac_zap.h"

int main(void){
    const uint8_t mac[6] = {0x02,0x12,0x34,0x56,0x78,0x9A};
    eth_init(mac);

    // TX example
    static uint8_t frame[60] = { /* fill Ethernet frame */ };
    eth_tx_enqueue(frame, sizeof(frame));

    // RX poll example
    uint8_t rxbuf[1600];
    unsigned len;
    if (eth_rx_poll(rxbuf, &len) == 1){
        // process frame
    }
}
```

## Notes
- For a continuous PHY reference clock, drive 25 MHz on `eth_ref_clk` (MII).
- Ensure your XDC maps all MII pins correctly and sets `create_clock` on `eth_ref_clk`.
- This is a simple baseline; for performance use IRQ-driven rings and zero-copy buffers.
