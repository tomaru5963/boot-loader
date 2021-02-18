# My first boot loader

This is my first boot loader for x86 PCs.

Memory map::

```text
0x00000000 +------------------+
           | IVT              |
           | BDA              |
0x00000500 +------------------+
           | Stack area       |
0x00007c00 +------------------+
           | BPB, EBPB        |
0x00007c3e +------------------+
           | Boot loader      |
0x00007e00 +------------------+
           | FAT12            |
0x00009000 +------------------+
           | Root directory   |
0x0000ac00 +------------------+
           ~                  ~
           ~                  ~
0x00010000 +------------------+
           | 2nd stage loader |
0x00011000 +------------------+
           | Memory info      |
           ~                  ~
           ~                  ~
0x00020000 +------------------+
           | Kernel           |
```

Typical layout of FAT12 floppy disk::

```text
   0 +----------------+
     | Boot sector    |
   1 +----------------+
     | FAT            |
     | 9 sectors      |
  10 +----------------+
     | FAT (optional) |
     | 9 sectors      |
  19 +----------------+
     | Root directory |
     | 14 sectors     |
  33 +----------------+
     | Data           |
     | 2849 sectors   |
2880 +----------------+
```

## (The first stage) boot loader

The first stage boot loader:

- is embedded in the boot sector of the floppy image
- loads FAT12 and the root directory into memory
- looks for the second stage boot loader and loads it, then
- jumps into the second stage loader

## The second stage boot loader

The second stage boot loader:

- looks for the kernel and loads it
- enables A20 line of the address bus
- gets the information of available memory
- disables interrupts including NMI
- switches to 32-bit protected mode, then
- jumps to the kernel

## The kernel

It just show a cyan `X` character in the top left corner of the screen and
then halt forever.

## Try with the floppy image

I have tried it with qemu and VirtualBox.

```bash
qemu-system-i386 -fda floppy.img
```
