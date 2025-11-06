/* ethmac_start.s — minimal ARM startup (vectors, stacks, IRQ revector)
 * Works like your uart.s, but generic for EthMAC bring-up.
 * Expects a C function:  void irq_handler(void);
 */

.set USER_SP, 0x00002000
.set IRQ_SP,  0x00003000
.set FIQ_SP,  0x00004000

/* Arty ZAP SoC VIC base matches your other startup */
.set VIC_BASE, 0xFFFFFFA0

    .text
    .global _Reset

_Reset:
_Reset   : b there
_Undef   : b _Undef
_Swi     : b _Swi
_Pabt    : b _Pabt
_Dabt    : b _Dabt
reserved : b reserved
irq      : b sc_call         /* both IRQ/FIQ go to the same C handler */
fiq      : b sc_call

/* Common IRQ/FIQ trampoline -> C */
sc_call:
    sub     r14, r14, #4
    stmfd   sp!, {r0-r12, r14}
    bl      irq_handler
    ldmfd   sp!, {r0-r12, pc}^

/* (optional) simple stubs
_Undef: b _Undef
_Swi:   b _Swi
_Pabt:  b _Pabt
_Dabt:  b _Dabt
*/

there:
    /* Switch to IRQ mode and set SP */
    mrs     r2, cpsr
    bic     r2, r2, #31
    orr     r2, r2, #18
    msr     cpsr_c, r2
    ldr     sp, =IRQ_SP

    /* Switch to FIQ mode and set SP */
    mrs     r2, cpsr
    bic     r2, r2, #31
    orr     r2, r2, #17
    msr     cpsr_c, r2
    ldr     sp, =FIQ_SP

    /* Enter User mode with IRQ/FIQ enabled and set SP */
    mrs     r2, cpsr
    bic     r2, r2, #31        /* clear mode */
    orr     r2, r2, #16        /* User mode */
    bic     r2, r2, #0xC0      /* enable IRQ+FIQ */
    msr     cpsr_c, r2
    ldr     sp, =USER_SP

    /* Unmask interrupts in VIC (mask=0 => enable all; or write your mask) */
    ldr     r0, =VIC_BASE
    add     r0, r0, #4         /* INT_MASK register */
    mov     r1, #0
    str     r1, [r0]

    /* Optionally clear any pending IRQs */
    sub     r0, r0, #4         /* back to base = VIC_BASE */
    add     r0, r0, #8         /* PENDING_CLR register (per your other test) */
    mvn     r1, #0             /* 0xFFFFFFFF */
    str     r1, [r0]

    /* Call C entry */
    bl      main

hang:
    b       hang
