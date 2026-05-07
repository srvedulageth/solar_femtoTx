.set USER_STACK_POINTER, 0x0000F7F0
.set IRQ_STACK_POINTER,  0x0000FBF0
.set FIQ_STACK_POINTER,  0x0000FFF0
.set VIC_BASE_ADDRESS,   0xFFFFFFA0

.text
.global _Reset
_Reset:

_Reset   : b there
_Undef   : b _Undef
_Swi     : b _Swi
_Pabt    : b _Pabt
_Dabt    : b _Dabt
reserved : b reserved
irq      : b sc_call
fiq      : b sc_call

sc_call:
    sub r14, r14, #4
    stmfd sp!, {r0-r12, r14}
    bl irq_handler
    ldmfd sp!, {r0-r12, pc}^

there:
    // Enable cache (single bit enables both caches in ZAP)
    ldr r1, =4100
    mcr p15, 0, r1, c1, c1, 0

    // Write out identity section mapping base = 16KB
    ldr r1, =0x00004000 //L1_TABLE_BASE
    mcr p15, 0, r1, c2, c0, 1

    // Set domain access control to all 1s
    mvn r1, #0
    mcr p15, 0, r1, c3, c0, 0

    // Descriptor 0: cacheable identity mapping
    ldr r1, =0x00004000
    mov r2, #14
    str r2, [r1]
    ldr r6, [r1]            // R6 holds the descriptor.
    mov r7, r1              // R7 holds the address.

    // Set up a section descriptor for upper 1MB of virtual address space.
    // This is identity mapping. Uncacheable.
    mov r1, #1
    mov r1, r1, lsl #14     // 16KB. This is descriptor 0.

    // Descriptor 4095: top 1MB uncached
    ldr r1, =0x00004000
    ldr r2, =16380
    add r1, r1, r2
    ldr r2, =0xFFF00002
    str r2, [r1]
    ldr r6, [r1]
    mov r7, r1

    // Enable MMU
    ldr r1, =4101
    mcr p15, 0, r1, c1, c1, 0

    /*
     * Switch to IRQ mode.
     * Set up stack pointer.
     */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #18
    msr cpsr_c, r2
    ldr sp, =IRQ_STACK_POINTER

    /*
     * Switch to FIQ mode.
     * Set up stack pointer.
     */
    mrs r2, cpsr
    bic r2, r2, #31
    orr r2, r2, #17
    msr cpsr_c, r2
    ldr sp, =FIQ_STACK_POINTER

    /*
     * Switch to user mode with interrupts enabled.
     * Set up stack pointer.
     */
    mrs r1, cpsr
    bic r1, r1, #31
    orr r1, r1, #16
    bic r1, r1, #0xC0
    msr cpsr_c, r1

    /*
     * Unmask all interrupts in the VIC.
     */
    ldr r0, =VIC_BASE_ADDRESS
    add r0, r0, #4
    mov r1, #0
    str r1, [r0]
    ldr r1, [r0]

    /*
     * Then call the main function.
     */
    ldr sp, =USER_STACK_POINTER
    bl main

here:
    b here

