/* dram_direct_boot_v3.c
   Drop-in replacement for dram_direct_boot() in uart_loader.c
   Uses fresh zImage (head.S patched for ZAP RAM base) and new DTB.
   Call from main() instead of boot_linux_uart_loader().
*/

#include <stdint.h>
#include "uart.h"

extern void jump_to_linux(void);  /* jump_linux.s — jumps to 0x10008020 */

static const uint32_t zimage_hdr[128] = {
    0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u,
    0xEA000005u, 0x016F2818u, 0x00000000u, 0x0018C4A0u, 0x04030201u, 0x45454545u, 0x00006F5Cu, 0xE10F9000u,
    0xE1A07001u, 0xE1A08002u, 0xE10F2000u, 0xE3120003u, 0x1A000001u, 0xE3A00017u, 0xEF123456u, 0xE321F0D3u,
    0xE16FF009u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u,
    0xE1A0000Fu, 0xE3A00201u, 0xE28F1F6Du, 0xE591D000u, 0xE08DD001u, 0xE1A01008u, 0xEB001A27u, 0xE2804902u,
    0xE1A0000Fu, 0xE1500004u, 0x359F019Cu, 0x3080000Fu, 0x31540000u, 0x33844001u, 0x2B000068u, 0xE28F0D06u,
    0xE590D000u, 0xE5906004u, 0xE08DD000u, 0xE0866000u, 0xE28F9F5Eu, 0xE599A000u, 0xE08AA009u, 0xE5DA9000u,
    0xE5DAE001u, 0xE189940Eu, 0xE5DAE002u, 0xE5DAA003u, 0xE189980Eu, 0xE1899C0Au, 0xE28DA801u, 0xE3A05000u,
    0xE28AA901u, 0xE154000Au, 0x2A000017u, 0xE084A009u, 0xE28F9054u, 0xE15A0009u, 0x9A000013u, 0xE28AAB02u,
    0xE3CAA0FFu, 0xE24F5070u, 0xE3C5501Fu, 0xE0469005u, 0xE289901Fu, 0xE3C9901Fu, 0xE0896005u, 0xE089900Au,
    0xE9365C0Fu, 0xE1560005u, 0xE9295C0Fu, 0x8AFFFFFBu, 0xE0496006u, 0xE1A00009u, 0xE08D1006u, 0xEB00015Fu,
    0xE24F00ACu, 0xE0800006u, 0xE1A0F000u, 0xE28F00BCu, 0xE890180Eu, 0xE0400001u, 0xE1901005u, 0x0A00000Du,
    0xE08BB000u, 0xE08CC000u, 0xE0822000u, 0xE0833000u, 0xE59B1000u, 0xE0811000u, 0xE1510002u, 0x21530001u,
    0x80811005u, 0xE48B1004u, 0xE15B000Cu, 0x3AFFFFF7u, 0xE0822005u, 0xE0833005u, 0xE3A00000u, 0xE4820004u,
    0xE4820004u, 0xE4820004u, 0xE4820004u, 0xE1520003u, 0x3AFFFFF9u, 0xE3140001u, 0xE3C44001u, 0x1B00001Fu,
    0xE1A00004u, 0xE1A0100Du, 0xE28D2801u, 0xE1A03007u, 0xEB0001C1u, 0xE28F1054u, 0xE5912000u, 0xE0822001u,
};

static const uint32_t zap_dtb[] = {
    0xEDFE0DD0u, 0xEF040000u, 0x38000000u, 0x18040000u, 0x28000000u, 0x11000000u, 0x10000000u, 0x00000000u,
    0xD7000000u, 0xE0030000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x01000000u, 0x00000000u,
    0x03000000u, 0x04000000u, 0x00000000u, 0x01000000u, 0x03000000u, 0x04000000u, 0x0F000000u, 0x01000000u,
    0x03000000u, 0x1B000000u, 0x1B000000u, 0x61746973u, 0x2C6D6172u, 0x2D70617Au, 0x00636F73u, 0x706D6973u,
    0x622D656Cu, 0x00007375u, 0x03000000u, 0x30000000u, 0x26000000u, 0x2050415Au, 0x20436F53u, 0x68746977u,
    0x65704F20u, 0x726F436Eu, 0x55207365u, 0x2C545241u, 0x43495620u, 0x6954202Cu, 0x2C72656Du, 0x68744520u,
    0x0043414Du, 0x01000000u, 0x736F6863u, 0x00006E65u, 0x03000000u, 0x66000000u, 0x2C000000u, 0x736E6F63u,
    0x3D656C6Fu, 0x53797474u, 0x31312C30u, 0x30303235u, 0x72616520u, 0x6F63796Cu, 0x61753D6Eu, 0x32387472u,
    0x6D2C3035u, 0x336F696Du, 0x78302C32u, 0x66666666u, 0x30656666u, 0x3531312Cu, 0x20303032u, 0x6C676F6Cu,
    0x6C657665u, 0x6920383Du, 0x726F6E67u, 0x6F6C5F65u, 0x76656C67u, 0x69206C65u, 0x3D74696Eu, 0x696E692Fu,
    0x00000074u, 0x03000000u, 0x15000000u, 0x35000000u, 0x636F732Fu, 0x7265732Fu, 0x406C6169u, 0x66666666u,
    0x30656666u, 0x00000000u, 0x02000000u, 0x01000000u, 0x6F6D656Du, 0x31407972u, 0x30303030u, 0x00303030u,
    0x03000000u, 0x07000000u, 0x41000000u, 0x6F6D656Du, 0x00007972u, 0x03000000u, 0x08000000u, 0x4D000000u,
    0x00000010u, 0x00000010u, 0x02000000u, 0x01000000u, 0x00636F73u, 0x03000000u, 0x0B000000u, 0x1B000000u,
    0x706D6973u, 0x622D656Cu, 0x00007375u, 0x03000000u, 0x04000000u, 0x00000000u, 0x01000000u, 0x03000000u,
    0x04000000u, 0x0F000000u, 0x01000000u, 0x03000000u, 0x00000000u, 0x51000000u, 0x01000000u, 0x65746E69u,
    0x70757272u, 0x6F632D74u, 0x6F72746Eu, 0x72656C6Cu, 0x66666640u, 0x61666666u, 0x00000030u, 0x03000000u,
    0x10000000u, 0x1B000000u, 0x61746973u, 0x2C6D6172u, 0x2D70617Au, 0x00636976u, 0x03000000u, 0x08000000u,
    0x4D000000u, 0xA0FFFFFFu, 0x20000000u, 0x03000000u, 0x00000000u, 0x58000000u, 0x03000000u, 0x04000000u,
    0x6D000000u, 0x01000000u, 0x03000000u, 0x04000000u, 0x7E000000u, 0x01000000u, 0x02000000u, 0x01000000u,
    0x656D6974u, 0x66664072u, 0x66666666u, 0x00003063u, 0x03000000u, 0x12000000u, 0x1B000000u, 0x61746973u,
    0x2C6D6172u, 0x2D70617Au, 0x656D6974u, 0x00000072u, 0x03000000u, 0x08000000u, 0x4D000000u, 0xC0FFFFFFu,
    0x20000000u, 0x03000000u, 0x04000000u, 0x86000000u, 0x01000000u, 0x03000000u, 0x04000000u, 0x91000000u,
    0x01000000u, 0x03000000u, 0x04000000u, 0xA2000000u, 0x00E1F505u, 0x02000000u, 0x01000000u, 0x69726573u,
    0x66406C61u, 0x66666666u, 0x00306566u, 0x03000000u, 0x09000000u, 0x1B000000u, 0x3631736Eu, 0x61303535u,
    0x00000000u, 0x03000000u, 0x08000000u, 0x4D000000u, 0xE0FFFFFFu, 0x20000000u, 0x03000000u, 0x04000000u,
    0xB2000000u, 0x02000000u, 0x03000000u, 0x04000000u, 0xBC000000u, 0x04000000u, 0x03000000u, 0x04000000u,
    0xC9000000u, 0x00C20100u, 0x03000000u, 0x04000000u, 0xA2000000u, 0x00E1F505u, 0x03000000u, 0x04000000u,
    0x86000000u, 0x00000000u, 0x03000000u, 0x04000000u, 0x91000000u, 0x01000000u, 0x02000000u, 0x01000000u,
    0x65687465u, 0x74656E72u, 0x66666640u, 0x30306566u, 0x00000030u, 0x03000000u, 0x11000000u, 0x1B000000u,
    0x6E65706Fu, 0x65726F63u, 0x74652C73u, 0x63616D68u, 0x00000000u, 0x03000000u, 0x08000000u, 0x4D000000u,
    0x00E0FFFFu, 0x00100000u, 0x03000000u, 0x04000000u, 0x86000000u, 0x02000000u, 0x03000000u, 0x04000000u,
    0x91000000u, 0x01000000u, 0x02000000u, 0x02000000u, 0x02000000u, 0x09000000u, 0x64646123u, 0x73736572u,
    0x6C65632Du, 0x2300736Cu, 0x657A6973u, 0x6C65632Du, 0x6300736Cu, 0x61706D6Fu, 0x6C626974u, 0x6F6D0065u,
    0x006C6564u, 0x746F6F62u, 0x73677261u, 0x64747300u, 0x2D74756Fu, 0x68746170u, 0x76656400u, 0x5F656369u,
    0x65707974u, 0x67657200u, 0x6E617200u, 0x00736567u, 0x65746E69u, 0x70757272u, 0x6F632D74u, 0x6F72746Eu,
    0x72656C6Cu, 0x6E692300u, 0x72726574u, 0x2D747570u, 0x6C6C6563u, 0x68700073u, 0x6C646E61u, 0x6E690065u,
    0x72726574u, 0x73747075u, 0x746E6900u, 0x75727265u, 0x702D7470u, 0x6E657261u, 0x6C630074u, 0x2D6B636Fu,
    0x71657266u, 0x636E6575u, 0x65720079u, 0x68732D67u, 0x00746669u, 0x2D676572u, 0x772D6F69u, 0x68746469u,
    0x72756300u, 0x746E6572u, 0x6570732Du, 0x00006465u,
};
#define ZAP_DTB_WORDS (sizeof(zap_dtb) / sizeof(zap_dtb[0]))

void dram_direct_boot(void)
{
    uint32_t errors = 0;

    /* ---------------------------------------------------------------
     * Step 1: Write zImage header (128 words) to 0x10008000
     * ------------------------------------------------------------- */
#ifdef DEBUG_2
    uart_puts("\r\nWriting zImage header to 0x10008000...\r\n");
#endif
    volatile uint32_t *zimg = (volatile uint32_t *)0x10008000u;
    for (int i = 0; i < 128; i++)
        zimg[i] = zimage_hdr[i];

#ifdef DEBUG_2
    errors = 0;
    for (int i = 0; i < 128; i++) {
        if (zimg[i] != zimage_hdr[i]) {
            uart_puts("zImage MISMATCH word[");
            uart_puthex32(i);
            uart_puts("] addr=0x"); uart_puthex32(0x10008000u + i*4);
            uart_puts(" wrote=0x"); uart_puthex32(zimage_hdr[i]);
            uart_puts(" got=0x");   uart_puthex32(zimg[i]);
            uart_puts("\r\n");
            if (++errors >= 5) { uart_puts("(stopping)\r\n"); break; }
        }
    }
    if (errors == 0)
        uart_puts("zImage header OK!\r\n");
    else {
        uart_puts("zImage DRAM FAILED. Halting.\r\n");
        for (;;);
    }
#endif

    /* ---------------------------------------------------------------
     * Step 2: Write DTB to 0x10800000
     * ------------------------------------------------------------- */
#ifdef DEBUG_2
    uart_puts("Writing DTB to 0x10800000...\r\n");
#endif
    volatile uint32_t *dtb = (volatile uint32_t *)0x10800000u;
    for (uint32_t i = 0; i < ZAP_DTB_WORDS; i++)
        dtb[i] = zap_dtb[i];

#ifdef DEBUG_2
    errors = 0;
    for (uint32_t i = 0; i < ZAP_DTB_WORDS; i++) {
        if (dtb[i] != zap_dtb[i]) {
            uart_puts("DTB MISMATCH word[");
            uart_puthex32(i);
            uart_puts("] wrote=0x"); uart_puthex32(zap_dtb[i]);
            uart_puts(" got=0x");   uart_puthex32(dtb[i]);
            uart_puts("\r\n");
            if (++errors >= 5) { uart_puts("(stopping)\r\n"); break; }
        }
    }
    if (errors == 0)
        uart_puts("DTB OK!\r\n");
    else {
        uart_puts("DTB DRAM FAILED. Halting.\r\n");
        for (;;);
    }
#endif

    /* ---------------------------------------------------------------
     * Step 3: Sanity check
     * ------------------------------------------------------------- */
#ifdef DEBUG_2
    uart_puts("\r\nSanity check:\r\n");
    uart_puts("zimg[8]  = 0x"); uart_puthex32(zimg[8]);
    uart_puts(" (expect 0xEA000005)\r\n");
    uart_puts("zimg[9]  = 0x"); uart_puthex32(zimg[9]);
    uart_puts(" (expect 0x016F2818)\r\n");
    uart_puts("zimg[33] = 0x"); uart_puthex32(zimg[33]);
    uart_puts(" (expect 0xE3A00201 = ldr r0,=0x10000000)\r\n");
    uart_puts("dtb[0]   = 0x"); uart_puthex32(dtb[0]);
    uart_puts(" (expect 0xEDFE0DD0)\r\n");
#endif

    /* ---------------------------------------------------------------
     * Step 4: Jump to kernel
     * jump_to_linux() in jump_linux.s:
     *   disables MMU/cache, sets r0=0 r1=0xFFFFFFFF r2=0x10800000
     *   ldr pc, =0x10008020
     * ------------------------------------------------------------- */
#ifdef DEBUG_2
    uart_puts("\r\nJumping to Linux at 0x10008020...\r\n");
#endif
    jump_to_linux();

    for (;;);
}
