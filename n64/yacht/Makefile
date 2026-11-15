# Builds the ROM with libdragon (inside WSL; build.sh runs the asset scripts
# first and then this).
#   make              yacht.z64       (build.sh moves it to build/yacht.z64)
#   make AUTOTEST=1   yacht_test.z64  (the emulator test session, tests/emu.sh)
ifeq ($(AUTOTEST),1)
BUILD_DIR = build/autotest
ROM = yacht_test
else
BUILD_DIR = build/obj
ROM = yacht
endif
SOURCE_DIR = src
N64_MKDFS_ROOT = build/fs
include $(N64_INST)/include/n64.mk

N64_CFLAGS += -Isrc -Ibuild
ifeq ($(AUTOTEST),1)
N64_CFLAGS += -DAUTOTEST
endif

SRC = $(wildcard src/*.c) $(wildcard src/core/*.c)
OBJS = $(SRC:src/%.c=$(BUILD_DIR)/%.o)

# Art (build/assets/*.png from tools/art) and sound (*.wav from tools/audio.js,
# tools/voice.js) converted for the cartridge filesystem.
PNG = $(wildcard build/assets/*.png)
WAV = $(wildcard build/assets/*.wav)
FS = $(PNG:build/assets/%.png=build/fs/%.sprite) $(WAV:build/assets/%.wav=build/fs/%.wav64)

build/fs/%.sprite: build/assets/%.png
	@mkdir -p build/fs
	@echo "    [SPRITE] $@"
	@$(N64_MKSPRITE) --format $(FORMAT) -o build/fs "$<"
FORMAT = RGBA32
build/fs/game_bg.sprite build/fs/title_bg.sprite build/fs/die%.sprite: FORMAT = RGBA16
build/fs/font_small.sprite build/fs/font_big.sprite: FORMAT = IA8
build/fs/shadow.sprite: FORMAT = IA16

build/fs/%.wav64: build/assets/%.wav
	@mkdir -p build/fs
	@echo "    [AUDIO] $@"
	@$(N64_AUDIOCONV) --wav-compress 1 -o build/fs "$<"

all: $(ROM).z64

$(ROM).z64: N64_ROM_TITLE = "YACHT"
$(ROM).z64: N64_ROM_SAVETYPE = eeprom4k
$(ROM).z64: N64_ROM_REGIONFREE = true
$(ROM).z64: $(BUILD_DIR)/$(ROM).dfs
$(BUILD_DIR)/$(ROM).dfs: $(FS)
$(BUILD_DIR)/$(ROM).elf: $(OBJS)

clean:
	rm -rf build/obj build/autotest build/fs yacht.z64 yacht_test.z64

-include $(wildcard $(BUILD_DIR)/*.d $(BUILD_DIR)/core/*.d)
.PHONY: all clean
