; Memory map, SNES header and vectors. 512 KB LoROM, 2 KB battery save RAM.
.MEMORYMAP
  SLOTSIZE $8000
  DEFAULTSLOT 0
  SLOT 0 $8000
.ENDME
.ROMBANKSIZE $8000
.ROMBANKS 16

.SNESHEADER
  ID "SNES"
  NAME "YACHT                "
  LOROM
  SLOWROM
  CARTRIDGETYPE $02
  ROMSIZE $09
  SRAMSIZE $01
  COUNTRY $01
  LICENSEECODE $00
  VERSION $01        ; v1.1 (0 was the first release)
.ENDSNES

.SNESNATIVEVECTOR
  COP EmptyHandler
  BRK EmptyHandler
  ABORT EmptyHandler
  NMI NmiHandler
  IRQ EmptyHandler
.ENDNATIVEVECTOR

.SNESEMUVECTOR
  COP EmptyHandler
  ABORT EmptyHandler
  NMI EmptyHandler
  RESET Reset
  IRQBRK EmptyHandler
.ENDEMUVECTOR
