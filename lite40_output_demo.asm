// LITE-40 output demo
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace lite40_output_demo

// The output demo: shows how to include the LITE-40 package in your own program, and how to send characters,
// control codes and strings to the 40x24 display. Nothing else from the project is needed. (The package only displays: a program
// that needs to read a line from the keyboard can copy the editor in lite40_input_demo.asm, a separate demo program.)
//
// The package is included as a pre-assembled binary: there is one for each RAM block the package can sit at the top of, and this
// program uses artifacts/lite40_1.bin, for block 1 (the 8K expander); the others are commented-out alternatives (see THE PACKAGE
// below, which also explains how the binary is imported and copied to where it runs). A program that wants to assemble the package
// in from its sources instead imports lite40.asm: see the header of that file.
//
// The program file is small because it is packed: the BASIC loader, a start-up routine that copies things into place, the program
// and the package, with no gap between them. The program runs at $2000 and the package at the top of the block, so the start-up
// routine copies each to its address (the screen takes $1000-$1FFF, so nothing can run where the file loads).
//
// Build:  build.bat                                          (makes artifacts/lite40_1.bin and the others, and artifacts/lite40_output_demo.prg)
//         java -jar KickAss.jar lite40_output_demo.asm -o lite40_output_demo.prg         (to build just this program; needs artifacts/lite40_1.bin)
// Run:    xvic -memory 8k artifacts\lite40_output_demo.prg     or      LOAD"*",8,1 : RUN        (VIC-20 with an 8K or larger expansion)
//
// The package has two entry points, consecutive JMPs at the start of its code:
//
//     JSR L40_CHROUT    A = one PETSCII character or control code
//     JSR L40_STROUT    A = lo-byte, Y = hi-byte of a $00-terminated string of any length
//
// Both come back with A, X and Y unchanged (flags undefined), so a loop can keep its counters in X and Y across calls. The
// first call must be CLR: it switches the VIC to the 40x24 display and clears the screen.
//
// Two things to keep in mind when planning a screen:
//   * Colour has half the resolution of the text: it applies to blocks of 2x2 characters, so two text rows share one row of
//     colour. The first page puts one line of text on every other row, and the colours change in pairs of characters.
//   * Control codes are executed wherever they appear, including inside strings (there is no quote mode).

// The control codes the package acts on are the standard VIC-20 PETSCII codes.
.const CLR      = $93                                   // clear the screen and home the print position
.const WRAP_ON  = $01                                   // turn word wrap on (it affects strings; it is off after the first CLR)
.const WRAP_OFF = $02                                   // turn word wrap off (each sets the state: neither flips it, so you never need to know it)
.const HOME     = $13                                   // print position to column 0, row 0
.const RETURN   = $0D                                   // column 0 of the next row (also ends reverse mode)
.const DOWN     = $11                                   // down a row
.const UP       = $91                                   // up a row
.const RIGHT    = $1D                                   // right a column
.const LEFT     = $9D                                   // left a column
.const RVS_ON   = $12                                   // reverse mode on
.const RVS_OFF  = $92                                   // reverse mode off
.const LOWER    = $0E                                   // lower-case character set for later characters
.const UPPER    = $8E                                   // upper-case/graphics character set for later characters
.const BLACK    = $90                                   // colour: black
.const WHITE    = $05                                   // colour: white
.const RED      = $1C                                   // colour: red
.const CYAN     = $9F                                   // colour: cyan
.const PURPLE   = $9C                                   // colour: purple
.const GREEN    = $1E                                   // colour: green
.const BLUE     = $1F                                   // colour: blue
.const YELLOW   = $9E                                   // colour: yellow

// The host owns the border and background colours (the package never writes $900F) and the keyboard
.label VIC_COLOURS = $900F                              // b7-4 background, b3 normal/inverse, b2-0 border
.label GETIN       = $FFE4                              // KERNAL: read a key (the stock keyboard scan keeps running)
.const DEMO_BASE   = $2000                              // where the demonstration program goes: the bottom of block 1, well below the package

// Text is PETSCII: in the upper-case/graphics set the letters are $41-$5A (KickAssembler's own default is ASCII)
.encoding "petscii_upper"

// ------------------------------------------------ THE PACKAGE ------------------------------------------------
// The package is a pre-assembled binary, one for each RAM block it can sit at the top of. It holds absolute addresses, so it must run
// at the address it was built for: each binary ends at the top of its block, so the host only needs that address. The binary runs at
// the top of the block minus its length, and the entry points are just below the glyph block, which is the top 1,192 bytes.
//
// The recommended way to use the binary is to import it as one contiguous item, wherever it falls in your program file, and copy it
// to the address it runs at when the program starts. Here the segment at the end of this file imports it, packed after the program,
// and the start routine copies it to its home. The program file is then only as big as the program and the package together. The
// alternative, importing the binary at its home address (with .pc = the top of the block minus its length), makes the file hold
// every byte from the start of the program up to the top of the block, and the gap between the program and the package is filler.
// Pick the block by changing the file name and L40_TOP together (the alternatives are the commented-out lines).
.const L40_FILE = "artifacts/lite40_1.bin"               // block 1 (the 8K expander, $2000-$3FFF): the package ends at $3FFF
// .const L40_FILE = "artifacts/lite40_2.bin"            // block 2 (the 16K expander, $4000-$5FFF), with L40_TOP = $6000
// .const L40_FILE = "artifacts/lite40_3.bin"            // block 3 (the 24K expander, $6000-$7FFF), with L40_TOP = $8000
// .const L40_FILE = "artifacts/lite40_5.bin"            // block 5 (RAM at $A000-$BFFF), with L40_TOP = $C000
.var L40_TOP = $4000                                    // the top of the block the binary was built for (the address after its last byte)
.var lite40 = LoadBinary(L40_FILE)                      // the package, read from the file to find its length
.const PKG_SIZE = lite40.getSize()                      // the length of the package in bytes
.const PKG_HOME = L40_TOP - PKG_SIZE                    // the address the package runs at
.label L40_CHROUT = L40_TOP - 1192 - 6                  // the entry points are just below the glyph block, whichever block it is:
.label L40_STROUT = L40_CHROUT + 3                      // L40_CHROUT sends one character, L40_STROUT a $00-terminated string

// Where the loader and the copy routine are, and the zero page they use ($FB-$FF are free)
.const START = $120D                                    // the first byte after the BASIC loader below
.label SRC = $FB                                        // copy source pointer (lo-byte, hi-byte)
.label DST = $FD                                        // copy destination pointer (lo-byte, hi-byte)
.label COUNT = $FF                                      // copy byte count after the whole pages

// The program is assembled in its own segment, for the address it runs at. The loader segment (the default one, at the start of
// the file) brings its bytes in as one contiguous item, and the start routine copies them to DEMO_BASE
.segmentdef Demo [start=DEMO_BASE]


// ------------------------------------------------ MACROS ------------------------------------------------
// Send one byte to the display (5 bytes, 8 cycles plus the package routine)
.macro put_code(code)
{
			lda #code										// [2]		load the byte to send
			jsr L40_CHROUT									// [6]		send it (.A, .X and .Y come back unchanged)
}


// Print a $00-terminated string (7 bytes, 10 cycles plus the package routine)
.macro put_string(message)
{
			lda #<message									// [2]		set string address lo-byte
			ldy #>message									// [2]		set string address hi-byte
			jsr L40_STROUT									// [6]		print up to the $00 terminator
}


// ------------------------------------------------ THE PROGRAM ------------------------------------------------
.segment Demo
.pc = DEMO_BASE "DEMO"

// Set the screen colours
demo_start:
.pc = * "demo_start"
{
			lda #$08										// [2]		set black background and black border
			sta VIC_COLOURS									// [4]
// Fall-through into show_page_one
}


// Show page 1: single characters, control codes, cursor movement and strings, then wait for a key
show_page_one:
.pc = * "show_page_one"
{
			:put_code(CLR)									// the first call must be CLR (send it whenever you want a clean screen)

			// a banner: the colour and reverse codes are part of the string
			:put_string(BANNER)

			// 1. single characters: one call per byte
			:put_string(HEADING1)
			:put_code(WHITE)								// a control code is sent exactly like a character
			:put_code('L')									// the letters of LITE-40, one call each
			:put_code('I')
			:put_code('T')
			:put_code('E')
			:put_code('-')
			:put_code('4')
			:put_code('0')
			:put_code(' ')
			ldx #0											// [2]		then the alphabet, from a loop
alphaloop:	txa												// [2]		.X counts 0-25 and survives the calls
			clc												// [2]
			adc #'A'										// [2]
			jsr L40_CHROUT									// [6]
			inx												// [2]
			cpx #26											// [2]
			bne alphaloop									// [3/2]	loop until the alphabet is done
			:put_code(RETURN)
			:put_code(RETURN)

			// 2. control codes: colours from a table, reverse mode, character sets
			:put_string(HEADING2)
			:put_code(RVS_ON)								// solid colour bars: reverse spaces
			ldx #0											// [2]
barloop:	lda COLOURS,x									// [4]		get a colour code from the table
			jsr L40_CHROUT									// [6]
			ldy #4											// [2]		set four spaces per bar (a colour block is two characters wide)
fillloop:	:put_code(' ')
			dey												// [2]		.Y is a counter too, and survives the calls
			bne fillloop									// [3/2]	loop until the bar is done
			inx												// [2]
			cpx #7											// [2]
			bne barloop										// [3/2]	loop until every colour is done
			:put_code(RVS_OFF)
			:put_code(RETURN)
			:put_code(RETURN)
			:put_string(MODES)								// reverse and both character sets, inside one string

			// 3. cursor movement: there are no coordinates, only HOME and the cursor keys (move_cursor builds them)
			:put_string(HEADING3)
			ldx #0											// [2]		set column (0-39)
			ldy #14											// [2]		set row (0-23)
			jsr move_cursor									// [6]
			:put_string(LEFTTXT)
			ldx #15											// [2]
			ldy #14											// [2]
			jsr move_cursor									// [6]
			:put_string(MIDDLETXT)							// this one uses LEFT to correct a typo while printing
			ldx #32											// [2]
			ldy #14											// [2]
			jsr move_cursor									// [6]
			:put_string(RIGHTTXT)

			// 4. strings: a simple one, then one with its own colour codes
			ldx #0											// [2]
			ldy #16											// [2]
			jsr move_cursor									// [6]
			:put_string(HEADING4)
			:put_string(HELLO)
			:put_string(RAINBOW)

			// wait for a key (the stock keyboard scan is still running)
			ldx #0											// [2]
			ldy #22											// [2]
			jsr move_cursor									// [6]
			:put_string(PROMPT)
			jsr discard_keys								// [6]		wait for a key press
// Fall-through into show_page_two
}


// Show page 2: one long string that scrolls the screen, then wait for a key
show_page_two:
.pc = * "show_page_two"
{

			// 5. a long string: more than 256 bytes, with control codes in it (it scrolls the screen as it goes)
			:put_code(CLR)
			:put_string(SCROLLTEXT)
			jsr discard_keys								// [6]		wait for a key press
// Fall-through into show_page_three
}


// Show page 3: word wrap, then wait for a key and start again
show_page_three:
.pc = * "show_page_three"
{

			// 6. word wrap: code 1 turns it on and code 2 turns it off, and with it on a word that will not fit in the rest of the line goes to the next line
			:put_string(WRAPTEXT)
			jsr discard_keys								// [6]		wait for a key press
			jmp show_page_one								// [3]		show page 1 again
}


// Discard any key already waiting, then wait for a new key press
discard_keys:
.pc = * "discard_keys"
{
flushloop:	jsr GETIN										// [6]		read a key
			bne flushloop									// [3/2]	loop until the keyboard buffer is empty
// Fall-through into wait_key_press
}


// Wait for a key press
wait_key_press:
.pc = * "wait_key_press"
{
waitloop:	jsr GETIN										// [6]		read a key
			beq waitloop									// [3/2]	loop until a key is pressed
			rts												// [6]
}


// Move the print position to a column and row
// => X		Column (0-39)
// => Y		Row (0-23)
move_cursor:
.pc = * "move_cursor"
{
			:put_code(HOME)									// column 0, row 0
			cpy #0											// [2]		check for row 0
			beq cols										// [2/3]	skip if already on row 0
rowloop:	:put_code(DOWN)									// move down a row
			dey												// [2]
			bne rowloop										// [3/2]	loop until the row is reached
cols:		cpx #0											// [2]		check for column 0
			beq done										// [2/3]	skip if already in column 0
colloop:	:put_code(RIGHT)								// move right a column
			dex												// [2]
			bne colloop										// [3/2]	loop until the column is reached
done:		rts												// [6]
}


// ------------------------------------------------ DATA ------------------------------------------------
// Every string ends with a $00 byte; pieces written one after another are one string

COLOURS:				// Colour codes for the bars
.pc = * "COLOURS"		// Seven colour codes (7 bytes)
.byte WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW

// 39 characters in reverse white, then RETURN (which ends reverse mode) twice: the second RETURN moves down to the next
// text line, because a colour row covers two text rows
BANNER:					// Banner string
.pc = * "BANNER"		// WHITE, RVS_ON, 39 characters, RETURN x 2, $00 terminator (44 bytes)
.byte WHITE, RVS_ON
.text " LITE-40: 40 COLUMNS BY 24 ROWS VIC-20 "
.byte RETURN, RETURN, 0

HEADING1:				// Heading string 1
.pc = * "HEADING1"		// YELLOW, text, RETURN x 2, $00 terminator (36 bytes)
.byte YELLOW
.text "SINGLE CHARACTERS: ONE CALL EACH"
.byte RETURN, RETURN, 0

HEADING2:				// Heading string 2
.pc = * "HEADING2"		// YELLOW, text, RETURN x 2, $00 terminator (40 bytes)
.byte YELLOW
.text "CONTROL CODES: COLOUR, REVERSE, CASE"
.byte RETURN, RETURN, 0

// Reverse mode, then the lower-case character set (the text is PETSCII with lower-case letters), then back to upper case
MODES:					// Reverse and character set string
.pc = * "MODES"			// Control codes and text, RETURN x 2, $00 terminator (41 bytes)
.byte CYAN, RVS_ON
.text " REVERSE "
.byte RVS_OFF
.text " NORMAL "
.byte LOWER
.encoding "petscii_mixed"
.text "Lower+UPPER "
.encoding "petscii_upper"
.byte UPPER
.text "BACK"
.byte RETURN, RETURN, 0

HEADING3:				// Heading string 3
.pc = * "HEADING3"		// YELLOW, text, RETURN x 2, $00 terminator (39 bytes)
.byte YELLOW
.text "CURSOR: HOME, DOWN, RIGHT, LEFT, UP"
.byte RETURN, RETURN, 0

LEFTTXT:				// Cursor movement label, left
.pc = * "LEFTTXT"		// WHITE, text, $00 terminator (6 bytes)
.byte WHITE
.text "LEFT"
.byte 0

MIDDLETXT:				// Cursor movement label, middle
.pc = * "MIDDLETXT"		// WHITE, text with a typo and a LEFT code, $00 terminator (10 bytes)
.byte WHITE
.text "MIDDLX"												// a typo...
.byte LEFT													// ...back up one column...
.text "E"													// ...and overwrite it
.byte 0

RIGHTTXT:				// Cursor movement label, right
.pc = * "RIGHTTXT"		// WHITE, text, $00 terminator (7 bytes)
.byte WHITE
.text "RIGHT"
.byte 0

HEADING4:				// Heading string 4
.pc = * "HEADING4"		// YELLOW, text, RETURN x 2, $00 terminator (40 bytes)
.byte YELLOW
.text "STRINGS: ONE CALL FOR A WHOLE STRING"
.byte RETURN, RETURN, 0

HELLO:					// Greeting string
.pc = * "HELLO"			// GREEN, text, RETURN x 2, $00 terminator (17 bytes)
.byte GREEN
.text "HELLO, WORLD!"
.byte RETURN, RETURN, 0

// A colour code before every pair of characters (a colour block is two characters wide)
.var rainbow_text = "COLOUR CODES INSIDE A STRING"
.var rainbow_codes = List().add(RED, YELLOW, GREEN, CYAN, BLUE, PURPLE)
RAINBOW:				// Rainbow string
.pc = * "RAINBOW"		// A colour code and two characters, repeated, $00 terminator (43 bytes)
.for (var i = 0; i < rainbow_text.size(); i = i + 2)
{
	.byte rainbow_codes.get(mod(i / 2, 6))
	.text rainbow_text.substring(i, min(i + 2, rainbow_text.size()))
}
.byte 0

PROMPT:					// Prompt string
.pc = * "PROMPT"		// WHITE, text, $00 terminator (22 bytes)
.byte WHITE
.text "PRESS A KEY FOR MORE"
.byte 0

// The second page: one string of more than 700 bytes. Each line has its own colour code, and there are more lines than
// rows, so the screen scrolls
.var line_codes = List().add(WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW)
SCROLLTEXT:				// Long string for page 2
.pc = * "SCROLLTEXT"	// Three lines, then 24 numbered lines, then a prompt, $00 terminator (726 bytes)
.byte WHITE
.text "ONE STRING, ANY LENGTH. THE SCREEN"
.byte RETURN
.text "SCROLLS WHEN THE TEXT REACHES THE"
.byte RETURN
.text "BOTTOM ROW."
.byte RETURN, RETURN
.for (var i = 1; i <= 24; i++)
{
	.byte line_codes.get(mod(i, 7))
	.text "LINE " + toIntString(i) + " OF A LONG STRING"
	.byte RETURN
}
.byte WHITE
.text "PRESS A KEY TO START AGAIN"
.byte 0

WRAPTEXT:				// Long string for page 3: word wrap
.pc = * "WRAPTEXT"		// State, CLR, heading, word wrap on and a paragraph, word wrap off and a paragraph, prompt, $00 terminator (350 bytes)
.byte UPPER, RVS_OFF, BLUE, CLR
.byte YELLOW
.text "WORD WRAP (CODE 1 ON, CODE 2 OFF)"
.byte RETURN, RETURN
.byte WRAP_ON, WHITE
.text "WITH WORD WRAP ON, A WORD THAT WILL NOT FIT IN WHAT IS LEFT OF THE LINE MOVES TO THE START OF THE NEXT ONE, SO NO WORD IS EVER CUT IN TWO AT THE EDGE OF THE SCREEN."
.byte RETURN, RETURN
.byte WRAP_OFF
.text "WITH IT OFF THE TEXT SIMPLY RUNS ON TO THE NEXT LINE WHEREVER IT REACHES THE EDGE, SO WORDS ARE CUT IN TWO."
.byte RETURN, RETURN
.text "PRESS A KEY TO START AGAIN"
.byte 0

demo_end:
.errorif demo_end > PKG_HOME, "The program runs into the package: it ends at $" + toHexString(demo_end) + " and the package starts at $" + toHexString(PKG_HOME)


// ------------------------------------------------ LOADING ------------------------------------------------
.segment Default

// BASIC loader, so the program starts with RUN. $1201 is where BASIC starts on a VIC-20 with an 8K or larger expansion. The file
// loads from here, so everything from $1201 up to the end of the package image is in the file
.pc = $1201 "BASIC"
			.word basicend									// link to the next BASIC line (none follows)
			.word 10										// line number
			.byte $9E										// SYS token
			.text toIntString(START)						// address of 'start'
			.byte 0											// end of line
basicend:	.word 0											// end of program
.errorif * != START, "START must be the address after the BASIC loader"


// Move the package and the program to where they run, then start the program. Neither can run where the file loaded it: the
// screen takes $1000-$1FFF, and the package must be at the top of its block. The package goes first, because its image sits
// where the program will run
start:
.pc = START "start"
{
			lda #<package_src								// [2]		set the source: the package image, imported as one item
			sta SRC											// [3]
			lda #>package_src								// [2]
			sta SRC+1										// [3]
			lda #<PKG_HOME									// [2]		set the destination: the address the package runs at
			sta DST											// [3]
			lda #>PKG_HOME									// [2]
			sta DST+1										// [3]
			ldx #>PKG_SIZE									// [2]		set the whole pages to copy
			lda #<PKG_SIZE									// [2]		and the bytes after them
			jsr copy_block									// [6]

			lda #<program_src								// [2]		set the source: the program image
			sta SRC											// [3]
			lda #>program_src								// [2]
			sta SRC+1										// [3]
			lda #<DEMO_BASE									// [2]		set the destination: the address the program runs at
			sta DST											// [3]
			lda #>DEMO_BASE									// [2]
			sta DST+1										// [3]
			ldx #>(demo_end - DEMO_BASE)					// [2]		set the whole pages to copy
			lda #<(demo_end - DEMO_BASE)					// [2]		and the bytes after them
			jsr copy_block									// [6]

			jmp demo_start									// [3]		run the program
}


// Copy a block of bytes upwards
// => SRC		Source address
// => DST		Destination address
// => X			Whole pages to copy
// => A			Bytes to copy after the whole pages
copy_block:
.pc = * "copy_block"
{
			sta COUNT										// [3]		stash the bytes after the whole pages
			ldy #0											// [2]		start at the first byte
			cpx #0											// [2]		check for whole pages
			beq tail										// [2/3]	skip if there are none
pageloop:	lda (SRC),y										// [5]		get a byte
			sta (DST),y										// [6]		copy it
			iny												// [2]
			bne pageloop									// [3/2]	loop until the page is done
			inc SRC+1										// [5]		step to the next source page
			inc DST+1										// [5]		step to the next destination page
			dex												// [2]
			bne pageloop									// [3/2]	loop until every page is done
tail:		ldx COUNT										// [3]		get the bytes after the pages (.Y is zero)
			beq done										// [2/3]	skip if there are none
tailloop:	lda (SRC),y										// [5]		get a byte
			sta (DST),y										// [6]		copy it
			iny												// [2]
			dex												// [2]
			bne tailloop									// [3/2]	loop until done
done:		rts												// [6]
}


// ------------------------------------------------ THE IMAGE ------------------------------------------------
// The program and the package, packed together in the file
program_src:
.pc = * "PROGRAM IMAGE"
.segmentout [segments="Demo"]							// the program's bytes, assembled for DEMO_BASE
package_src:
.pc = * "LITE-40 IMAGE"
.import binary L40_FILE								// the package: the code and tables, the entry points, and the glyphs last
