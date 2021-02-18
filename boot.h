#define BOOT_ADDR           0x7c3e
#define BOOT_SEG            ((BOOT_ADDR & ~0xffff) >> 4)
#define BOOT_OFFSET         (BOOT_ADDR & 0xffff)
#define BOOT_STACK_START    0x7c00

#define BOOT2_ADDR          0x10000
#define BOOT2_SEG           ((BOOT2_ADDR & ~0xffff) >> 4)
#define BOOT2_OFFSET        (BOOT2_ADDR & 0xffff)

#define SMAP_ADDR           0x11000
#define SMAP_SEG            ((SMAP_ADDR & ~0xffff) >> 4)
#define SMAP_OFFSET         (SMAP_ADDR & 0xffff)
#define SMAP_MAGIC          0x534D4150
#define SMAP_ENT_SIZE       24
#define SMAP_ENT_ACPI_EXT_OFFSET    20

#define KERNEL_ADDR         0x20000
#define KERNEL_SEG          ((KERNEL_ADDR & ~0xffff) >> 4)
#define KERNEL_OFFSET       (KERNEL_ADDR & 0xffff)
#define KERNEL_CS           0x08
#define KERNEL_DS           0x10
