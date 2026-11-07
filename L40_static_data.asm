// LITE-40 static data structures
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace L40_static_data

// The tables are placed from the top of the package down, in four groups with no bytes between them, so that nothing is wasted: the
// tables that must start on a page boundary (the glyph address table, two pages, and the character matrix table) sit where the
// glyph data, the entry points and the small tables that go above them put them, and the rest of the small tables sit just below
// the glyph address table. Which small tables go where is chosen so that the sizes add up (the assertions at the end of this file
// check it, and say what to change if a table is added or removed). Every table is inside one page, so every indexed read stays
// inside one page. From the bottom:
//
//     low small tables     L40_LOW_TABLES_SIZE bytes, immediately below the glyph address table
//     glyph address table  512 bytes, page-aligned
//     character matrix     240 bytes, page-aligned
//     high small tables    L40_HIGH_TABLES_SIZE bytes, immediately below the entry points

// -------------------------------------------- LOW SMALL TABLES --------------------------------------------

.pc = L40_LOW_TABLES "L40_LOW_TABLES"
low_tables:
VICNTSC:				// 6560 (NTSC) VIC initialisation data (6 bytes)
.pc = * "VICNTSC"		// VIC register values $9000-$9005 (the sound registers and $900F are never written)
.byte %00000111			// $9000 - b7 = interlace; b6-0 = screen x-pos
.byte %00011001			// $9001 - b7-0 = screen y-pos
.byte %00010100			// $9002 - b7 = screen address b9; b6-0 = screen cols
.byte %00011001			// $9003 - b7 = raster b0; b6-1 = screen rows; b0 = double-height chars
.byte %00000000			// $9004 - b7-0 = raster b1-8
.byte %11001100			// $9005 - b7-4 = screen address b15+b12-10; b3-0 = chargen address b15+b12-10

CROWOFFS:				// Character row offsets
.pc = * "CROWOFFS"		// Character row offsets (13 bytes)
.byte 0,20,40,60,80,100,120,140,160,180,200,220,240

CONCODEL:
.pc = * "CONCODEL"		// CHROUT control character handler address lo-bytes (13 bytes; all hi-bytes are the same page)
.byte <L40_controlcode_handlers.inactive_code			// 0 - every code that does nothing
.byte <L40_controlcode_handlers.carriage_return			// 1
.byte <L40_controlcode_handlers.cursor_home				// 2
.byte <L40_controlcode_handlers.switch_case				// 3
.byte <L40_controlcode_handlers.rvs_mode				// 4
.byte <L40_controlcode_handlers.set_colour_byte			// 5
.byte <L40_controlcode_handlers.clear_screen			// 6
.byte <L40_controlcode_handlers.cursor_down				// 7
.byte <L40_controlcode_handlers.cursor_left				// 8
.byte <L40_controlcode_handlers.cursor_right			// 9
.byte <L40_controlcode_handlers.cursor_up				// 10
.byte <L40_controlcode_handlers.wrap_on				// 11
.byte <L40_controlcode_handlers.wrap_off				// 12

CODEIDXH:
.pc = * "CODEIDXH"		// CHROUT high-range ($80-$9F, indexed by char & $1F) -> CONCODEL index (0 = ignored)
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0		// $8D=SHIFTCR (ignored),$8E=UCASE
.byte 5,10,4,6,0,0,0,0,0,0,0,0,5,8,5,5		// $90=BLACK,$91=CRSRUP,$92=RVSOFF,$93=CLRSCRN,$9C=PURPLE,$9D=CRSRLEFT,$9E=YELLOW,$9F=CYAN

BITADDRH:				// Character -> Screen_Bitmap 8x16 character address hi-bytes
.pc = * "BITADDRH"		// Character -> Screen_Bitmap 8x16 character address hi-byte table (16 bytes)
.fill 16,>[L40_runtime_memory.Screen_Bitmap+(256*i)]	// $00 - $0F plus Screen_Bitmap start address hi-byte

ROWOFFS:				// Bitmap address row offsets
.pc = * "ROWOFFS"		// Zero-based row offsets (24 bytes)
.fill 12,[0,8]

COLOFFS:				// Bitmap address column offsets
.pc = * "COLOFFS"		// Zero-based column offsets (40 bytes)
.fill 20,[%11110000,%00001111]

low_tables_end:

// -------------------------------------------- PAGE-ALIGNED TABLES --------------------------------------------

.pc = L40_GLPHADDR "GLYPHADD"
GLYPHADD:				// Character glyph pixel address data
.pc = * "GLYPHADD"		// Glyph pixel address lo/hi-bytes for the screen codes 0-127 of each character set (256 + 256 bytes, together two pages)
GLPHADDR:
{
lo:			// lo-bytes, indexed by the screen code, plus 128 for the upper/lower-case set
.byte <L40_glyph_data.G0,<L40_glyph_data.G1,<L40_glyph_data.G2,<L40_glyph_data.G3,<L40_glyph_data.G4,<L40_glyph_data.G5,<L40_glyph_data.G6,<L40_glyph_data.G7		// upper-case/graphics set, screen codes 000-007
.byte <L40_glyph_data.G8,<L40_glyph_data.G9,<L40_glyph_data.G10,<L40_glyph_data.G11,<L40_glyph_data.G12,<L40_glyph_data.G13,<L40_glyph_data.G14,<L40_glyph_data.G15		// upper-case/graphics set, screen codes 008-015
.byte <L40_glyph_data.G16,<L40_glyph_data.G17,<L40_glyph_data.G18,<L40_glyph_data.G19,<L40_glyph_data.G20,<L40_glyph_data.G21,<L40_glyph_data.G22,<L40_glyph_data.G23		// upper-case/graphics set, screen codes 016-023
.byte <L40_glyph_data.G24,<L40_glyph_data.G25,<L40_glyph_data.G26,<L40_glyph_data.G27,<L40_glyph_data.G28,<L40_glyph_data.G29,<L40_glyph_data.G30,<L40_glyph_data.G31		// upper-case/graphics set, screen codes 024-031
.byte <L40_glyph_data.G32,<L40_glyph_data.G33,<L40_glyph_data.G34,<L40_glyph_data.G35,<L40_glyph_data.G36,<L40_glyph_data.G37,<L40_glyph_data.G38,<L40_glyph_data.G39		// upper-case/graphics set, screen codes 032-039
.byte <L40_glyph_data.G40,<L40_glyph_data.G41,<L40_glyph_data.G42,<L40_glyph_data.G43,<L40_glyph_data.G44,<L40_glyph_data.G45,<L40_glyph_data.G46,<L40_glyph_data.G47		// upper-case/graphics set, screen codes 040-047
.byte <L40_glyph_data.G48,<L40_glyph_data.G49,<L40_glyph_data.G50,<L40_glyph_data.G51,<L40_glyph_data.G52,<L40_glyph_data.G53,<L40_glyph_data.G54,<L40_glyph_data.G55		// upper-case/graphics set, screen codes 048-055
.byte <L40_glyph_data.G56,<L40_glyph_data.G57,<L40_glyph_data.G58,<L40_glyph_data.G59,<L40_glyph_data.G60,<L40_glyph_data.G61,<L40_glyph_data.G62,<L40_glyph_data.G63		// upper-case/graphics set, screen codes 056-063
.byte <L40_glyph_data.G64,<L40_glyph_data.G65,<L40_glyph_data.G66,<L40_glyph_data.G67,<L40_glyph_data.G68,<L40_glyph_data.G69,<L40_glyph_data.G70,<L40_glyph_data.G71		// upper-case/graphics set, screen codes 064-071
.byte <L40_glyph_data.G72,<L40_glyph_data.G73,<L40_glyph_data.G74,<L40_glyph_data.G75,<L40_glyph_data.G76,<L40_glyph_data.G77,<L40_glyph_data.G78,<L40_glyph_data.G79		// upper-case/graphics set, screen codes 072-079
.byte <L40_glyph_data.G80,<L40_glyph_data.G81,<L40_glyph_data.G82,<L40_glyph_data.G83,<L40_glyph_data.G71,<L40_glyph_data.G84,<L40_glyph_data.G85,<L40_glyph_data.G86		// upper-case/graphics set, screen codes 080-087
.byte <L40_glyph_data.G87,<L40_glyph_data.G88,<L40_glyph_data.G89,<L40_glyph_data.G90,<L40_glyph_data.G91,<L40_glyph_data.G66,<L40_glyph_data.G92,<L40_glyph_data.G93		// upper-case/graphics set, screen codes 088-095
.byte <L40_glyph_data.G32,<L40_glyph_data.G94,<L40_glyph_data.G95,<L40_glyph_data.G96,<L40_glyph_data.G97,<L40_glyph_data.G71,<L40_glyph_data.G98,<L40_glyph_data.G88		// upper-case/graphics set, screen codes 096-103
.byte <L40_glyph_data.G99,<L40_glyph_data.G100,<L40_glyph_data.G88,<L40_glyph_data.G101,<L40_glyph_data.G102,<L40_glyph_data.G103,<L40_glyph_data.G73,<L40_glyph_data.G104		// upper-case/graphics set, screen codes 104-111
.byte <L40_glyph_data.G105,<L40_glyph_data.G106,<L40_glyph_data.G107,<L40_glyph_data.G108,<L40_glyph_data.G71,<L40_glyph_data.G94,<L40_glyph_data.G109,<L40_glyph_data.G110		// upper-case/graphics set, screen codes 112-119
.byte <L40_glyph_data.G111,<L40_glyph_data.G112,<L40_glyph_data.G113,<L40_glyph_data.G114,<L40_glyph_data.G115,<L40_glyph_data.G116,<L40_glyph_data.G117,<L40_glyph_data.G118		// upper-case/graphics set, screen codes 120-127
.byte <L40_glyph_data.G0,<L40_glyph_data.G119,<L40_glyph_data.G120,<L40_glyph_data.G121,<L40_glyph_data.G122,<L40_glyph_data.G123,<L40_glyph_data.G124,<L40_glyph_data.G125		// upper/lower-case set, screen codes 000-007
.byte <L40_glyph_data.G126,<L40_glyph_data.G127,<L40_glyph_data.G128,<L40_glyph_data.G129,<L40_glyph_data.G130,<L40_glyph_data.G131,<L40_glyph_data.G132,<L40_glyph_data.G133		// upper/lower-case set, screen codes 008-015
.byte <L40_glyph_data.G134,<L40_glyph_data.G135,<L40_glyph_data.G136,<L40_glyph_data.G137,<L40_glyph_data.G138,<L40_glyph_data.G139,<L40_glyph_data.G140,<L40_glyph_data.G141		// upper/lower-case set, screen codes 016-023
.byte <L40_glyph_data.G142,<L40_glyph_data.G143,<L40_glyph_data.G144,<L40_glyph_data.G27,<L40_glyph_data.G28,<L40_glyph_data.G29,<L40_glyph_data.G30,<L40_glyph_data.G31		// upper/lower-case set, screen codes 024-031
.byte <L40_glyph_data.G32,<L40_glyph_data.G33,<L40_glyph_data.G34,<L40_glyph_data.G35,<L40_glyph_data.G36,<L40_glyph_data.G37,<L40_glyph_data.G38,<L40_glyph_data.G39		// upper/lower-case set, screen codes 032-039
.byte <L40_glyph_data.G40,<L40_glyph_data.G41,<L40_glyph_data.G42,<L40_glyph_data.G43,<L40_glyph_data.G44,<L40_glyph_data.G45,<L40_glyph_data.G46,<L40_glyph_data.G47		// upper/lower-case set, screen codes 040-047
.byte <L40_glyph_data.G48,<L40_glyph_data.G49,<L40_glyph_data.G50,<L40_glyph_data.G51,<L40_glyph_data.G52,<L40_glyph_data.G53,<L40_glyph_data.G54,<L40_glyph_data.G55		// upper/lower-case set, screen codes 048-055
.byte <L40_glyph_data.G56,<L40_glyph_data.G57,<L40_glyph_data.G58,<L40_glyph_data.G59,<L40_glyph_data.G60,<L40_glyph_data.G61,<L40_glyph_data.G62,<L40_glyph_data.G63		// upper/lower-case set, screen codes 056-063
.byte <L40_glyph_data.G64,<L40_glyph_data.G1,<L40_glyph_data.G2,<L40_glyph_data.G3,<L40_glyph_data.G4,<L40_glyph_data.G5,<L40_glyph_data.G6,<L40_glyph_data.G7		// upper/lower-case set, screen codes 064-071
.byte <L40_glyph_data.G8,<L40_glyph_data.G9,<L40_glyph_data.G10,<L40_glyph_data.G11,<L40_glyph_data.G12,<L40_glyph_data.G13,<L40_glyph_data.G14,<L40_glyph_data.G15		// upper/lower-case set, screen codes 072-079
.byte <L40_glyph_data.G16,<L40_glyph_data.G17,<L40_glyph_data.G18,<L40_glyph_data.G19,<L40_glyph_data.G20,<L40_glyph_data.G21,<L40_glyph_data.G22,<L40_glyph_data.G23		// upper/lower-case set, screen codes 080-087
.byte <L40_glyph_data.G24,<L40_glyph_data.G25,<L40_glyph_data.G26,<L40_glyph_data.G90,<L40_glyph_data.G91,<L40_glyph_data.G66,<L40_glyph_data.G145,<L40_glyph_data.G146		// upper/lower-case set, screen codes 088-095
.byte <L40_glyph_data.G32,<L40_glyph_data.G94,<L40_glyph_data.G95,<L40_glyph_data.G96,<L40_glyph_data.G97,<L40_glyph_data.G71,<L40_glyph_data.G98,<L40_glyph_data.G88		// upper/lower-case set, screen codes 096-103
.byte <L40_glyph_data.G99,<L40_glyph_data.G147,<L40_glyph_data.G88,<L40_glyph_data.G101,<L40_glyph_data.G102,<L40_glyph_data.G103,<L40_glyph_data.G73,<L40_glyph_data.G104		// upper/lower-case set, screen codes 104-111
.byte <L40_glyph_data.G105,<L40_glyph_data.G106,<L40_glyph_data.G107,<L40_glyph_data.G108,<L40_glyph_data.G71,<L40_glyph_data.G94,<L40_glyph_data.G109,<L40_glyph_data.G110		// upper/lower-case set, screen codes 112-119
.byte <L40_glyph_data.G111,<L40_glyph_data.G112,<L40_glyph_data.G148,<L40_glyph_data.G114,<L40_glyph_data.G115,<L40_glyph_data.G116,<L40_glyph_data.G117,<L40_glyph_data.G118		// upper/lower-case set, screen codes 120-127
hi:			// hi-bytes, indexed in the same way
.byte >L40_glyph_data.G0,>L40_glyph_data.G1,>L40_glyph_data.G2,>L40_glyph_data.G3,>L40_glyph_data.G4,>L40_glyph_data.G5,>L40_glyph_data.G6,>L40_glyph_data.G7		// upper-case/graphics set, screen codes 000-007
.byte >L40_glyph_data.G8,>L40_glyph_data.G9,>L40_glyph_data.G10,>L40_glyph_data.G11,>L40_glyph_data.G12,>L40_glyph_data.G13,>L40_glyph_data.G14,>L40_glyph_data.G15		// upper-case/graphics set, screen codes 008-015
.byte >L40_glyph_data.G16,>L40_glyph_data.G17,>L40_glyph_data.G18,>L40_glyph_data.G19,>L40_glyph_data.G20,>L40_glyph_data.G21,>L40_glyph_data.G22,>L40_glyph_data.G23		// upper-case/graphics set, screen codes 016-023
.byte >L40_glyph_data.G24,>L40_glyph_data.G25,>L40_glyph_data.G26,>L40_glyph_data.G27,>L40_glyph_data.G28,>L40_glyph_data.G29,>L40_glyph_data.G30,>L40_glyph_data.G31		// upper-case/graphics set, screen codes 024-031
.byte >L40_glyph_data.G32,>L40_glyph_data.G33,>L40_glyph_data.G34,>L40_glyph_data.G35,>L40_glyph_data.G36,>L40_glyph_data.G37,>L40_glyph_data.G38,>L40_glyph_data.G39		// upper-case/graphics set, screen codes 032-039
.byte >L40_glyph_data.G40,>L40_glyph_data.G41,>L40_glyph_data.G42,>L40_glyph_data.G43,>L40_glyph_data.G44,>L40_glyph_data.G45,>L40_glyph_data.G46,>L40_glyph_data.G47		// upper-case/graphics set, screen codes 040-047
.byte >L40_glyph_data.G48,>L40_glyph_data.G49,>L40_glyph_data.G50,>L40_glyph_data.G51,>L40_glyph_data.G52,>L40_glyph_data.G53,>L40_glyph_data.G54,>L40_glyph_data.G55		// upper-case/graphics set, screen codes 048-055
.byte >L40_glyph_data.G56,>L40_glyph_data.G57,>L40_glyph_data.G58,>L40_glyph_data.G59,>L40_glyph_data.G60,>L40_glyph_data.G61,>L40_glyph_data.G62,>L40_glyph_data.G63		// upper-case/graphics set, screen codes 056-063
.byte >L40_glyph_data.G64,>L40_glyph_data.G65,>L40_glyph_data.G66,>L40_glyph_data.G67,>L40_glyph_data.G68,>L40_glyph_data.G69,>L40_glyph_data.G70,>L40_glyph_data.G71		// upper-case/graphics set, screen codes 064-071
.byte >L40_glyph_data.G72,>L40_glyph_data.G73,>L40_glyph_data.G74,>L40_glyph_data.G75,>L40_glyph_data.G76,>L40_glyph_data.G77,>L40_glyph_data.G78,>L40_glyph_data.G79		// upper-case/graphics set, screen codes 072-079
.byte >L40_glyph_data.G80,>L40_glyph_data.G81,>L40_glyph_data.G82,>L40_glyph_data.G83,>L40_glyph_data.G71,>L40_glyph_data.G84,>L40_glyph_data.G85,>L40_glyph_data.G86		// upper-case/graphics set, screen codes 080-087
.byte >L40_glyph_data.G87,>L40_glyph_data.G88,>L40_glyph_data.G89,>L40_glyph_data.G90,>L40_glyph_data.G91,>L40_glyph_data.G66,>L40_glyph_data.G92,>L40_glyph_data.G93		// upper-case/graphics set, screen codes 088-095
.byte >L40_glyph_data.G32,>L40_glyph_data.G94,>L40_glyph_data.G95,>L40_glyph_data.G96,>L40_glyph_data.G97,>L40_glyph_data.G71,>L40_glyph_data.G98,>L40_glyph_data.G88		// upper-case/graphics set, screen codes 096-103
.byte >L40_glyph_data.G99,>L40_glyph_data.G100,>L40_glyph_data.G88,>L40_glyph_data.G101,>L40_glyph_data.G102,>L40_glyph_data.G103,>L40_glyph_data.G73,>L40_glyph_data.G104		// upper-case/graphics set, screen codes 104-111
.byte >L40_glyph_data.G105,>L40_glyph_data.G106,>L40_glyph_data.G107,>L40_glyph_data.G108,>L40_glyph_data.G71,>L40_glyph_data.G94,>L40_glyph_data.G109,>L40_glyph_data.G110		// upper-case/graphics set, screen codes 112-119
.byte >L40_glyph_data.G111,>L40_glyph_data.G112,>L40_glyph_data.G113,>L40_glyph_data.G114,>L40_glyph_data.G115,>L40_glyph_data.G116,>L40_glyph_data.G117,>L40_glyph_data.G118		// upper-case/graphics set, screen codes 120-127
.byte >L40_glyph_data.G0,>L40_glyph_data.G119,>L40_glyph_data.G120,>L40_glyph_data.G121,>L40_glyph_data.G122,>L40_glyph_data.G123,>L40_glyph_data.G124,>L40_glyph_data.G125		// upper/lower-case set, screen codes 000-007
.byte >L40_glyph_data.G126,>L40_glyph_data.G127,>L40_glyph_data.G128,>L40_glyph_data.G129,>L40_glyph_data.G130,>L40_glyph_data.G131,>L40_glyph_data.G132,>L40_glyph_data.G133		// upper/lower-case set, screen codes 008-015
.byte >L40_glyph_data.G134,>L40_glyph_data.G135,>L40_glyph_data.G136,>L40_glyph_data.G137,>L40_glyph_data.G138,>L40_glyph_data.G139,>L40_glyph_data.G140,>L40_glyph_data.G141		// upper/lower-case set, screen codes 016-023
.byte >L40_glyph_data.G142,>L40_glyph_data.G143,>L40_glyph_data.G144,>L40_glyph_data.G27,>L40_glyph_data.G28,>L40_glyph_data.G29,>L40_glyph_data.G30,>L40_glyph_data.G31		// upper/lower-case set, screen codes 024-031
.byte >L40_glyph_data.G32,>L40_glyph_data.G33,>L40_glyph_data.G34,>L40_glyph_data.G35,>L40_glyph_data.G36,>L40_glyph_data.G37,>L40_glyph_data.G38,>L40_glyph_data.G39		// upper/lower-case set, screen codes 032-039
.byte >L40_glyph_data.G40,>L40_glyph_data.G41,>L40_glyph_data.G42,>L40_glyph_data.G43,>L40_glyph_data.G44,>L40_glyph_data.G45,>L40_glyph_data.G46,>L40_glyph_data.G47		// upper/lower-case set, screen codes 040-047
.byte >L40_glyph_data.G48,>L40_glyph_data.G49,>L40_glyph_data.G50,>L40_glyph_data.G51,>L40_glyph_data.G52,>L40_glyph_data.G53,>L40_glyph_data.G54,>L40_glyph_data.G55		// upper/lower-case set, screen codes 048-055
.byte >L40_glyph_data.G56,>L40_glyph_data.G57,>L40_glyph_data.G58,>L40_glyph_data.G59,>L40_glyph_data.G60,>L40_glyph_data.G61,>L40_glyph_data.G62,>L40_glyph_data.G63		// upper/lower-case set, screen codes 056-063
.byte >L40_glyph_data.G64,>L40_glyph_data.G1,>L40_glyph_data.G2,>L40_glyph_data.G3,>L40_glyph_data.G4,>L40_glyph_data.G5,>L40_glyph_data.G6,>L40_glyph_data.G7		// upper/lower-case set, screen codes 064-071
.byte >L40_glyph_data.G8,>L40_glyph_data.G9,>L40_glyph_data.G10,>L40_glyph_data.G11,>L40_glyph_data.G12,>L40_glyph_data.G13,>L40_glyph_data.G14,>L40_glyph_data.G15		// upper/lower-case set, screen codes 072-079
.byte >L40_glyph_data.G16,>L40_glyph_data.G17,>L40_glyph_data.G18,>L40_glyph_data.G19,>L40_glyph_data.G20,>L40_glyph_data.G21,>L40_glyph_data.G22,>L40_glyph_data.G23		// upper/lower-case set, screen codes 080-087
.byte >L40_glyph_data.G24,>L40_glyph_data.G25,>L40_glyph_data.G26,>L40_glyph_data.G90,>L40_glyph_data.G91,>L40_glyph_data.G66,>L40_glyph_data.G145,>L40_glyph_data.G146		// upper/lower-case set, screen codes 088-095
.byte >L40_glyph_data.G32,>L40_glyph_data.G94,>L40_glyph_data.G95,>L40_glyph_data.G96,>L40_glyph_data.G97,>L40_glyph_data.G71,>L40_glyph_data.G98,>L40_glyph_data.G88		// upper/lower-case set, screen codes 096-103
.byte >L40_glyph_data.G99,>L40_glyph_data.G147,>L40_glyph_data.G88,>L40_glyph_data.G101,>L40_glyph_data.G102,>L40_glyph_data.G103,>L40_glyph_data.G73,>L40_glyph_data.G104		// upper/lower-case set, screen codes 104-111
.byte >L40_glyph_data.G105,>L40_glyph_data.G106,>L40_glyph_data.G107,>L40_glyph_data.G108,>L40_glyph_data.G71,>L40_glyph_data.G94,>L40_glyph_data.G109,>L40_glyph_data.G110		// upper/lower-case set, screen codes 112-119
.byte >L40_glyph_data.G111,>L40_glyph_data.G112,>L40_glyph_data.G148,>L40_glyph_data.G114,>L40_glyph_data.G115,>L40_glyph_data.G116,>L40_glyph_data.G117,>L40_glyph_data.G118		// upper/lower-case set, screen codes 120-127
}

.pc = L40_MATDATA "MATDATA"
MATDATA:				// Character matrix data for 20x12 (40x24) screen
.pc = * "MATDATA"		// Character code bytes (240 bytes)
.byte $10,$1C,$28,$34,$40,$4C,$58,$64,$70,$7C,$88,$94,$A0,$AC,$B8,$C4,$D0,$DC,$E8,$F4
.byte $11,$1D,$29,$35,$41,$4D,$59,$65,$71,$7D,$89,$95,$A1,$AD,$B9,$C5,$D1,$DD,$E9,$F5
.byte $12,$1E,$2A,$36,$42,$4E,$5A,$66,$72,$7E,$8A,$96,$A2,$AE,$BA,$C6,$D2,$DE,$EA,$F6
.byte $13,$1F,$2B,$37,$43,$4F,$5B,$67,$73,$7F,$8B,$97,$A3,$AF,$BB,$C7,$D3,$DF,$EB,$F7
.byte $14,$20,$2C,$38,$44,$50,$5C,$68,$74,$80,$8C,$98,$A4,$B0,$BC,$C8,$D4,$E0,$EC,$F8
.byte $15,$21,$2D,$39,$45,$51,$5D,$69,$75,$81,$8D,$99,$A5,$B1,$BD,$C9,$D5,$E1,$ED,$F9
.byte $16,$22,$2E,$3A,$46,$52,$5E,$6A,$76,$82,$8E,$9A,$A6,$B2,$BE,$CA,$D6,$E2,$EE,$FA
.byte $17,$23,$2F,$3B,$47,$53,$5F,$6B,$77,$83,$8F,$9B,$A7,$B3,$BF,$CB,$D7,$E3,$EF,$FB
.byte $18,$24,$30,$3C,$48,$54,$60,$6C,$78,$84,$90,$9C,$A8,$B4,$C0,$CC,$D8,$E4,$F0,$FC
.byte $19,$25,$31,$3D,$49,$55,$61,$6D,$79,$85,$91,$9D,$A9,$B5,$C1,$CD,$D9,$E5,$F1,$FD
.byte $1A,$26,$32,$3E,$4A,$56,$62,$6E,$7A,$86,$92,$9E,$AA,$B6,$C2,$CE,$DA,$E6,$F2,$FE
.byte $1B,$27,$33,$3F,$4B,$57,$63,$6F,$7B,$87,$93,$9F,$AB,$B7,$C3,$CF,$DB,$E7,$F3,$FF

// Primary Screen Matrix is 20x12 chars  ->  240 bytes at $1000-$10EF (double-height chars)
// Primary Colour Matrix is 20x12 chars  ->  240 bytes at $9400-$94EF (double-height chars)
// Primary Screen Screen_Bitmap is 160x192 bits -> 3840 bytes at $1100-$1FFF
matdata_end:

// -------------------------------------------- HIGH SMALL TABLES --------------------------------------------

.pc = L40_HIGH_TABLES "L40_HIGH_TABLES"
high_tables:
BITADDRL:				// Character -> Screen_Bitmap 8x16 character address lo-bytes
.pc = * "BITADDRL"		// Character -> Screen_Bitmap 8x16 character address lo-byte table (16 bytes)
.byte $00,$10,$20,$30,$40,$50,$60,$70,$80,$90,$A0,$B0,$C0,$D0,$E0,$F0

// The 48-byte block below is kept byte-for-byte as it was in the cartridge, as a signature (D10 in DISPLAY_ONLY_PLAN.md).
// Nothing in the package reads it and nothing may rely on its contents. Do not prune or reorder it.
V1CNTSC:				// VIC vector defaults (48 bytes)
.pc = * "V1CNTSC"		// Signature block (48 bytes)
.word $5269
.word $856C
.word $6477
.word $7679
.word $7E69
.word $6A98
.word $8D9F
.word $996F
.word $9AA0
.word $9AA1
.word $A7A4
.word $A464
.word $6A79
.word $7A7B
.word $7C7D
.word $8697
.word $8DA3
.word $ABB7
.word $84AC
.word $BBB9
.word $BD92
.word $8A8B
.word $8C8D
.word $8E6F
V1CPAL:

CODEIDXL:
.pc = * "CODEIDXL"		// CHROUT low-range ($00-$1F) -> CONCODEL index (0 = ignored)
.byte 0,11,12,0,0,5,0,0,0,0,0,0,0,1,3,0		// $01=WRAPON,$02=WRAPOFF,$05=WHITE,$0D=CR,$0E=LCASE
.byte 0,7,4,2,0,0,0,0,0,0,0,0,5,9,5,5		// $11=CRSRDOWN,$12=RVSON,$13=CRSRHOME,$1C=RED,$1D=CRSRRGHT,$1E=GREEN,$1F=BLUE

VICPAL:					// 6561 (PAL) VIC initialisation data (differences from NTSC values)
.pc = * "VICPAL"		// VIC register values (2 bytes)
.byte %00001110			// $9000 - b7 = interlace; b6-0 = screen x-pos
.byte %00100100			// $9001 - b7-0 = screen y-pos

high_tables_end:

// -------------------------------------------- LAYOUT ASSERTIONS --------------------------------------------

.errorif (low_tables_end - low_tables) != L40_LOW_TABLES_SIZE, "The low small tables are " + [low_tables_end - low_tables] + " bytes: set L40_LOW_TABLES_SIZE in lite40.asm to that, and move small tables between the groups until the glyph address table is page-aligned"
.errorif (high_tables_end - high_tables) != L40_HIGH_TABLES_SIZE, "The high small tables are " + [high_tables_end - high_tables] + " bytes: set L40_HIGH_TABLES_SIZE in lite40.asm to that, and move small tables between the groups until the glyph address table is page-aligned"
.errorif (matdata_end - MATDATA) != 240, "The character matrix table must be 240 bytes (20 x 12)"
.errorif (GLPHADDR & $FF) != 0, "GLPHADDR must be page-aligned: the tables, entry points and glyph data above it must add up to a whole number of pages (see the layout notes in lite40.asm)"
.errorif (MATDATA & $FF) != 0, "MATDATA must be page-aligned (see the layout notes in lite40.asm)"
.errorif (MATDATA - GLPHADDR) != 512, "GLPHADDR lo/hi tables must be exactly two pages"
.errorif (V1CPAL - V1CNTSC) != 48, "The V1CNTSC signature block must be 48 bytes"
.errorif (GLPHADDR - low_tables_end) != 0, "The low small tables must end where the glyph address table begins"
.errorif (high_tables_end != L40_CHROUT), "The high small tables must end where the entry points begin"

// every small table must sit inside one page, so that no indexed read of it crosses a page
.macro one_page(label, size)
{
	.errorif (label >> 8) != ((label + size - 1) >> 8), "A small table crosses a page: move small tables between the groups (see the layout notes in lite40.asm)"
}
:one_page(VICNTSC, 6)
:one_page(CROWOFFS, 13)
:one_page(CONCODEL, 13)
:one_page(CODEIDXH, 32)
:one_page(BITADDRH, 16)
:one_page(ROWOFFS, 24)
:one_page(COLOFFS, 40)
:one_page(BITADDRL, 16)
:one_page(V1CNTSC, 48)
:one_page(CODEIDXL, 32)
:one_page(VICPAL, 2)
