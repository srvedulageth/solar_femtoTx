.set USER_STACK_POINTER, 0x0000F7F0
.set IRQ_STACK_POINTER,  0x0000FBF0
.set FIQ_STACK_POINTER,  0x0000FFF0
.set VIC_BASE_ADDRESS,   0xFFFFFFA0
.set L1_TABLE_BASE,      0x00004000

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

//sc_call:
//    sub r14, r14, #4
//    stmfd sp!, {r0-r12, r14}
//    bl irq_handler
//    ldmfd sp!, {r0-r12, pc}^

sc_call:
    sub lr, lr, #4
    stmfd sp!, {r0-r12, lr}

    bl irq_handler

    ldmfd sp!, {r0-r12, lr}
    subs pc, lr, #0

there:
    // ----------------------------------------------------
    // Enable cache (single bit enables both caches in ZAP)
    // Uses test-case CP15 encoding
    // ----------------------------------------------------
    //ldr r1, =4100
    //mcr p15, 0, r1, c1, c1, 0

    // ----------------------------------------------------
    // TTBR / translation table base = 16KB aligned
    // Uses test-case CP15 encoding
    // ----------------------------------------------------
    ldr r1, =L1_TABLE_BASE
    mcr p15, 0, r1, c2, c0, 1

    // ----------------------------------------------------
    // Domain access control = all 1s
    // ----------------------------------------------------
    mvn r1, #0
    mcr p15, 0, r1, c3, c0, 0

    // ----------------------------------------------------
    // Clear all 4096 first-level descriptors
    // ----------------------------------------------------
    ldr r0, =L1_TABLE_BASE
    mov r1, #0
    mov r2, #4096    //#4096
clear_l1_loop:
    str r1, [r0], #4
    subs r2, r2, #1
    bne clear_l1_loop

    // ----------------------------------------------------
    // Descriptor 0: VA 0x00000000 -> PA 0x00000000
    // Cacheable section descriptor = 0x0000000E
    // ----------------------------------------------------
    ldr r0, =L1_TABLE_BASE
    ldr r1, =0x0000000E
    str r1, [r0]                  // entry 0

    // ----------------------------------------------------
    // Map DDR: 0x10000000 - 0x1FFFFFFF (256MB)
    // Cacheable section descriptors:
    //   entry 0x100 = 0x1000000E
    //   ...
    //   entry 0x1FF = 0x1FF0000E
    // ----------------------------------------------------
    ldr r0, =L1_TABLE_BASE
    ldr r1, =0x1000000E           // first DDR section descriptor
    mov r2, #0x100                // first section index
    mov r3, #256                  // 256 sections = 256MB

ddr_map_loop:
    str r1, [r0, r2, lsl #2]
    add r1, r1, #0x00100000       // next physical section
    add r2, r2, #1
    subs r3, r3, #1
    bne ddr_map_loop

    // ----------------------------------------------------
    // Descriptor 4095: VA 0xFFF00000 -> PA 0xFFF00000
    // Uncacheable section descriptor = 0xFFF00002
    // Covers UART/TIMER/VIC/ETH regs at 0xFFFFFFxx
    // ----------------------------------------------------
    ldr r0, =L1_TABLE_BASE
    ldr r2, =16380                // 4095 * 4
    add r0, r0, r2
    ldr r1, =0xFFF00002
    str r1, [r0]

    // ----------------------------------------------------
    // Enable MMU
    // Uses test-case CP15 encoding
    // ----------------------------------------------------
    ldr r1, =4001
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
