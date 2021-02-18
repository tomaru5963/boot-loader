#include "boot.h"
#include "fat12.h"

        .code16
        .globl  _start
_start:
        cli
        movw    $BOOT2_SEG, %ax
        movw    %ax, %ds
        movw    %ax, %es
        /*
         * Keep %ss:%sp because we keep using the setting for the first stage
         * loader
         */

        /* Make sure %cs is 0x1000 */
        ljmpw   $BOOT2_SEG, $1f
1:
        sti
        movw    $banner, %si
        xorb    %ah, %ah
        int     $0x21

        /* Look for the kernel */
        pushw   %es
        movw    $kernel, %si
        movw    $DIRECTORY_ENTRIES, %cx
        movw    $DIRECTORY_SEG, %ax
        movw    %ax, %es
        movw    $DIRECTORY_OFFSET, %bx
        movb    $2, %ah
        int     $0x21
        jc      hang
        popw    %es

        /* Load the kernel image into 0x20000 */
        pushw   %ds
        pushw   %es
        movw    %ax, %dx
        movw    $FAT12_SEG, %ax
        movw    %ax, %ds
        movw    $FAT12_OFFSET, %si
        movw    $KERNEL_SEG, %ax
        movw    %ax, %es
        movw    $KERNEL_OFFSET, %bx
        movb    $3, %ah
        int     $0x21
        popw    %es
        popw    %ds

        /*
         * Enable A20 line
         *
         * Somehow qemu-system-i386 alread enable A20 without doing anything.
         * The following method is using a BIOS function. This works for
         * VirtualBox.
         */
        movw    $0x2401, %ax
        int     $0x15

        /*
         * How to check if A20 is enabled
         *
         * The boot record signature 0xaa55 is located at 0x0000:0x7def. If
         * A20 is enabled, the value at 0x107def is not 0xaa55. Here 0x107def
         * is 0xffff:7e0e.
         */
        /*
        movw    $0xffff, %ax
        movw    %ax, %es
        movw    $0x7e0e, %bx
        movw    %es:(%bx), %ax
        cmpw    $0xaa55, %ax
        jne     enabled
        disabled
        */

        /* Get information about memory regions */
        /* Store it at %es:%di = 0x1000:0x1000 */
        movw    $(SMAP_OFFSET + SMAP_ENT_SIZE), %di
        xorw    %bp, %bp
        xorl    %ebx, %ebx
        movl    $SMAP_MAGIC, %edx
2:
        movb    $0x01, SMAP_ENT_ACPI_EXT_OFFSET(%di)
        movl    $SMAP_ENT_SIZE, %ecx
        movl    $0xe820, %eax
        int     $0x15
        jc      hang
        movl    $SMAP_MAGIC, %edx
        cmpl    %edx, %eax
        jne     hang
        orb     %cl, %cl
        jz      3f                      /* No valid info. Ignore it */
        incw    %bp
        addw    $SMAP_ENT_SIZE, %di
3:
        orl     %ebx, %ebx
        jnz     2b
        movw    %bp, SMAP_OFFSET        /* Number of the entries */

        /*
         * Switch to protected mode
         */

        /* Adjust address of pm32 and gdt */
        xorl    %ebx, %ebx
        movw    %cs, %bx
        movw    %bx, %ds
        shll    $4, %ebx
        addl    %ebx, 8f
        addl    %ebx, 9f

        /* Pass %ss * 16 to 32-bit mode via %edx */
        xorl    %edx, %edx
        movw    %ss, %dx
        shll    $4, %edx

        /* Disable interrupts */
        cli
        inb     $0x70, %al
        orb     $0x80, %al
        outb    %al, $0x70              /* Disable NMI */

        lgdt    gdt_desc
        movl    %cr0, %eax
        orb     $1, %al
        movl    %eax, %cr0

        /* Transition to 32 bit protected mode */
        .byte   0x66, 0xea              /* ljmpl opcode */
8:      .long   pm32                    /* Offset */
        .word   KERNEL_CS               /* Segment */

hang:
        movb    $0xff, %ah
        int     $0x21

banner: .string "Second boot loader\r\n"
kernel: .string "KERNEL  BIN"

        .code32
        .balign 4
pm32:
        /*
         * Here IF flag is off and NMI is disabled
         * %edx = %ss in the real mode * 16
         * %esp is still the same value which was set in the first loader
         */
        movl    $KERNEL_DS, %ecx
        movl    %ecx, %ds
        movl    %ecx, %es
        movl    %ecx, %fs
        movl    %ecx, %gs
        movl    %ecx, %ss

        /* Align %esp to the boundary and let it point to the flat address */
        andl    $~2, %esp
        addl    %edx, %esp

        /* Clear registers */
        xorl    %ebx, %ebx
        xorl    %ecx, %ecx
        xorl    %edx, %edx
        xorl    %ebp, %ebp
        xorl    %esi, %esi
        xorl    %edi, %edi

        / Jump to kernel code */
        movl    $KERNEL_ADDR, %eax
        jmpl    *%eax

        /* Never reach here */
        cli
1:
        hlt
        jmp     1b

gdt_desc:
        .word   gdt_size - 1
9:      .long   gdt

        .balign 16
gdt:
        .quad   0                       /* Null entry */

        /*
         * Code segment
         * base = 0x00000000
         * segment limit = 0xffffffff
         */
        .word   0xffff
        .word   0
        .byte   0
        /*
         * Present bit: 1 (valid)
         * Privilege level: 00b (highest)
         * Descriptor type: 1 (code or data segment)
         * Executable bit: 1 (executable)
         * Direction bit/Conforming bit: 0 (no conforming)
         * Readable bit/Writable bit: 1 (readable)
         * Accessed bit: 0
         */
        .byte   0x9a
        /*
         * Granularity bit: 1 (4KiB - size of one page)
         * Size bit: 1 (32bit protected mode)
         * unused 2 bits
         * limit 4 last bits
         */
        .byte   0b11001111
        .byte   0

        /*
         * Data segment
         * base = 0x00000000
         * segment limit = 0xffffffff
         */
        .word   0xffff
        .word   0
        .byte   0
        /*
         * Present bit: 1 (valid)
         * Privilege level: 00b (highest)
         * Descriptor type: 1 (code or data segment)
         * Executable bit: 0 (data)
         * Direction bit/Conforming bit: 0 (the segment grows up)
         * Readable bit/Writable bit: 1 (writable)
         * Accessed bit: 0
         */
        .byte   0x92
        /*
         * Granularity bit: 1 (4KiB - size of one page)
         * Size bit: 1 (32bit protected mode)
         * unused 2 bits
         * limit 4 last bits
         */
        .byte   0b11001111
        .byte   0
gdt_size = . - gdt
