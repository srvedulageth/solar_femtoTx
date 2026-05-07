//
//  (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 3
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
//  02110-1301, USA.
//

.set USER_STACK_POINTER, 0x00003DF0
.set IRQ_STACK_POINTER,  0x00003EF0
.set FIQ_STACK_POINTER,  0x00003FF0
.set VIC_BASE_ADDRESS,   0xFFFFFFA0

.text
.global _Reset
_Reset:

_Reset   : b there
.word 4100
.word 16380
.word 0xFFF00002
.word 4101
.word 0x7fffffff
.word 0xffffffff
_Undef   : b _Undef
_Swi     : b _Swi
_Pabt    : b _Pabt
_Dabt    : b _Dabt
reserved : b reserved
irq      : b sc_call
fiq      : b sc_call

/*
 * This handler simply revectors IRQs to
 * a dedicated irq_handler function. This
 * is a common routine for IRQ and FIQ.
 */
sc_call:
sub r14, r14, #4
stmfd sp!, {r0-r12, r14}
bl irq_handler
ldmfd sp!, {r0-r12, pc}^

there:

   //bl    enable_cache
   // Enable cache (Uses a single bit to enable both caches).
   //.set ENABLE_CP_WORD, 4100
   //mov r0, #0x4
   //ldr r1, [r0]
   //mcr p15, 0, r1, c1, c1, 0
   
   // Write out identitiy section mapping. Write 16KB to register 2.
   mov r1, #1
   mov r1, r1, lsl #14
   mcr p15, 0, r1, c2, c0, 1
   
   // Set domain access control to all 1s.
   mvn r1, #0
   mcr p15, 0, r1, c3, c0, 0
   
   // Set up a section desctiptor for identity mapping that is Cachaeable.
   mov r1, #1
   mov r1, r1, lsl #14     // 16KB
   mov r2, #14             // Cacheable identity descriptor.
   str r2, [r1]            // Write identity section desctiptor to 16KB location.
   ldr r6, [r1]            // R6 holds the descriptor.
   mov r7, r1              // R7 holds the address.
   
   // Set up a section descriptor for upper 1MB of virtual address space.
   // This is identity mapping. Uncacheable.
   mov r1, #1
   mov r1, r1, lsl #14     // 16KB. This is descriptor 0.
   
   // Go to descriptor 4095. This is the address BASE + (#DESC * 4).
   .set DESCRIPTOR_IO_SECTION_OFFSET, 16380 // 4095 x 4
   mov r0, #0x8
   ldr r2,[r0]
   add r1, r1, r2
   
   // Prepare a descriptor. Descriptor = 0xFFF00002 (Uncacheable section descriptor).
   .set DESCRIPTOR_IO_SECTION, 0xFFF00002
   mov r0, #0xC
   ldr r2 ,[r0]
   str r2, [r1]
   ldr r6, [r1]
   mov r7, r1
   
   // ENABLE MMU
   .set ENABLE_MMU_CP_WORD, 4101
   mov r0, #0x10
   ldr r1, [r0]
   mcr p15, 0, r1, c1, c1, 0

// ------------------------------
// CONSTANT POOL
// ------------------------------

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
 * Setup up stack pointer.
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
ldr r0, =VIC_BASE_ADDRESS // VIC base address.
add r0, r0, #4            // Move to INT_MASK
mov r1, #0                // Prepare mask value
str r1, [r0]              // Unmask all interrupt sources.
ldr r1, [r0]              // No change to R1 value.

/*
 * Then call the main function. The main function
 * will initiallize UART0 in TX and RX.
 */
ldr sp, =USER_STACK_POINTER
bl main
here: b here

