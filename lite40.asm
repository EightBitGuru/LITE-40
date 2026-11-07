// LITE-40 package
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

// The whole package as one block that ends at the top of a RAM block: the glyph data is at the very top, the two entry points sit
// just below it, the tables below those, and the code lowest, with the least dead space that the placement rules allow (21 bytes, below) and nothing wasted above it. The block it is built for is chosen with L40_TOP below; the default is the top of block 1 (the 8K expander,
// $2000-$3FFF), so the package is assembled at $32B6 and ends at $3FFF, with L40_CHROUT at $3B52. Block 2 (16K), block 3 (24K)
// and block 5 (RAM at $A000) are the commented-out options below, or pass the top on the command line in decimal, for example
// :L40_TOP=24576 for $6000. A program that assembles the package in from source imports this file:
//
//     .import source "lite40.asm"
//
// and builds with  -libdir <project folder>  (so the package finds its own files)  and, to pick another block,  :L40_TOP=<decimal>.
// L40_TOP, L40_CHROUT and L40_STROUT are then available to the host. Every address in the package is derived from L40_TOP.
//
//     JSR L40_CHROUT       ; A = PETSCII character or control code
//                         ; A, X, Y preserved; flags undefined
//
//     JSR L40_STROUT       ; A = lo-byte, Y = hi-byte of the address of a $00-terminated PETSCII string (any length)
//                         ; A, X, Y preserved; flags undefined
//
// The first call must be CLR ($93): it switches the VIC to the 40x24 display if needed, disables the stock cursor, and
// clears the screen. The package never calls or replaces any KERNAL vector. The control codes are the standard VIC-20
// PETSCII codes; the ones that do something are listed in README.md.
//
// Layout, low to high. The package is given a fixed amount of room, L40_SPACE, in bytes, so it starts at L40_TOP - L40_SPACE. The code
// is assembled upwards from there and must end before the tables; the build stops with a message if it does not, and a spare byte
// between the end of the code and the tables is dead space (the build reports how many, and the tests insist on none). Everything
// below the code is pinned from the top of the package down, so that no byte is wasted between them: the glyph data (L40_GLYPH_COUNT glyphs of 8
// bytes) at the very top, the two entry points just below it, then the small tables (the high group), the character matrix table, the
// glyph address table, and the rest of the small tables (the low group), which end where the code must end. The glyph address table
// (two pages) and the character matrix table must start on page boundaries, and every small table must sit inside one page; the sizes
// of the two groups of small tables (L40_LOW_TABLES_SIZE and L40_HIGH_TABLES_SIZE) are chosen so that the sizes add up, and the
// build stops with a message if a change breaks that. Several routines are also sensitive to where they sit within a 256-byte page:
// initialise_screen and scroll_lines_up each inside one page, the control code handlers inside one page, and the three branches that
// most characters take inside one page (L40_character_output.asm). The code start is not page-aligned, so these depend on L40_SPACE
// and on the order of the files: the build checks them all, and if a change to the code breaks one, change L40_SPACE (any change moves
// every routine), or reorder the files, or put a .fill in front of a file, until the build passes. With the files in the order below
// the code needs no padding at all when it starts at offset 182 of a page (L40_SPACE 3402); the nearest start with a bigger offset
// that the rules allow is one that would need padding inside the code, so the 21 bytes between the end of the code and the tables
// are the least dead space that the rules leave. The code is 1189 bytes and the whole package 3381 bytes of code, tables and
// glyphs. Because the start is fixed, what comes before a routine moves it and what comes after does not.

// Which block the package is built for: the top of the block (the address just above its last byte)
.var L40_TOP = $4000									// block 1 (BLK1, the 8K expander, $2000-$3FFF): the package is at $3000-$3FFF
// .var L40_TOP = $6000									// block 2 (BLK2, the 16K expander, $4000-$5FFF): the package is at $5000-$5FFF
// .var L40_TOP = $8000									// block 3 (BLK3, the 24K expander, $6000-$7FFF): the package is at $7000-$7FFF
// .var L40_TOP = $C000									// block 5 (BLK5 as RAM, $A000-$BFFF): the package is at $B000-$BFFF
.if (cmdLineVars.containsKey("L40_TOP"))
{
			.eval L40_TOP = cmdLineVars.get("L40_TOP").asNumber()			// the command line wins
}

.errorif (L40_TOP != $4000) && (L40_TOP != $6000) && (L40_TOP != $8000) && (L40_TOP != $C000), "L40_TOP must be the top of a RAM block: $4000 (block 1), $6000 (block 2), $8000 (block 3) or $C000 (block 5)"

.const L40_SPACE = 3402									// the room reserved for the package, in bytes: the code starts this far below the top (21 bytes of it are spare: see the layout notes above)
.const L40_START = L40_TOP - L40_SPACE					// the first byte of the package (not page-aligned: see the layout notes above)
.const L40_GLYPH_COUNT = 149								// the distinct glyphs in the glyph data (the glyph data file is checked against it)
.const L40_GLYPHS = L40_TOP - L40_GLYPH_COUNT * 8			// the glyph data: 8 bytes a glyph, at the very top of the package
.label L40_CHROUT = L40_GLYPHS - 6						// Package entry point: a JMP to the character output routine, just below the glyphs (a stable offset from L40_TOP)
.label L40_STROUT = L40_CHROUT + 3						// String entry point: the next three bytes

// The tables, from the top down (see L40_static_data.asm): the sizes of the two groups of small tables are checked there
.const L40_HIGH_TABLES_SIZE = 98							// the small tables just below the entry points
.const L40_HIGH_TABLES = L40_CHROUT - L40_HIGH_TABLES_SIZE
.const L40_MATDATA = L40_HIGH_TABLES - 240					// the character matrix table (20 x 12): page-aligned
.const L40_GLPHADDR = L40_MATDATA - 512						// the glyph address table (lo-bytes and hi-bytes for each of the two character sets): page-aligned
.const L40_LOW_TABLES_SIZE = 144							// the rest of the small tables, just below the glyph address table
.const L40_LOW_TABLES = L40_GLPHADDR - L40_LOW_TABLES_SIZE	// where the code must end

.import source "kickass_opcodes.asm"						// KickAssembler opcode pseudocommands
.import source "vic20_system_constants.asm"					// VIC-20 system constants
.import source "vic20_system_memory.asm"					// VIC-20 system memory labels
.import source "L40_runtime_memory.asm"						// LITE-40 runtime memory labels
.import source "L40_runtime_constants.asm"					// LITE-40 runtime constants

.pc = L40_START "L40_CODE"
package_start:
code:
.import source "L40_string_output.asm"						// String output, with word wrap
.import source "L40_character_output.asm"					// Character output (the CHROUT replacement)
.import source "L40_runtime_setup.asm"						// Display setup
.import source "L40_controlcode_handlers.asm"				// Control code output handlers (all inside one page)
.import source "L40_helper_routines.asm"					// General helper routines (initialise_screen and scroll_lines_up each inside one page, with no padding in front of them)
code_end:

// The code must end before the tables: if it does not, there is not enough room for it
.errorif code_end > L40_LOW_TABLES, "The code is " + [code_end - L40_LOW_TABLES] + " bytes too long for L40_SPACE: raise L40_SPACE by " + [code_end - L40_LOW_TABLES] + " (and check the placement rules: the code start moves)"

// (The routines that must not cross a page check themselves, in their own files)

.label data = L40_LOW_TABLES
.import source "L40_static_data.asm"						// Static data structures: the small tables below and above the two page-aligned tables, each group placed by its own .pc

.pc = L40_CHROUT "L40_CHROUT"
entry_points:
			jmp L40_character_output.character_output		// [3]		character entry point (stable offset from L40_TOP)
			jmp L40_string_output.print_string				// [3]		string entry point (L40_CHROUT + 3)

.pc = L40_GLYPHS "L40_GLYPHS"
glyphs:
glyph_data:
.import source "L40_glyph_data.asm"							// LITE-40 glyph data (each distinct normal glyph once)
package_end:

.print "L40_TOP:      $" + toHexString(L40_TOP)
.print "L40_START:    $" + toHexString(L40_START)
.print "L40_CHROUT:   $" + toHexString(L40_CHROUT)
.print "L40_STROUT:   $" + toHexString(L40_STROUT)
.print "CODE BYTES:  " + [code_end - code]
.print "DATA BYTES:  " + [glyphs - L40_LOW_TABLES]
.print "TOT. BYTES:  " + [package_end - package_start - (L40_LOW_TABLES - code_end)] + " (glyphs " + [package_end - glyph_data] + ")"
.print "FREE BYTES:  " + [L40_LOW_TABLES - code_end]

.errorif package_end != L40_TOP, "The package does not end at L40_TOP"
.errorif package_end - glyph_data != L40_GLYPH_COUNT * 8, "L40_GLYPH_COUNT does not match the glyph data: it is " + [(package_end - glyph_data) / 8] + " glyphs"
.errorif entry_points != L40_CHROUT, "The entry points are not just below the glyph data"

// The package must not overlap the screen/bitmap ($1000-$1FFF), the VIC and I/O area ($8000-$9FFF, which also holds the colour
// RAM), page 0-3 or the ROMs ($C000 up): the four block tops allowed above keep it wholly inside block 1, 2, 3 or 5
.errorif L40_START < $2000, "The package must start at $2000 or higher: $0000-$1FFF holds the system RAM pages, BLK0 and the screen bitmap"
