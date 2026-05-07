.set USER_STACK_POINTER, 0x0000B7F0
.set IRQ_STACK_POINTER,  0x0000BBF0
.set FIQ_STACK_POINTER,  0x0000BFF0
.set UND_STACK_POINTER,  0x0000B3F0
.set VIC_BASE_ADDRESS,   0xFFFFFFA0
.extern __l1_table_base

.text
.global _Reset
_Reset:

/* Exception vector table: keep this exactly 8 words at 0x00..0x1c */
_Reset   : b there
_Undef   : b UNDEF
_Swi     : b SWI
_Pabt    : b PABT
_Dabt    : b DABT
reserved : b _Reset
irq      : b IRQ
fiq      : b FIQ

/* ------------------------------------------------------------------------- */
/* Minimal trap handlers                                                     */
/* ------------------------------------------------------------------------- */
UNDEF:
    stmfa sp!, {r0-r12, r14}
    ldmfa sp!, {r0-r12, pc}^

SWI:
    stmfd sp!, {r0-r12, r14}
    ldmfd sp!, {r0-r12, pc}^

PABT:
    b PABT

DABT:
    b DABT

/* ------------------------------------------------------------------------- */
/* IRQ handler: modelled after ZAP factorial.s                               */
/* Calls C irq_handler(), then returns with pc^ to restore CPSR from SPSR.    */
/* ------------------------------------------------------------------------- */
IRQ:
    sub r14, r14, #4
    stmfd sp!, {r0-r12, r14}

    bl irq_handler

    ldmfd sp!, {r0-r12, pc}^

/* ------------------------------------------------------------------------- */
/* FIQ handler: modelled after ZAP factorial.s                               */
/* In FIQ mode, r8-r14 are banked, so only save r0-r7 plus return lr.         */
/* If you do not use FIQ, this is still safe.                                 */
/* ------------------------------------------------------------------------- */
FIQ:
    sub r14, r14, #4
    stmfd sp!, {r0-r7, r14}

    bl irq_handler

    ldmfd sp!, {r0-r7, pc}^

/* ------------------------------------------------------------------------- */
/* Reset/startup                                                             */
/* ------------------------------------------------------------------------- */
there:
    /* Switch to IRQ mode and set IRQ stack */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #18
    msr cpsr_c, r2
    ldr sp, =IRQ_STACK_POINTER

    /* Switch to FIQ mode and set FIQ stack */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #17
    msr cpsr_c, r2
    ldr sp, =FIQ_STACK_POINTER

    /* Switch to UND mode and set UND stack */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #27
    msr cpsr_c, r2
    ldr sp, =UND_STACK_POINTER

    /* Stay in privileged UND mode for CP15 setup.                            */
    /* IMPORTANT: Do not switch to user mode before CP15 mcr operations.      */
    /* ZAP factorial.s performs cache/MMU setup while still privileged,       */
    /* then switches to user mode afterwards.                                 */

    /* --------------------------------------------------------------------- */
    /* Enable cache first, exactly like ZAP factorial.s.                      */
    /* 4100 enables both caches in the original test.                         */
    /* --------------------------------------------------------------------- */
    //.set ENABLE_CACHE_CP_WORD, 4100
    //ldr r1, =ENABLE_CACHE_CP_WORD
    //mcr p15, 0, r1, c1, c1, 0

    /* Translation table base = 0x4000, same CP15 encoding as factorial.s */
    ldr r1, =__l1_table_base
    mcr p15, 0, r1, c2, c0, 1

    /* Domain access control = all 1s */
    mvn r1, #0
    mcr p15, 0, r1, c3, c0, 0

    /* --------------------------------------------------------------------- */
    /* DO NOT clear the whole L1 table here.                                  */
    /* This follows factorial.s and avoids overwriting anything unexpectedly.  */
    /* We only write descriptors that this bare-metal Ethernet test needs.     */
    /* --------------------------------------------------------------------- */

    /* Descriptor 0: VA 0x00000000 -> PA 0x00000000, cacheable identity map */
    ldr r1, =__l1_table_base
    mov r2, #14
    //mov r2, #2
    str r2, [r1]

    /* Descriptor 0x100: first DDR MB 0x10000000 -> 0x10000000.               */
    /* Use UNCACHED because your EthMAC packet buffers begin in this section.  */
    ldr r1, =__l1_table_base
    ldr r2, =0x10000002
    ldr r3, =0x100
    str r2, [r1, r3, lsl #2]

    /* Descriptors 0x101..0x1ff: remaining DDR cacheable.                     */
    /* Comment this loop out if you want all DDR uncached for first debug.     */
    ldr r1, =__l1_table_base
    ldr r2, =0x1010000E
    ldr r3, =0x101
    mov r4, #255
DDR_CACHEABLE_LOOP:
    str r2, [r1, r3, lsl #2]
    add r2, r2, #0x00100000
    add r3, r3, #1
    subs r4, r4, #1
    bne DDR_CACHEABLE_LOOP

    /* Descriptor 4095: VA 0xfff00000 -> PA 0xfff00000, uncached MMIO.        */
    /* Covers UART, TIMER, VIC, EthMAC regs, and internal EthMAC BD RAM.       */
    ldr r1, =__l1_table_base
    ldr r2, =16380
    add r1, r1, r2
    ldr r2, =0xFFF00002
    str r2, [r1]

    /* preload user SP before MMU/cache enable */
    ldr r7, =USER_STACK_POINTER

    /* ENABLE MMU + caches, exactly like ZAP factorial.s */
    //.set ENABLE_MMU_CP_WORD, 4101
    ldr r1, =4101
    mcr p15, 0, r1, c1, c1, 0

    /* Now switch to user mode with interrupts enabled and set user stack. */
    mrs r1, cpsr
    bic r1, r1, #31
    orr r1, r1, #16
    bic r1, r1, #0xC0
    msr cpsr_c, r1
    ldr sp, =USER_STACK_POINTER

    /* no memory read here */
    mov sp, r7

    /* Unmask all interrupts in the VIC */
    ldr r0, =VIC_BASE_ADDRESS
    add r0, r0, #4
    mov r1, #0
    str r1, [r0]
    ldr r1, [r0]

    /* Call C main */
    bl main

here:
    b here
