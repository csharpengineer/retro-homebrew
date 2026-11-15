// The best score and the sound setting in the cartridge's 4 Kbit EEPROM, laid
// out like the SNES save: "YCHT", best (LE), muted, 0, checksum (LE) =
// (sum of bytes 0-7) XOR $A55A. A missing or bad save starts from defaults.
#include <libdragon.h>
#include "platform.h"

static bool have_eeprom;

static uint16_t checksum(const uint8_t *b) {
  uint16_t s = 0;
  for (int i = 0; i < 8; i++) s += b[i];
  return s ^ 0xA55A;
}

void save_store(uint16_t best, bool muted) {
  if (!have_eeprom) return;
  uint8_t b[16] = { 'Y', 'C', 'H', 'T', best & 0xFF, best >> 8, muted ? 1 : 0, 0 };
  uint16_t c = checksum(b);
  b[8] = c & 0xFF;
  b[9] = c >> 8;
  eeprom_write_bytes(b, 0, sizeof b);
}

void save_load(uint16_t *best, bool *muted) {
  *best = 0;
  *muted = false;
  have_eeprom = eeprom_present() != EEPROM_NONE;
  if (!have_eeprom) return;
  uint8_t b[16];
  eeprom_read_bytes(b, 0, sizeof b);
  if (b[0] != 'Y' || b[1] != 'C' || b[2] != 'H' || b[3] != 'T' || (b[8] | b[9] << 8) != checksum(b)) {
    save_store(0, false);
    return;
  }
  *best = b[4] | b[5] << 8;
  *muted = b[6] & 1;
}
