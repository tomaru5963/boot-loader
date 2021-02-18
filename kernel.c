#include <stdint.h>

void kernel_main()
{
        /* Write a character on the screen */
        uint16_t *vram = (uint16_t *)0xb8000;
        uint16_t ch = 0x0b << 8 | 'X';
        *vram = ch;

        asm volatile("cli");
        while (1) {
                asm volatile("hlt");
        }
}