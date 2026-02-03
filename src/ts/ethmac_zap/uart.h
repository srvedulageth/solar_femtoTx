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

#ifndef UART_H
#define UART_H
#include <stdint.h>
//#define DEBUG

        // Non virtualized addresses for UART0
        #define UART0_DLAB1   ((char*)0xFFFFFFE0)
        #define UART0_DLAB2   ((char*)0xFFFFFFE1)
        #define UART0_THR     ((char*)0xFFFFFFE0)
        #define UART0_RBR     ((char*)0xFFFFFFE0)
        #define UART0_IER     ((char*)0xFFFFFFE1)
        #define UART0_FCR     ((char*)0xFFFFFFE2)
        #define UART0_LCR     ((char*)0xFFFFFFE3)
        #define UART0_LSR     ((char*)0xFFFFFFE5)
        #define VIC_INT_CLEAR ( (int*)0xFFFFFFA8)

        // Initialization functions.
        void UARTInit(void);
        void UARTEnableTX(void);
        void UARTEnableRX(void);

        // Open loop functions.
        void UARTWrite(const char*);
        void UARTWriteByte(unsigned char x);

        // UART interrupt related functions.
        void UARTEnableTXInterrupt(void);
        void UARTEnableRXInterrupt(void);

        // Check THRE
        int UARTTransmitEmpty(void);

        // Get a character from the UART.
        char UARTGetChar (void );

/* =================== Simple UART helpers ======================= */
static void uart_puts(const char* s){ UARTWrite((char*)s); }

static void uart_puthex(unsigned x){
  static const char h[]="0123456789ABCDEF";
  char buf[11]; buf[0]='0'; buf[1]='x';
  for (int i=0;i<8;i++) buf[2+i]=h[(x>>(28-4*i))&0xF];
  buf[10]=0; UARTWrite(buf);
}

static void uart_puthex_sml(unsigned x){
  static const char h[]="0123456789ABCDEF";
  char buf[3];
  for (int i=6;i<8;i++) buf[i-6]=h[(x>>(28-4*i))&0xF];
  UARTWrite(buf); uart_puts(" ");
}

static void uart_puthex8(uint8_t v){
    const char* H = "0123456789ABCDEF";
    UARTWriteByte(H[v>>4]); UARTWriteByte(H[v&0xF]);
}

static void uart_puthex16(uint16_t v){
    uart_puthex8((uint8_t)(v>>8));
    uart_puthex8((uint8_t)(v>>0));
}

static void uart_puthex32(uint32_t v){
    uart_puthex8((uint8_t)(v>>24));
    uart_puthex8((uint8_t)(v>>16));
    uart_puthex8((uint8_t)(v>>8));
    uart_puthex8((uint8_t)(v>>0));
}

static inline char hex_nibble(unsigned v) {
    v &= 0xF;
    return (v < 10) ? ('0' + v) : ('A' + (v - 10));
}

static void hexdump64(uint32_t buf_addr, unsigned total_len)
{
    volatile uint8_t* p = (volatile uint8_t*)buf_addr;
    unsigned n = (total_len < 64) ? total_len : 64;

    uart_puts("\r\n");
    for (unsigned i=0;i<n;i++){
        if ((i & 0x0F) == 0){
            uart_puts("  ");
            uart_puthex8((uint8_t)((i>>8)&0xFF));
            uart_puthex8((uint8_t)(i&0xFF));
            uart_puts(": ");
        }
        uart_puthex8(p[i]);
        UARTWriteByte(' ');
        if ((i & 0x0F) == 0x0F) uart_puts("\r\n");
    }
    if ((n & 0x0F) != 0) uart_puts("\r\n");
}
#endif
