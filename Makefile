FLOPPY_IMAGE := floppy.img

BOOT_OBJS := boot.o
BOOT_ELF := boot.elf
BOOT_BIN := $(BOOT_ELF:.elf=.bin)
BOOT_LDFLAGS := -Ttext=0x7c3e

BOOT2_OBJS := boot2.o
BOOT2_ELF := boot2.elf
BOOT2_BIN := $(BOOT2_ELF:.elf=.bin)
BOOT2_LDFLAGS := -Ttext=0

KERNEL_OBJS := start.o kernel.o
KERNEL_ELF := kernel.elf
KERNEL_BIN := $(KERNEL_ELF:.elf=.bin)
KERNEL_LDFLAGS := -Ttext=0x20000

OBJS := $(BOOT_OBJS) $(BOOT2_OBJS) $(KERNEL_OBJS)
DEPS := $(OBJS:.o=.d)
TARGETS := $(FLOPPY_IMAGE) $(OBJS) $(DEPS)
TARGETS += $(BOOT_ELF) $(BOOT_BIN)
TARGETS += $(BOOT2_ELF) $(BOOT2_BIN)
TARGETS += $(KERNEL_ELF) $(KERNEL_BIN)

CC := i686-elf-gcc
CFLAGS := -Wall -Wextra -std=gnu99 -ffreestanding -nostdlib -lgcc -g

OBJCOPY := i686-elf-objcopy

.PHONY: all
all: $(FLOPPY_IMAGE)

$(FLOPPY_IMAGE): $(BOOT_BIN) $(BOOT2_BIN) $(KERNEL_BIN)
	dd if=/dev/zero of=$@ count=2880
	mformat -i $@ -f 1440 ::
	dd if=$(BOOT_BIN) of=$@ bs=1 seek=62 conv=notrunc
	mcopy -i $@ $(BOOT2_BIN) ::
	mcopy -i $@ $(KERNEL_BIN) ::

$(BOOT_ELF): $(BOOT_OBJS)
	$(CC) $(CFLAGS) $(BOOT_LDFLAGS) $^ -o $@

$(BOOT2_ELF): $(BOOT2_OBJS)
	$(CC) $(CFLAGS) $(BOOT2_LDFLAGS) $^ -o $@

$(KERNEL_ELF): $(KERNEL_OBJS)
	$(CC) $(CFLAGS) $(KERNEL_LDFLAGS) $^ -o $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.o: %.S
	$(CC) $(CFLAGS) -MMD -MP -c $<

%.o: %.c
	$(CC) $(CFLAGS) -MMD -MP -c $<

-include $(DEPS)

.PHONY: clean
clean:
	rm -f $(TARGETS)
