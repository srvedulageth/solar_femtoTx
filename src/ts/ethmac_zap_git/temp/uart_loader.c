#include <stdint.h>
#include <stddef.h>
#include "ethmac_zap.h"
#include "uart.h"

#define ZIMAGE_ADDR  0x10800000u
#define DTB_ADDR     0x11000000u

#define LOAD_MAGIC 0x5A504C44u  /* "ZPLD" */

typedef void (*kernel_entry_t)(uint32_t r0, uint32_t r1, uint32_t r2);

extern void jump_to_linux(void);  /* jump_linux.s — jumps to 0x10008020 */

static uint32_t dram_sanity_check(void)
{
    volatile uint32_t *p = (volatile uint32_t *)0x10008000u;
    uint32_t errors = 0;

    uart_puts("DRAM byte lane check...\r\n");

    uint32_t patterns[4] = {
        0xFF000000u,
        0x00FF0000u,
        0x0000FF00u,
        0x000000FFu
    };

    for (int i = 0; i < 4; i++) {
        p[i] = patterns[i];
        uint32_t rb = p[i];
        uart_puts("wrote=0x"); uart_puthex32(patterns[i]);
        uart_puts(" got=0x");  uart_puthex32(rb);
        if (rb == patterns[i])
            uart_puts(" OK\r\n");
        else {
            uart_puts(" FAIL\r\n");
            errors++;
        }
    }

    /* Targeted patterns that failed previously */
    uint32_t test_vals[7] = {
        0xE5DA9000u,
        0xE5DAA003u,
        0xE1520003u,
        0xDA000000u,
        0x00DA0000u,
        0x0000DA00u,
        0x000000DAu,
    };

    uart_puts("Pattern test:\r\n");
    for (int i = 0; i < 7; i++) {
        p[i] = test_vals[i];
        uint32_t rb = p[i];
        uart_puts("wrote=0x"); uart_puthex32(test_vals[i]);
        uart_puts(" got=0x");  uart_puthex32(rb);
        if (rb == test_vals[i])
            uart_puts(" OK\r\n");
        else {
            uart_puts(" FAIL\r\n");
            errors++;
        }
    }

    return errors;
}

static uint32_t uart_get_u32_le(void)
{
    uint32_t v = 0;
    v |= ((uint32_t)UARTGetChar()) << 0;
    v |= ((uint32_t)UARTGetChar()) << 8;
    v |= ((uint32_t)UARTGetChar()) << 16;
    v |= ((uint32_t)UARTGetChar()) << 24;
    return v;
}

static void recv_blob(void)
{
    uint32_t magic = uart_get_u32_le();
    while (magic != LOAD_MAGIC) {
      magic = uart_get_u32_le();
    }

    uint32_t addr  = uart_get_u32_le();
    uint32_t size  = uart_get_u32_le();

    volatile uint8_t *p = (volatile uint8_t *)addr;

    for (uint32_t i = 0; i < size; ++i) {
        p[i] = UARTGetChar();
            //UARTWriteByte(p[i]);

        if ((i & 0xFFFFu) == 0)
            UARTWriteByte('.');
    }

    uart_puts("\r\nMagic=0x"); uart_puthex32(magic); uart_puts("\r\n");
    uart_puts("RX addr=0x"); uart_puthex32(addr);
    uart_puts(" size=0x"); uart_puthex32(size); uart_puts("\r\n");

    uart_puts("\r\nOK\r\n");
}

void boot_linux_uart_loader(void)
{
    uart_puts("\nZAP UART Linux loader\r\n");

    /* Step 1: Quick DRAM check before wasting time on transfer */
    uint32_t dram_errors = dram_sanity_check();
    if (dram_errors > 0) {
        uart_puts("WARNING: DRAM errors detected. Proceeding anyway...\r\n");
        /* Don't halt — DDR3 calibration is marginal but may still work */
    }

    /* Step 2: Receive zImage and DTB via UART */
    uart_puts("Send zImage blob...\r\n");
    recv_blob();   // Python sends addr = 0x10008000

    uart_puts("Send DTB blob...\r\n");
    recv_blob();   // Python sends addr = 0x10800000

    //uint32_t dtb_magic = *(volatile uint32_t*)DTB_ADDR;
    //uart_puts("DTB magic=0x"); uart_puthex32(dtb_magic); uart_puts("\r\n");

    uart_puthex32(((volatile uint32_t*)0x10008000u)[0]); uart_puts("\r\n");
    uart_puthex32(((volatile uint32_t*)0x10008000u)[1]); uart_puts("\r\n");
    uart_puthex32(((volatile uint32_t*)0x10008000u)[2]); uart_puts("\r\n");
    uart_puthex32(((volatile uint32_t*)0x10008000u)[3]); uart_puts("\r\n");
    uart_puthex32(((volatile uint32_t*)0x10008000u)[4]); uart_puts("\r\n");
    uart_puthex32(((volatile uint32_t*)0x10008000u)[5]); uart_puts("\r\n");
    uart_puthex32(((volatile uint32_t*)0x10008000u)[6]); uart_puts("\r\n");
    uart_puthex32(((volatile uint32_t*)0x10008000u)[7]); uart_puts("\r\n");
    uart_puthex32(((volatile uint32_t*)0x10008000u)[8]); uart_puts("\r\n");
    uart_puthex32(*(volatile uint32_t*)0x10800000u);     uart_puts("\r\n");

    /* Step 3: Verify key words after transfer */
    uart_puts("\r\nVerify:\r\n");
    uart_puts("zimg[8] =0x"); 
    uart_puthex32(((volatile uint32_t*)0x10800000u)[8]);
    uart_puts(" (expect 0xEA000005)\r\n");

    uart_puts("zimg[9] =0x"); 
    uart_puthex32(((volatile uint32_t*)0x10800000u)[9]);
    uart_puts(" (expect 0x016F2818)\r\n");

    uart_puts("zimg[33]=0x"); 
    uart_puthex32(((volatile uint32_t*)0x10800000u)[33]);
    uart_puts(" (expect 0xE3A00201)\r\n");

    uart_puts("dtb[0]  =0x"); 
    uart_puthex32(*(volatile uint32_t*)0x11000000u);
    uart_puts(" (expect 0xEDFE0DD0)\r\n");

    uart_puts("Jumping to Linux...\r\n");
    //jump_to_linux(ZIMAGE_ADDR, DTB_ADDR);
    jump_to_linux();
}
