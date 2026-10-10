.global jump_to_linux
.func   jump_to_linux

jump_to_linux:

    @ 1. SVC mode, IRQ/FIQ disabled
    mov r4, #0xD3
    msr cpsr_c, r4

    @ 2. Drain write buffer
    mov r4, #0
    mcr p15, 0, r4, c7, c10, 4

    @ 3. Disable MMU, I-cache, D-cache
    mrc p15, 0, r4, c1, c0, 0
    bic r4, r4, #0x1000
    bic r4, r4, #0x0007
    mcr p15, 0, r4, c1, c0, 0

    @ 4. Invalidate TLB, caches, drain
    mov r4, #0
    mcr p15, 0, r4, c8, c7, 0
    mcr p15, 0, r4, c7, c5, 0
    mcr p15, 0, r4, c7, c6, 0
    mcr p15, 0, r4, c7, c10, 4

    @ 5. Boot registers
    mov r0, #0
    mvn r1, #0
    mov r2, #0x10400000

    @ 6. Jump — avoid literal pool, use register directly
    mov r3, #0x10800000
    orr r3, r3, #0x00000020
    nop
    nop
    nop
    mov pc, r3

.endfunc
