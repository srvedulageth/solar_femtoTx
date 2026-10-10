/* dram_direct_boot_sim.c
 * Writes zImage header to BOTH 0x10008000 AND 0x10800000
 * Writes DTB to 0x10400000
 * Jumps to 0x10800020
 *
 * What we want to see:
 * 1. CPU fetches from 0x10800020 (I-cache) - confirms jump worked
 * 2. CPU executes EA000005 (branch at 0x10800020) - zImage entry
 * 3. CPU fetches from 0x1080003C (branch target) - decompressor running
 * 4. Eventually CPU fetches from 0x10008000 - kernel entry
 */

#include <stdint.h>
#include "uart.h"

extern void jump_to_linux(void);

static const uint32_t zimage_hdr[128] = {
    0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u, 0xE1A00000u,
    0xEA000005u, 0x016F2818u, 0x00000000u, 0x0018C4B0u, 0x04030201u, 0x45454545u, 0x00006F60u, 0xE10F9000u,
    0xE1A07001u, 0xE1A08002u, 0xE10F2000u, 0xE3120003u, 0x1A000001u, 0xE3A00017u, 0xEF123456u, 0xE321F0D3u,
    0xE16FF009u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u,
    0xE1A0000Fu, 0xE3A00201u, 0xE28F1F6Du, 0xE591D000u, 0xE08DD001u, 0xE1A01008u, 0xEB001A28u, 0xE2804902u,
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
    0xE1A00004u, 0xE1A0100Du, 0xE28D2801u, 0xE1A03007u, 0xEB0001C2u, 0xE28F1054u, 0xE5912000u, 0xE0822001u,
};

/* Minimal DTB — just enough for fdt_check_mem_start to work */
static const uint32_t zap_dtb[] = {
    0xEDFE0DD0u, 0xFC040000u, 0x38000000u, 0x14040000u, 0x28000000u,
    0x11000000u, 0x10000000u, 0x00000000u, 0xE8000000u, 0xDC030000u,
};
#define ZAP_DTB_WORDS (sizeof(zap_dtb) / sizeof(zap_dtb[0]))

void dram_direct_boot(void)
{
#ifdef DEBUG_2
    uart_puts("\r\n=== dram_direct_boot ===\r\n");
#endif

    /* ---------------------------------------------------------------
     * Step 1: Write zImage header to 0x10008000
     * (kernel decompressed destination)
     * ------------------------------------------------------------- */
#ifdef DEBUG_2
    uart_puts("Writing zImage to 0x10008000...\r\n");
#endif

    volatile uint32_t *zimg_dst = (volatile uint32_t *)0x10008000u;
    for (int i = 0; i < 128; i++)
        zimg_dst[i] = zimage_hdr[i];

#ifdef DEBUG_2
    uart_puts("0x10008020=0x"); uart_puthex32(zimg_dst[8]);
    uart_puts(" (expect 0xEA000005 = branch)\r\n");
#endif

    /* ---------------------------------------------------------------
     * Step 2: Write zImage header to 0x10800000
     * (zImage load address - where jump_to_linux jumps to)
     * We want to see I-cache fetch from 0x10800020 in simulation
     * ------------------------------------------------------------- */
#ifdef DEBUG_2
    uart_puts("Writing zImage to 0x10800000...\r\n");
#endif

    volatile uint32_t *zimg_load = (volatile uint32_t *)0x10800000u;
    for (int i = 0; i < 128; i++)
        zimg_load[i] = zimage_hdr[i];

#ifdef DEBUG_2
    uart_puts("0x10800020=0x"); uart_puthex32(zimg_load[8]);
    uart_puts(" (expect 0xEA000005 = branch)\r\n");
#endif

    /* ---------------------------------------------------------------
     * Step 3: Write DTB magic to 0x10400000
     * (just enough for fdt_check_mem_start to validate)
     * ------------------------------------------------------------- */
#ifdef DEBUG_2
    uart_puts("Writing DTB to 0x10400000...\r\n");
#endif

    volatile uint32_t *dtb = (volatile uint32_t *)0x10400000u;
    for (uint32_t i = 0; i < ZAP_DTB_WORDS; i++)
        dtb[i] = zap_dtb[i];

#ifdef DEBUG_2
    uart_puts("0x10400000=0x"); uart_puthex32(dtb[0]);
    uart_puts(" (expect 0xEDFE0DD0 = FDT magic)\r\n");
#endif

    /* ---------------------------------------------------------------
     * Step 4: Jump to zImage entry
     * jump_to_linux() does:
     *   mov r3, #0x10800000
     *   orr r3, r3, #0x20      <- r3 = 0x10800020
     *   nop / nop / nop
     *   mov pc, r3             <- JUMP
     *
     * What we want to see in simulation/waveform:
     *   1. I-cache fetch from 0x10800020 (EA000005 = branch)
     *   2. I-cache fetch from 0x1080003C (branch target)
     *   3. I-cache fetch from 0x10800084 (our RAM base patch)
     *   4. Eventually 0x10008000 (kernel entry)
     * ------------------------------------------------------------- */
#ifdef DEBUG_2
    uart_puts("\r\nJumping to 0x10800020...\r\n");
    uart_puts("Watch for I-cache fetches:\r\n");
    uart_puts("  0x10800020 = zImage entry\r\n");
    uart_puts("  0x1080003C = branch target\r\n");
    uart_puts("  0x10800084 = RAM base patch\r\n");
    uart_puts("  0x10008000 = kernel entry (goal!)\r\n");
#endif

    jump_to_linux();

    for (;;);
}
