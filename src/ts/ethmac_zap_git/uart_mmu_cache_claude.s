/* =============================================================================
 * uart_mmu_cache.s  —  ZAP SoC startup / MMU init
 *
 * Fixes applied vs original:
 *   1. TTBR0  : c2,c0,0  (was c2,c0,1 = TTBR1)
 *   2. MMU on : c1,c0,0  (was c1,c1,0 = Auxiliary Control Register)
 *   3. TLB + cache invalidation added before MMU enable
 *   4. SVC mode (not user mode) before calling main, IRQ/FIQ masked
 *      — Linux loader must run privileged; kernel jump restores SVC anyway
 * ============================================================================= */

.set USER_STACK_POINTER, 0x0000B7F0
.set IRQ_STACK_POINTER,  0x0000BBF0
.set FIQ_STACK_POINTER,  0x0000BFF0
.set UND_STACK_POINTER,  0x0000B3F0
.set SVC_STACK_POINTER,  0x0000B3F0   /* reuse UND region; adjust if needed */
.set VIC_BASE_ADDRESS,   0xFFFFFFA0
.extern __l1_table_base

.text
.global _Reset
_Reset:

/* -------------------------------------------------------------------------
 * Exception vector table: exactly 8 words at 0x00..0x1C
 * ------------------------------------------------------------------------- */
_vectors:
    b there         /* 0x00  Reset          */
    b UNDEF         /* 0x04  Undefined      */
    b _Swi          /* 0x08  SWI            */
    b _Pabt         /* 0x0C  Prefetch abort */
    b _Dabt         /* 0x10  Data abort     */
    b reserved      /* 0x14  Reserved       */
    b sc_call       /* 0x18  IRQ            */
    b sc_call       /* 0x1C  FIQ            */

/* -------------------------------------------------------------------------
 * Undefined instruction handler
 * LR points to next instruction (not the faulting one).
 * Save, corrupt for debug visibility, restore and return.
 * ------------------------------------------------------------------------- */
UNDEF:
    @ Print 'UND' to UART then halt
    ldr r0, =0xFFFFFFE0     @ UART THR address
    mov r1, #0x55           @ 'U'
    str r1, [r0]
    mov r1, #0x4E           @ 'N'
    str r1, [r0]
    mov r1, #0x44           @ 'D'
    str r1, [r0]
    mov r1, #0x0D           @ '\r'
    str r1, [r0]
    mov r1, #0x0A           @ '\n'
    str r1, [r0]
    b UNDEF

/* Stub handlers — kept as infinite loops for debug visibility */
_Swi:     b _Swi
_Pabt:
    ldr r0, =0xFFFFFFE0
    mov r1, #0x50           @ 'P'
    str r1, [r0]
    mov r1, #0x41           @ 'A'
    str r1, [r0]
    mov r1, #0x42           @ 'B'
    str r1, [r0]
    mov r1, #0x54           @ 'T'
    str r1, [r0]
    mov r1, #0x0D
    str r1, [r0]
    mov r1, #0x0A
    str r1, [r0]
    b _Pabt

_Dabt:
    ldr r0, =0xFFFFFFE0
    mov r1, #0x44           @ 'D'
    str r1, [r0]
    mov r1, #0x41           @ 'A'
    str r1, [r0]
    mov r1, #0x42           @ 'B'
    str r1, [r0]
    mov r1, #0x54           @ 'T'
    str r1, [r0]
    mov r1, #0x0D
    str r1, [r0]
    mov r1, #0x0A
    str r1, [r0]
    b _Dabt
reserved: b reserved

/* -------------------------------------------------------------------------
 * IRQ / FIQ handler
 * r8-r14 are banked in FIQ mode, so saving r0-r7 + lr is sufficient.
 * For IRQ: sub lr,lr,#4 is the standard ARM return fixup.
 * ------------------------------------------------------------------------- */
sc_call:
    sub  r14, r14, #4
    stmfd sp!, {r0-r7, r14}
    bl   irq_handler
    ldmfd sp!, {r0-r7, pc}^

/* =============================================================================
 * Reset / startup
 * ============================================================================= */
there:
    /* -----------------------------------------------------------------
     * Set up per-mode stacks.
     * Each mode switch: clear mode bits, OR in new mode, write CPSR.
     * ----------------------------------------------------------------- */

    /* IRQ mode stack */
    mrs r2, cpsr
    bic r2, r2, #0x1F
    orr r2, r2, #0x12           /* IRQ mode = 0x12 */
    msr cpsr_c, r2
    ldr sp, =IRQ_STACK_POINTER

    /* FIQ mode stack */
    mrs r2, cpsr
    bic r2, r2, #0x1F
    orr r2, r2, #0x11           /* FIQ mode = 0x11 */
    msr cpsr_c, r2
    ldr sp, =FIQ_STACK_POINTER

    /* UND mode stack */
    mrs r2, cpsr
    bic r2, r2, #0x1F
    orr r2, r2, #0x1B           /* UND mode = 0x1B */
    msr cpsr_c, r2
    ldr sp, =UND_STACK_POINTER

    /* SVC mode — stay here for CP15 / MMU setup */
    mrs r2, cpsr
    bic r2, r2, #0x1F
    orr r2, r2, #0x13           /* SVC mode = 0x13 */
    orr r2, r2, #0xC0           /* IRQ + FIQ disabled while we init */
    msr cpsr_c, r2
    ldr sp, =SVC_STACK_POINTER

    /* -----------------------------------------------------------------
     * Preload constants before MMU enable.
     * After MMU on, avoid ldr =literal until we are in main.
     * ----------------------------------------------------------------- */
    ldr r7, =USER_STACK_POINTER
    ldr r8, =VIC_BASE_ADDRESS
    ldr r9, =__l1_table_base

    /* -----------------------------------------------------------------
     * CP15: Translation Table Base — TTBR0 (c2,c0,0)
     * FIX: original used c2,c0,1 which is TTBR1, not used by the kernel.
     * ----------------------------------------------------------------- */
    mov r1, r9
    mcr p15, 0, r1, c2, c0, 0  /* TTBR0 = L1 table base */

    /* Domain access control: all domains = Manager (no permission faults) */
    mvn r1, #0
    mcr p15, 0, r1, c3, c0, 0

    /* -----------------------------------------------------------------
     * Build 4096-entry identity L1 page table.
     * Every 1 MB section: VA == PA, uncached (C=0, B=0), section (bit1=1).
     * Descriptor bits [1:0] = 0b10 = section; AP=0b11 full access (bits 11:10).
     * 0x0E = 0b0000_1110: section, domain 0, AP=00 (no access in user — OK,
     *        we run privileged). Adjust AP bits if user-mode access needed.
     *
     * r9 = L1 table base
     * r0 = write pointer
     * r1 = physical section base (increments by 1 MB)
     * r3 = loop counter
     * ----------------------------------------------------------------- */
    mov r0, r9
    mov r1, #0
    ldr r3, =4096

L1_IDENTITY_UNCACHED_LOOP:
    orr r2, r1, #0x0E           /* section descriptor, uncached */
    str r2, [r0], #4
    add r1, r1, #0x00100000     /* next 1 MB physical section */
    subs r3, r3, #1
    bne L1_IDENTITY_UNCACHED_LOOP

    /* -----------------------------------------------------------------
     * Override DDR region 0x10000000–0x1FFFFFFF (256 MB) as UNCACHED.
     * Entry index 0x100 = offset 0x400 bytes into table.
     * ----------------------------------------------------------------- */
    ldr r6, =0x400
    add r6, r9, r6              /* r6 = &L1[0x100] */
    ldr r2, =0x10000002         /* PA 0x10000000, uncached section */
    mov r4, #256

DDR_UNCACHED_LOOP:
    str r2, [r6], #4
    add r2, r2, #0x00100000
    subs r4, r4, #1
    bne DDR_UNCACHED_LOOP

    /* Override MMIO top-MB entry (0xFFF00000) explicitly uncached */
    ldr r6, =0x3FFC
    add r6, r9, r6
    ldr r2, =0xFFF00002
    str r2, [r6]

    /* -----------------------------------------------------------------
     * Invalidate TLB, I-cache, D-cache and drain write buffer
     * BEFORE enabling the MMU.
     * FIX: these were missing in the original — stale cache lines can
     *      cause immediate prefetch/data aborts right after MMU-on.
     * ----------------------------------------------------------------- */
    mov r1, #0
    mcr p15, 0, r1, c8, c7, 0  /* invalidate unified TLB              */
    mcr p15, 0, r1, c7, c5, 0  /* invalidate I-cache                  */
    mcr p15, 0, r1, c7, c6, 0  /* invalidate D-cache                  */
    mcr p15, 0, r1, c7, c10, 4 /* drain write buffer (Data Sync Barr) */

    /* -----------------------------------------------------------------
     * Enable MMU (and I-cache if desired).
     *
     * Control register bits of interest:
     *   bit 0  (M)  = MMU enable
     *   bit 2  (C)  = D-cache enable
     *   bit 12 (I)  = I-cache enable
     *
     * 0x1000 | 0x0001 = 0x1001 = MMU + I-cache, no D-cache
     * 0x1000 | 0x0005 = 0x1005 = MMU + I-cache + D-cache
     *
     * FIX: original used c1,c1,0 (Auxiliary Control Register).
     *      Correct register is c1,c0,0 (System Control Register).
     *
     * Start with MMU + I-cache only (0x1001) until DDR is confirmed
     * stable, then switch to 0x1005 to add D-cache.
     * ----------------------------------------------------------------- */
    /* mrc p15, 0, r1, c1, c0, 0*/  /* read current control register */
    /* orr r1, r1, #0x0001*/         /* set M bit: MMU on             */
    /* orr r1, r1, #0x1000*/         /* set I bit: I-cache on         */
    /*DO NOT UNCOMMENT orr r1, r1, #0x0004 */   /* set C bit: D-cache on (enable later) */
    /* mcr p15, 0, r1, c1, c0, 0*/  /* write back — MMU now enabled  */

    /*ldr r1, =4101
    mcr p15, 0, r1, c1, c1, 0*/

    /* ----------------------------------------------------------------
     * From here: ldr =literal is safe again because the identity map
     * means VA == PA, so literal pools in flash/ROM are still reachable.
     * ---------------------------------------------------------------- */

    /* -----------------------------------------------------------------
     * Unmask all interrupts in VIC (preloaded in r8).
     * VIC_BASE + 4 = interrupt enable register.
     * Write 0 to enable all; read back to confirm.
     * ----------------------------------------------------------------- */
    mov r0, r8
    add r0, r0, #4
    mov r1, #0
    str r1, [r0]
    ldr r1, [r0]                /* readback (optional debug confirmation) */

    /* -----------------------------------------------------------------
     * Stay in SVC mode with interrupts enabled and call C main().
     * Rationale: the UART loader is privileged code; it maps DRAM,
     * receives blobs, then calls jump_to_linux() which sets the final
     * CPU state (SVC, IRQ/FIQ off) before jumping to the kernel.
     * Switching to user mode here would prevent CP15 access in loader.
     * ----------------------------------------------------------------- */
    mrs r1, cpsr
    bic r1, r1, #0xC0           /* enable IRQ + FIQ */
    msr cpsr_c, r1

    mov sp, r7                  /* set SVC stack pointer */

    /* Zero .bss */
    ldr r0, =__bss_start
    ldr r1, =__bss_end
    mov r2, #0
    bss_zero_loop:
    cmp r0, r1
    strlt r2, [r0], #4
    blt bss_zero_loop

    bl main

halt:
    b halt
