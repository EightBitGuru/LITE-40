// LITE-40 runtime RAM labels
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace L40_runtime_memory

// Zero-page
// Six locations are not defined here: the package uses the stock KERNAL's own screen editor variables (the labels in
// vic20.os_zpvars) for the same job, so a host calling the stock PLOT routine (carry set) reads the package's print position
// (.X = row 0-23, .Y = column 0-39), which is what BASIC's POS, TAB and SPC use. The stock IRQ only touches them in its
// cursor flash, which CLR disables ($CC).
//
//   vic20.os_zpvars.CRSRLPOS  $D3  Print column (0-39) (ZP required for isb)
//   vic20.os_zpvars.CRSRROW   $D6  Print row (0-23) (ZP required for isb)
//   vic20.os_zpvars.CHARBYTE  $D7  Incoming character, restored to .A on exit
//   vic20.os_zpvars.COLRPTRL  $F3  Colour RAM row pointer lo-byte
//   vic20.os_zpvars.COLRPTRH  $F4  Colour RAM row pointer hi-byte
//   vic20.os_zpvars.RVSFLAG   $C7  Reverse flag ($00=RVS OFF, $80=RVS ON; any non-zero value means on)

// 18 bytes of package state at $D9-$EA (in the stock screen line link table, which only the stock editor uses),
// 7 spare bytes at $EB-$F1
.label CELLBITL         = $00D9     //  Bitmap address of the current character cell lo-byte
.label CELLBITH         = $00DA     //  Bitmap address of the current character cell hi-byte
.label COLMASK          = $00DB     //  Column nybble mask ($F0=even column, left nybble; $0F=odd column, right nybble)
.label CASEFLAG         = $00DC     //  Upper/Lower-case flag ($00=upper-case, $80=lower-case: added to the glyph address table index)
.label SAVEX            = $00DD     //  Caller's X-register, restored on exit
.label SAVEY            = $00DE     //  Caller's Y-register, restored on exit
.label TEMPAL           = $00DF     //  Glyph data pointer / scroll bitmap pointer lo-byte
.label TEMPAH           = $00E0     //  Glyph data pointer / scroll bitmap pointer hi-byte
.label TEMPBL           = $00E1     //  Control code dispatch address lo-byte
.label TEMPBH           = $00E2     //  Control code dispatch address hi-byte
.label MATROWL          = $00E3     //  Scroll: character matrix data row pointer lo-byte
.label MATROWH          = $00E4     //  Scroll: character matrix data row pointer hi-byte
.label REGYSAVE         = $00E5     //  Scroll: character matrix index scratch
.label STRPTRL          = $00E6     //  String output: pointer to the next character lo-byte
.label STRPTRH          = $00E7     //  String output: pointer to the next character hi-byte
.label WRAPFLAG         = $00E8     //  Word wrap flag (b7 -> 0=off, 1=on): set on by control code $01 and off by $02 and by the first CLR, read by print_string
.label WRAPCNT          = $00E9     //  String output: length of the next word, and the reverse flag while a wrap line break is sent
.label WRAPLEAD         = $00EA     //  String output: $80 at the start of a string and after a code that moves the print position, $00 once a character has been sent
.label SPAREZP          = $00EB     //  Spare (7 bytes to $F1)

// Onboard RAM
.label Character_Matrix = $1000     //  Screen character matrix is 20x12 double-height chars -> 240 bytes to $10EF
.label SPAREP10         = $10F0     //  Spare (16 bytes)
.label Screen_Bitmap    = $1100     //  Screen bitmap is 160x192 bits -> 20 * 8 * 24 = 3840 bytes to $1FFF
