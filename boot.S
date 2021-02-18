#include "boot.h"
#include "fat12.h"

        .code16
        .globl  _start
_start:
        cli
        movw    $BOOT_SEG, %ax
        movw    %ax, %ds
        movw    %ax, %es
        movw    %ax, %ss
        movw    $BOOT_STACK_START, %sp
        /* Set CS to 0x0 */
        ljmpw   $BOOT_SEG, $1f
1:
        /* Setup the interrupt vector for int 0x21 */
        movw    $0x21, %bx
        shlw    $2, %bx
        movw    $handle_21, (%bx)
        addw    $2, %bx
        movw    $0, (%bx)

        sti
        movw    $banner, %si
        xorb    %ah, %ah
        int     $0x21

        /*
         * Read FAT12 at 0x7e00
         * from sector 1, 9 sectors
         */
        movw    $1, %dx
        movw    $9, %cx
        movw    $FAT12_OFFSET, %bx
        movb    $1, %ah
        int     $0x21

        /*
         * Read Root directory at 0x9000
         * from sector 19, 14 sectors
         */
        movw    $19, %dx
        movw    $14, %cx
        movw    $DIRECTORY_OFFSET, %bx
        movb    $1, %ah
        int     $0x21

        /* Look for the second stage boot loader */
        movw    $boot2, %si
        movw    $DIRECTORY_ENTRIES, %cx
        movw    $DIRECTORY_OFFSET, %bx
        movb    $2, %ah
        int     $0x21
        jc      hang

        /* Load the second stage loader into 0x10000 */
        movw    %ax, %dx
        movw    $FAT12_OFFSET, %si
        movw    $BOOT2_SEG, %ax
        movw    %ax, %es
        movw    $BOOT2_OFFSET, %bx
        movb    $3, %ah
        int     $0x21

        /* Jump to the second stage */
        ljmpw   $BOOT2_SEG, $BOOT2_OFFSET

hang:
        movw    $fatal, %si
        xorw    %ax, %ax
        movw    %ax, %ds
        int     $0x21
        cli
2:
        hlt
        jmp     2b

handle_21:
        cmpb    $0, %ah
        je      puts
        cmpb    $1, %ah
        je      read_sectors
        cmpb    $2, %ah
        je      look_up_filename
        cmpb    $3, %ah
        je      read_file

        /* Return to "hang" */
        movw    %sp, %bp
        movw    $hang, (%bp)
        movw    $BOOT_SEG, 2(%bp)
        iretw

        /*
         * Print a string terminated with '\0'
         *
         * %ds:%si - String to be displayed
         */
puts:
        lodsb
        orb     %al, %al
        jz      1f
        callw   putc
        jmp     puts
1:
        iretw
putc:
        movb    $0x0e, %ah
        sti
        int     $0x10
        cli
        retw

        /*
         * Read consecutive sectors from floppy drive A
         *
         * %dx - Start sector (LBA)
         * %cx - Number of sectors to be read
         * %es:%bx - Address where data is stored
         */
read_sectors:
        pushw   %dx
        pushw   %cx

        /*
         * LBA to CHS
         * temp = LBA / (sectors per track)
         * sector = (LBA % (sectors per track)) + 1
         * head = temp % (number of heads)
         * cylinder = temp / (number of heads)
         * Here "sectors per track" is 18 for 3.5inch 1.44Mi floppy disk, 36
         * for 2.88Mi. "number of heads" is 2 for the both
         */
        movw    %dx, %ax
        /* %dh: sectors per track, %dl: num of heads */
        movw    $((18 << 8) | 2), %dx
        divb    %dh                     /* %al: temp, %ah: remainder */
        incb    %ah
        movb    %ah, %cl                /* sector */
        xorb    %ah, %ah
        divb    %dl                     /* %al: cylinder, %ah: head */
        movb    %al, %ch                /* cylinder */
        movb    %ah, %dh                /* head */
        xorb    %dl, %dl                /* drive A */
        movw    $(2 << 8) | 1, %ax        /* just one sector */

        /*
         * int 0x13, %ah = 0x02: Read disk sectors
         * %al - number of sectors to read
         * %ch - cylinder (low order bits of cylinder)
         * %cl - sector (0:5 bits are used, 6:7 bits are high order bits of
         *       cylinder)
         * %dh - head
         * %dl - drive, 0 for drive A
         * %es:%bx - pointer to buffer
         */
        sti
        int     $0x13
        cli
        popw    %cx
        decw    %cx
        jz      1f

        popw    %dx
        incw    %dx
        addw    $BYTES_PER_SECTOR, %bx
        jmp     read_sectors
1:
        popw    %dx
        iretw

        /*
         * Look up filename in root directory
         *
         * %ds:%si - Pointer to the filename (just 11 = 8 + 3 bytes)
         * %cx - Number of directory entries
         * %es:%bx - Pointer to the root directory
         *
         * On return:
         * %ax - cluster of the file if CF not set
         */
look_up_filename:
        pushw   %cx
        pushw   %si
        movw    %bx, %di
        movw    $11, %cx
2:
        cmpsb
        jne     1f
        loop    2b

        /* found */
        popw    %si
        popw    %cx
        movw    %es:0x1a(%bx), %ax      /* read cluster number */
        movw    %sp, %bp
        andw    $~0x0001, 4(%bp)        /* clear CF */
        iretw
1:
        popw    %si
        popw    %cx
        addw    $DIRECTORY_ENTRY_SIZE, %bx
        loop    look_up_filename

        /* not found */
        movw    %sp, %bp
        orw     $0x0001, 4(%bp)         /* set CF */
        iretw

        /*
         * Read file
         *
         * %dx - Start cluster number of the file
         * %ds:%si - Pointer to the FAT12
         * %es:%bx - Address where the file data is stored
         */
read_file:
        cmpw    $0x0fff, %dx            /* end of clusters */
        jne     1f
        iretw
1:
        pushw   %dx
        addw    $(DATA_AREA_OFFSET - 2), %dx
        pushw   %si
        pushw   %bx
        movw    $1, %cx                 /* just one sector */
        movb    $1, %ah
        sti
        int     $0x21
        cli
        popw    %bx
        popw    %si
        popw    %dx

        /* get the next cluster */
        pushw   %si
        movw    %dx, %ax
        shrw    %ax
        addw    %dx, %ax
        addw    %ax, %si
        movw    (%si), %ax
        popw    %si
        andw    $1, %dx
        jz      2f                      /* even cluster */
        /* odd cluster */
        shrw    $4, %ax
2:
        andw    $0x0fff, %ax
        movw    %ax, %dx
        addw    $BYTES_PER_SECTOR, %bx
        jmp     read_file

banner: .string "Boot loader\r\n"
fatal:  .string "Fatal error\r\n"
boot2:  .ascii  "BOOT2   BIN"
