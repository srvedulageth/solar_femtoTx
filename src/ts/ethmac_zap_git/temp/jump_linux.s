.global jump_to_linux
.func   jump_to_linux

@ void jump_to_linux(void)
@ Entered in any mode. Must be called last — no return.
jump_to_linux:

    @ 1. Disable IRQ and FIQ, switch to SVC mode
    mov r4, #0xD3           @ SVC mode, IRQ+FIQ disabled
    msr cpsr_c, r4

    @ 2. Disable MMU, D-cache, I-cache (c1, c0, 0 is correct)
    mrc p15, 0, r4, c1, c0, 0
    bic r4, r4, #0x0007     @ clear M, A, C bits (MMU, alignment, D-cache)
    bic r4, r4, #0x1000     @ clear I bit (I-cache)
    mcr p15, 0, r4, c1, c0, 0

    @ 3. Invalidate TLBs, I-cache, D-cache, drain write buffer
    mov r4, #0
    mcr p15, 0, r4, c8, c7, 0   @ invalidate TLB
    mcr p15, 0, r4, c7, c5, 0   @ invalidate I-cache
    mcr p15, 0, r4, c7, c6, 0   @ invalidate D-cache
    mcr p15, 0, r4, c7, c10, 4  @ drain write buffer

    @ 4. Set up Linux boot registers
    mov r0, #0              @ must be 0
    ldr r1, =0xFFFFFFFF     @ machine type: -1 = use DTB
    ldr r2, =0x11000000     @ DTB physical address

@ Enable I-cache and D-cache before jump
mrc p15, 0, r4, c1, c0, 0
orr r4, r4, #0x1000    @ I-cache
orr r4, r4, #0x0004    @ D-cache
mcr p15, 0, r4, c1, c0, 0


    @ 5. Jump to kernel entry point
    ldr pc, =0x10800020

.endfunc
