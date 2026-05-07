.set USER_STACK_POINTER, 0x0000B7F0
.set IRQ_STACK_POINTER,  0x0000BBF0
.set FIQ_STACK_POINTER,  0x0000BFF0
.set UND_STACK_POINTER,  0x0000B3F0
.set VIC_BASE_ADDRESS,   0xFFFFFFA0
.extern __l1_table_base

.text
.global _Reset
_Reset:

/* Exception vector table: exactly 8 words at 0x00..0x1c */
_Reset   : b there
_Undef   : b UNDEF
_Swi     : b _Swi
_Pabt    : b _Pabt
_Dabt    : b _Dabt
reserved : b reserved
irq      : b sc_call
fiq      : b sc_call

UNDEF:
// Undefined vector.
// LR Points to next instruction.
stmfa sp!, {r0-r12, r14}

// Corrupt registers.
mov r0, #1
mov r1, #2
mov r2, #3
mov r3, #4
mov r4, #5
mov r5, #6
mov r6, #7
mov r7, #8
mov r8, #9
mov r9, #10
mov r10, #12
mov r11, #13
mov r12, #14
mov r14, #15

// Restore them.
ldmfa sp!, {r0-r12, pc}^

/* Trap handlers: keep simple for debug
SWI:
    b SWI
PABT:
    b PABT
DABT:
    b DABT
*/

/* IRQ handler: ZAP/factorial-style return
IRQ:
    sub r14, r14, #4
    stmfd sp!, {r0-r12, r14}
    bl irq_handler
    ldmfd sp!, {r0-r12, pc}^
*/

/* FIQ handler: r8-r14 are banked in FIQ, save only r0-r7 + lr */
sc_call:
    sub r14, r14, #4
    stmfd sp!, {r0-r7, r14}
    bl irq_handler
    ldmfd sp!, {r0-r7, pc}^

/* ------------------------------------------------------------------------- */
/* Reset/startup                                                             */
/* ------------------------------------------------------------------------- */
there:
    /* IRQ stack */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #18
    msr cpsr_c, r2
    ldr sp, =IRQ_STACK_POINTER

    /* FIQ stack */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #17
    msr cpsr_c, r2
    ldr sp, =FIQ_STACK_POINTER

    /* UND stack; stay privileged for CP15 setup */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #27
    msr cpsr_c, r2
    ldr sp, =UND_STACK_POINTER

    /* Preload constants BEFORE MMU/cache enable.
     * After enable, avoid all literal-pool loads until main.
     */
    ldr r7,  =USER_STACK_POINTER
    ldr r8,  =VIC_BASE_ADDRESS
    ldr r9,  =__l1_table_base

    /* --------------------------------------------------------------------- */
    /* CP15 setup while privileged                                            */
    /* --------------------------------------------------------------------- */
    /* Translation table base */
    mov r1, r9
    mcr p15, 0, r1, c2, c0, 1

    /* Domain access control = all 1s */
    mvn r1, #0
    mcr p15, 0, r1, c3, c0, 0

    /* --------------------------------------------------------------------- */
    /* Build a COMPLETE 4096-entry identity L1 table.                         */
    /* Default every 1MB section as UNCACHED identity.                         */
    /* This prevents garbage/uninitialized descriptors from redirecting        */
    /* instruction/data fetches into DRAM.                                     */
    /*                                                                        */
    /* r9  = L1 table base                                                    */
    /* r0  = write pointer                                                    */
    /* r1  = physical section base/descriptor                                 */
    /* r3  = countdown                                                        */
    /* --------------------------------------------------------------------- */
    mov r0, r9
    mov r1, #0
    ldr r3, =4096
L1_IDENTITY_UNCACHED_LOOP:
    orr r2, r1, #0x0E          /* section descriptor, C/B clear */
    str r2, [r0], #4
    add r1, r1, #0x00100000    /* next physical 1MB section base */
    subs r3, r3, #1
    bne L1_IDENTITY_UNCACHED_LOOP

    /* Override first DDR MB uncached */
    ldr r6, =0x400
    add r6, r9, r6
    ldr r2, =0x10000002
    str r2, [r6]

    /* MMIO entry is already uncached from identity loop, but write explicitly:
     * entry 0xFFF = __l1_table_base + 0x3FFC -> 0xFFF00002
     */
    ldr r6, =0x3FFC
    add r6, r9, r6
    ldr r2, =0xFFF00002
    str r2, [r6]

    /* entry 0x200 maps VA 0x20000000 -> PA 0x00000000 FOR TESTING */
    ldr r6, =0x800          /* 0x200 * 4 */
    add r6, r9, r6
    ldr r2, =0x0000000E
    str r2, [r6]

    /* --------------------------------------------------------------------- */
    /* Enable MMU/cache control word.                                         */
    /*                                                                        */
    /* 4001 = MMU only on your ZAP debug                                      */
    /* 4101 = MMU + caches on your ZAP debug                                  */
    /*                                                                        */
    /* Start with 4001 until interrupts + EthMAC are stable; then try 4101.    */
    /* --------------------------------------------------------------------- */
    ldr r1, =4101
    /* ldr r1, =4101 */
    mcr p15, 0, r1, c1, c1, 0

    /* Do not use ldr =literal after this point. */

    /* Switch to user mode with interrupts enabled */
    mrs r1, cpsr
    bic r1, r1, #31
    orr r1, r1, #16
    bic r1, r1, #0xC0
    msr cpsr_c, r1
    mov sp, r7

    /* Unmask all interrupts in the VIC using preloaded r8 */
    mov r0, r8
    add r0, r0, #4
    mov r1, #0
    str r1, [r0]
    ldr r1, [r0]

    /* Call C main */
    bl main

here:
    b here
