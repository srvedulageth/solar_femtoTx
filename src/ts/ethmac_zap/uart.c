//
// (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//


#include "uart.h"
#include "ethmac_zap.h"
#include "ethmac_shared.h"

void eth_demo_init(void);
void eth_print_phy_status(void);
void eth_irq_handler(void);
void phy_hw_reset(void);
void phy_scan_all(void);
void phy_autoneg_and_wait(void);
void phy_verify(int pa);
void mdio_burner(int pa);
void eth_transmit(void);
//void net_poll_drain(unsigned budget);
void net_poll_drain();
void net_init(void);

void irq_handler ()
{
       // Wait for space to be available.
       while ( !UARTTransmitEmpty() );

       // Write character
       //UARTWriteByte ( UARTGetChar() );

       eth_irq_handler();

       // Clear interrupt pending register in VIC.
       *VIC_INT_CLEAR = 0xffffffff;
}

// ---------------- Friendly boot banner ----------------
void UARTPrintBanner(void) {
    UARTWrite("\n\r================================\n\r");
    UARTWrite("          ZAP SoC Boot           \n\r");
    UARTWrite("        UART is alive ✔          \n\r");
    UARTWrite("================================\n\r\n\r");
}

int main(void)
{
        // Just bringup the UART TX and RX - enable interrupts and exit.
        UARTInit();

#ifdef DEBUG_2
        UARTPrintBanner();
#endif

        eth_demo_init();

#ifdef DEBUG_2
        phy_hw_reset();
        phy_scan_all();
        phy_autoneg_and_wait();
        eth_print_phy_status();
        phy_verify(1);
        //phy_verify(2);
        mdio_burner(1);
#endif

        //eth_transmit();
        //net_init();
        //UARTWrite("Net up. Try: ping 192.168.1.20\r\n");

        volatile uint32_t x = *(volatile uint32_t*)0x20000000; //FOR MMU Testing ....

        // Respond to ARP + PING forever
        for (;;) {
            if (rx_poll_scheduled) {
               //eth_writel(0x11111111, ETH_MAC_HASH0);
               // Drain up to a budget; prevents livelock under heavy RX
               net_poll_drain();
            }

            // Example: fire a UDP packet to Windows: 192.168.1.10:9000
            // const char msg[] = "hello from FPGA";
            // udp_send_to_ip(htonl(PC_IP), 9000, msg, sizeof(msg)-1);

            // small idle if you want
            for (volatile unsigned k = 0; k < 2; ++k) __asm__ volatile("" ::: "memory");
        }

        UARTEnableRXInterrupt();

        // Never return — idle
        for (;;)
           __asm__ volatile("" ::: "memory");

        return 0;
}

/* Sets up rate as 1 baud = 16 CPU clocks. Also resets TX and RX logic */
void UARTInit()
{
        // Set up frequency of operation. 1 bit time = 16 CPU clocks.
        *UART0_LCR        = (*UART0_LCR) | (1 << 7);
        *UART0_DLAB1      = 0x46;
        *UART0_DLAB2      = 1;
        *UART0_LCR        = (*UART0_LCR) & ~(1 << 7);

        // Enable TX and RX.
        UARTEnableTX();
        UARTEnableRX();
}

/* Write a string to the UART device. This is an open loop function. */
void UARTWrite(const char* s)
{
    while (*s) {
        UARTWriteByte((unsigned char)*s++);  // pass the byte VALUE
        while (!UARTTransmitEmpty() ) ;    // block until THR/FIFO drained
    }
}

/* Write a byte to the UART. This is an open loop function. */
void UARTWriteByte(unsigned char c)
{
        *UART0_THR = c;
}

/* UART Enable RX interrupt */
void UARTEnableRXInterrupt (void) {
        *UART0_IER = *UART0_IER | 1;
}

/* Enable TX */
void UARTEnableTX (void) {
        *UART0_FCR = *UART0_FCR | 4;
}

/* Enablt RX */
void UARTEnableRX (void) {
        *UART0_FCR = *UART0_FCR | 1;
}

/* Check if transmit is empty */
int UARTTransmitEmpty (void) {
        char x = *UART0_LSR;

        if ( x & (1 << 6) )
                return 1;
        else
                return 0;
}

/* Get a character from uart */
char UARTGetChar (void) {
        return *UART0_RBR;
}
