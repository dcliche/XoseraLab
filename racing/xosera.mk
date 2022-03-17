# Make Xosera test program for rosco_m68k
#
# vim: set noet ts=8 sw=8
# Copyright (c) 2021 Xark
# MIT LICENSE

ifndef ROSCO_M68K_DIR
$(error Please set ROSCO_M68K_DIR to the rosco_m68k directory to use for rosco_m68k building)
endif
ifndef XOSERA_DIR
$(error Please set XOSERA_DIR to the Xosera directory to use for rosco_m68k building)
endif
XOSERA_M68K_API=$(XOSERA_DIR)/xosera_m68k_api

EXTRA_CFLAGS?=-g -O3 -fomit-frame-pointer
#EXTRA_VASMFLAGS?=-showopt
SYSINCDIR?=$(ROSCO_M68K_DIR)/code/software/libs/build/include
SYSLIBDIR?=$(ROSCO_M68K_DIR)/code/software/libs/build/lib
DEFINES=-DROSCO_M68K
CFLAGS=-std=c11 -ffreestanding -ffunction-sections -fdata-sections \
    -Wall -Wextra -Werror -Wno-unused-function -pedantic -I$(SYSINCDIR) \
    -I$(XOSERA_M68K_API) -I../common \
    -mcpu=68010 -march=68010 -mtune=68010 $(DEFINES)
GCC_LIBS=$(shell $(CC) --print-search-dirs \
    | grep libraries:\ = \
    | sed 's/libraries: =/-L/g' \
    | sed 's/:/m68000\/ -L/g')m68000/
LIBS=-lprintf -lcstdlib -lmachine -lstart_serial -lgpio -lm -lgcc
ASFLAGS=-mcpu=68010 -march=68010
LDFLAGS=-T $(SYSLIBDIR)/ld/serial/rosco_m68k_program.ld -L $(SYSLIBDIR) \
    -Map=$(MAP) --gc-sections --oformat=elf32-m68k
VASMFLAGS=-Felf -m68010 -quiet -Lnf -I$(XOSERA_M68K_API) $(DEFINES)
CC=m68k-elf-gcc
AS=m68k-elf-as
LD=m68k-elf-ld
NM=m68k-elf-nm
LD=m68k-elf-ld
OBJDUMP=m68k-elf-objdump
OBJCOPY=m68k-elf-objcopy
SIZE=m68k-elf-size
VASM=vasmm68k_mot
RM=rm -f
KERMIT=kermit
SERIAL?=/dev/modem
BAUD?=9600

# Output config (assume same as name of directory)
PROGRAM_BASENAME=$(shell basename $(CURDIR))

# Set other output files using output basname
ELF=$(PROGRAM_BASENAME).elf
BINARY=$(PROGRAM_BASENAME).bin
DISASM=$(PROGRAM_BASENAME).dis
MAP=$(PROGRAM_BASENAME).map
SYM=$(PROGRAM_BASENAME).sym

# Assume source files in Makefile directory are source files for project
CSOURCES=kmain.c racing_xosera.c racing.c
CSOURCES+=$(wildcard $(XOSERA_M68K_API)/*.c)
CSOURCES+=$(wildcard ../common/*.c)
SSOURCES=$(wildcard *.S)
ASMSOURCES=$(wildcard *.asm)
SOURCES=$(CSOURCES) $(SSOURCES) $(ASMSOURCES)

# Assume each source files makes an object file
OBJECTS=$(addsuffix .o,$(basename $(SOURCES)))

all: $(BINARY) $(DISASM)

$(ELF) : $(OBJECTS)
	$(LD) $(LDFLAGS) $(GCC_LIBS) $^ -o $@ $(LIBS)
	$(NM) --numeric-sort $@ >$(SYM)
	$(SIZE) $@
	chmod a-x $@

$(BINARY) : $(ELF)
	$(OBJCOPY) -O binary $(ELF) $(BINARY)

$(DISASM) : $(ELF)
	$(OBJDUMP) --disassemble -S $(ELF) >$(DISASM)

$(OBJECTS): Makefile

%.o : %.c
	$(CC) -c $(CFLAGS) $(EXTRA_CFLAGS) -o $@ $<

%.o : %.asm
	$(VASM) $(VASMFLAGS) $(EXTRA_VASMFLAGS) -L $(basename $@).lst -o $@ $<

# remove targets that can be generated by this Makefile
clean:
	$(RM) $(OBJECTS) $(ELF) $(BINARY) $(MAP) $(SYM) $(DISASM) $(addsuffix .lst,$(basename $(SSOURCES) $(ASMSOURCES)))

disasm: $(DISASM)

# hexdump of program binary
dump: $(BINARY)
	hexdump -C $(BINARY)

# upload binary to rosco (if ready and kermit present)
load: $(BINARY)
	$(KERMIT) -i -l $(SERIAL) -b $(BAUD) -s $(BINARY)

# This is handy to test on Ubuntu Linux (kills previous "screen", opens one in shell window/tab)
test: $(BINARY) $(DISASM)
	-killall screen && sleep 1
	$(KERMIT) -i -l $(SERIAL) -b $(BAUD) -s $(BINARY)
	gnome-terminal --geometry=80x25 --title="rosco_m68k $(SERIAL)" -- screen $(SERIAL) $(BAUD)

# This is handy to test on MacOS (kills previous "screen", opens new one in shell window/tab)
mactest: $(BINARY) $(DISASM)
	-killall screen && sleep 1
	$(KERMIT) -i -l $(SERIAL) -b $(BAUD) -s $(BINARY)
	echo "#! /bin/sh" > $(TMPDIR)/rosco_screen.sh
	echo "/usr/bin/screen $(SERIAL) $(BAUD)" >> $(TMPDIR)/rosco_screen.sh
	chmod +x $(TMPDIR)/rosco_screen.sh
	sleep 1
	open -b com.apple.terminal $(TMPDIR)/rosco_screen.sh

# This is handy to test on MacOS (kills previous "screen", opens new one in shell window/tab)
macterm:
	-killall screen && sleep 1
	echo "#! /bin/sh" > $(TMPDIR)/rosco_screen.sh
	echo "/usr/bin/screen $(SERIAL) $(BAUD)" >> $(TMPDIR)/rosco_screen.sh
	chmod +x $(TMPDIR)/rosco_screen.sh
	sleep 1
	open -b com.apple.terminal $(TMPDIR)/rosco_screen.sh

# Makefile magic (for "phony" targets that are not real files)
.PHONY: all clean dump disasm load test mactest macterm
