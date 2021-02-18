#define FAT12_ADDR              0x7e00
#define FAT12_SEG               ((FAT12_ADDR & ~0xffff) >> 4)
#define FAT12_OFFSET            (FAT12_ADDR & 0xffff)

#define DIRECTORY_ADDR          0x9000
#define DIRECTORY_SEG           ((DIRECTORY_ADDR & ~0xffff) >> 4)
#define DIRECTORY_OFFSET        (DIRECTORY_ADDR & 0xffff)
#define DIRECTORY_ENTRY_SIZE    32
#define DIRECTORY_ENTRIES       224

#define BYTES_PER_SECTOR        512

#define DATA_AREA_OFFSET        33
