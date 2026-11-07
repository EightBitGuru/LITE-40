// LITE-40 input demo
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace lite40_input_demo

// A complete program that reads a line of text from the keyboard onto the 40x24 display. The package only displays, so a program
// that needs input does the editing itself: this is a reference line editor, written as a host would write one, using only the
// package's public interface (L40_CHROUT, L40_STROUT and the control codes), the KERNAL's GETIN and PLOT, and the jiffy clock. It is
// not part of the package and the package knows nothing about it. It is a program of its own, separate from
// lite40_output_demo.asm, and includes the package the same way (see THE PACKAGE below: imported as one item, packed after the
// program, and copied to the top of the block when the program starts).
//
// Build:  build.bat                                          (makes artifacts/lite40_1.bin and the others, and artifacts/lite40_input_demo.prg)
//         java -jar KickAss.jar lite40_input_demo.asm -o lite40_input_demo.prg         (to build just this program; needs artifacts/lite40_1.bin)
// Run:    xvic -memory 8k artifacts\lite40_input_demo.prg     or      LOAD"*",8,1 : RUN        (VIC-20 with an 8K or larger expansion)
//
// To use the editor in your own program, copy everything under "LINE INPUT" below: the routines, their RAM labels and constants.
// It needs these from the host: L40_CHROUT and L40_STROUT (the package), GETIN, and the constants RETURN, LEFT, RIGHT, RVS_ON,
// RVS_OFF and WRAP_OFF. Then:
//
//     lda #38                      A = the most characters to accept
//     jsr input_line               prints the cursor and edits the line at the print position
//                                  A = the number of characters typed; INBUF holds them, followed by $00
//
// The line starts at the print position when input_line is called, so a prompt is printed first. The line uses columns up to 38, so
// that the cursor never has to sit in column 39 (printing there moves on to the next row, and on the bottom row scrolls the
// screen): the most it accepts is 39 less the start column, or A if that is smaller. When the line is full the cursor is shown
// over its last character. Keys: any of the characters in accept (space to Z, and shifted letters), cursor left and right, DEL
// (deletes the character before the cursor), INS (opens a blank space at the cursor) and RETURN (ends the line and moves down a row).
//
// How it works. The package cannot read the screen back, so the program keeps the line in INBUF and draws it. The print position is
// kept on the cursor's cell between keys, because the package's own cursor codes (LEFT and RIGHT) are the only way to move it:
// move_to uses PLOT to find the column the package is at, and sends LEFT or RIGHT codes until it gets to the one it wants. Typing,
// INS and DEL change INBUF and then redraw the line from the first character that changed with one L40_STROUT call, and blank the
// cell after the end of the line (a deleted character leaves one behind). The cursor is a reversed copy of the character under it
// (RVS ON, the character, RVS OFF), and it blinks by drawing that cell plain and reversed in turn.
//
// What a host needs to know. Word wrap is respected: it reads the package's word wrap flag (WRAPFLAG, $E8: b7 is set for on) when it is
// called, turns word wrap off ($02) while it edits, because the tail of the line is redrawn with L40_STROUT, and turns it on again
// ($01) before it returns if it was on. It leaves reverse mode off. The screen's colour is whatever it was: colour covers 2x2 characters, so the cursor takes the colour of its cell and a
// colour code should be sent before the prompt, not while editing. The line is PETSCII: shifted letters are $C1-$DA, which the
// package prints as upper-case letters in the lower-case character set (and as graphics in the upper-case set), so a program
// that wants to read the line should fold the case.

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
.const DEMO_BASE   = $2000                              // where the program goes: the bottom of block 1, well below the package

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
.pc = DEMO_BASE "EXAMPLE"

// Set the screen colours
demo_start:
.pc = * "demo_start"
{
			lda #$08										// [2]		set black background and black border
			sta VIC_COLOURS									// [4]
// Fall-through into show_input
}


// Ask for a line, show it back, wait for a key and ask again
show_input:
.pc = * "show_input"
{
			:put_string(INPUTTEXT)							// the explanation and the prompt
			lda #38											// [2]		accept up to 38 characters (the editor limits it to the room left on the line)
			jsr input_line									// [6]		edit a line at the print position until RETURN
			:put_string(YOUTYPED)
			:put_string(INBUF)								// the line that was typed (the editor leaves it in INBUF, followed by $00)
			:put_string(AGAIN)
			jsr discard_keys								// [6]		wait for a key press
			jmp show_input									// [3]		ask again
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


// ------------------------------------------------ LINE INPUT ------------------------------------------------
// The host's RAM: the line and the editor's state, in the cassette buffer ($033C-$03FB)
.label INBUF   = $033C		// The line: up to 38 characters, then a $00 terminator (39 bytes)
.label INSTART = $0363		// Column where the line starts (0-38)
.label INCAP   = $0364		// Most characters the line can hold
.label INLEN   = $0365		// Characters in the line now (0 to INCAP)
.label INPOS   = $0366		// Cursor position in the line (0 to INLEN)
.label INSHOWN = $0367		// Cursor cell flag (b7 -> 0=drawn plain, 1=drawn reversed)
.label INFLIP  = $0368		// Jiffy clock low byte at which the cursor next blinks
.label INFROM  = $0369		// First character index to redraw
.label INCHAR  = $036A		// The character being inserted
.label INTARG  = $036B		// Column that move_to is moving to
.label INWRAP  = $036C		// The caller's word wrap state, to put back (b7 -> 0=off, 1=on)

// The KERNAL and the keys
.label PLOT    = $FFF0		// KERNAL: read the print position with Carry set (.X = row, .Y = column)
.label WRAPFLAG = $00E8		// The package's word wrap flag (b7 -> 0=off, 1=on): the program may read it, but only the control codes $01 and $02 change it
.label JIFFYLO = $00A2		// Jiffy clock low byte (60 a second on NTSC, 50 on PAL; the stock interrupt keeps it going)
.const DEL     = $14			// DEL key: delete the character before the cursor
.const INS     = $94			// SHIFT+DEL (INS) key: open a blank space at the cursor
.const BLINK   = 16			// Jiffies between one blink and the next

.errorif (INBUF >> 8) != ((INBUF + 40) >> 8), "INBUF must sit inside one page: the string address is built from its lo-byte"


// Edit a line of text at the print position until RETURN is pressed
// => A		Most characters to accept (1-38)
// <= A		Number of characters in the line (INBUF holds them, then $00)
input_line:
.pc = * "input_line"
{

			// set the limit: the room from the start column to column 38, or less if the caller asked for less
			sta INCAP										// [4]		set the limit the caller asked for
			lda WRAPFLAG									// [3]		get the word wrap state the caller has (b7 is set for on)
			sta INWRAP										// [4]		keep it, to put back when the line ends
			lda #0											// [2]
			sta INLEN										// [4]		start with an empty line (the length is what is returned if there is no room for one)
			lda #WRAP_OFF									// [2]		the tail of the line is redrawn with L40_STROUT, so make sure word wrap is off
			jsr L40_CHROUT									// [6]
			lda #RVS_OFF									// [2]		make sure reverse mode is off
			jsr L40_CHROUT									// [6]
			sec												// [2]		set Carry to read the print position
			jsr PLOT										// [6]		get the print position (.Y = column)
			sty INSTART										// [4]		set the column the line starts in
			lda #39											// [2]		get the room from the start column to column 38
			sec												// [2]
			sbc INSTART										// [4]
			cmp INCAP										// [4]		check for more room than the caller asked for
			bcs room										// [3/2]	keep the caller's limit if the room is enough
			sta INCAP										// [4]		set the room as the limit
room:		lda INCAP										// [4]		check for no room at all (or none asked for)
			beq leave										// [2/3]	no room: leave with a length of zero

			// start with an empty line, and show the cursor
			lda #0											// [2]
			sta INPOS										// [4]		set the cursor position
			sta INBUF										// [4]		set the terminator
			lda #$80										// [2]		show the cursor
			jsr show_cell									// [6]
			jsr restart_blink								// [6]		start the blink timing

			// read keys until RETURN, blinking the cursor while waiting
getkey:		jsr GETIN										// [6]		read a key (the stock keyboard scan keeps running)
			bne havekey										// [2/3]	handle it
			jsr blink										// [6]		no key: blink the cursor when it is time
			jmp getkey										// [3]		loop for a key
havekey:	cmp #RETURN										// [2]		check for RETURN
			beq finish										// [2/3]	end the line
			jsr handle_key									// [6]		edit the line
			jsr restart_blink								// [6]		show the cursor, and time the next blink from now
			jmp getkey										// [3]		loop for the next key

			// end the line: draw the cursor's cell plain, move down a row and return the length
finish:		lda #0											// [2]		draw it plain
			jsr show_cell									// [6]
			lda #RETURN										// [2]		move to the start of the next row (this also ends reverse mode)
			jsr L40_CHROUT									// [6]
leave:		bit INWRAP										// [4]		check the word wrap state the caller had (b7 is set for on)
			bpl done										// [2/3]	it was off, and it is off now
			lda #WRAP_ON									// [2]		it was on: turn it on again
			jsr L40_CHROUT									// [6]
done:		lda INLEN										// [4]		get the length
			rts												// [6]
}


// Act on one key that is not RETURN
// => A		Key (PETSCII)
handle_key:
.pc = * "handle_key"
{
			cmp #LEFT										// [2]		check for cursor left
			beq key_left									// [2/3]
			cmp #RIGHT										// [2]		check for cursor right
			beq key_right									// [2/3]
			cmp #DEL										// [2]		check for DEL
			beq key_delete									// [2/3]
			cmp #INS										// [2]		check for INS
			beq key_insert									// [2/3]
			jsr accept										// [6]		check for a character to type (.A comes back unchanged)
			bcs key_typed									// [3/2]	type it
			rts												// [6]		ignore every other key
}


// Move the cursor one character left, if it is not at the start of the line
key_left:
.pc = * "key_left"
{
			lda INPOS										// [4]		get the cursor position
			beq exit										// [2/3]	skip if it is at the start
			lda #0											// [2]		draw the cursor's cell plain
			jsr show_cell									// [6]
			dec INPOS										// [6]		move the cursor
			lda #$80										// [2]		draw its new cell reversed
			jmp show_cell									// [3]		exit via show_cell
exit:		rts												// [6]
}


// Move the cursor one character right, if it is not at the end of the line
key_right:
.pc = * "key_right"
{
			lda INPOS										// [4]		get the cursor position
			cmp INLEN										// [4]		check for the end of the line
			bcs exit										// [2/3]	skip if it is there
			lda #0											// [2]		draw the cursor's cell plain
			jsr show_cell									// [6]
			inc INPOS										// [6]		move the cursor
			lda #$80										// [2]		draw its new cell reversed
			jmp show_cell									// [3]		exit via show_cell
exit:		rts												// [6]
}


// Delete the character before the cursor, and close up the line
key_delete:
.pc = * "key_delete"
{
			lda INPOS										// [4]		get the cursor position
			beq exit										// [2/3]	skip if it is at the start

			// draw the cursor's cell plain first: the line is about to get shorter, and the cursor may be on a cell past its new end,
			// which the redraw would not reach
			lda #0											// [2]
			jsr show_cell									// [6]
			ldx INPOS										// [4]		get the cursor position again (show_cell changed .X)

			// move the rest of the line, and the terminator, down one place
shift:		lda INBUF,x										// [4]		get a character
			sta INBUF-1,x									// [5]		move it down
			inx												// [2]
			cpx INLEN										// [4]		check for the end of the line
			bcc shift										// [3/2]	loop until the character before the terminator has moved
			beq shift										// [3/2]	and once more for the terminator itself

			// redraw from where the cursor now is
			dec INLEN										// [6]		the line is one shorter
			dec INPOS										// [6]		the cursor has moved back
			ldx INPOS										// [4]		redraw from the cursor
			jmp repaint										// [3]		exit via repaint
exit:		rts												// [6]
}


// Open a blank space at the cursor (the cursor stays where it is)
key_insert:
.pc = * "key_insert"
{
			lda #' '										// [2]		insert a space
			jsr insert_char									// [6]		(.X comes back as the cursor position)
			bcs exit										// [2/3]	skip if the line is full
			jmp repaint										// [3]		redraw from the cursor: it is now on the space
exit:		rts												// [6]
}


// Insert a typed character at the cursor, and move the cursor on
// => A		Character (PETSCII)
key_typed:
.pc = * "key_typed"
{
			jsr insert_char									// [6]		(.X comes back as the cursor position)
			bcs exit										// [2/3]	skip if the line is full
			inc INPOS										// [6]		move the cursor past the new character
			jmp repaint										// [3]		redraw from the character
exit:		rts												// [6]
}


// Insert a character in the line at the cursor position, without moving the cursor
// => A		Character (PETSCII)
// <= X		Cursor position (the first index that needs redrawing)
// <= C		Set if the line is full and nothing was inserted
insert_char:
.pc = * "insert_char"
{
			sta INCHAR										// [4]		stash the character
			ldx INLEN										// [4]		get the length
			cpx INCAP										// [4]		check for a full line
			bcs exit										// [2/3]	return with Carry set if it is

			// move the rest of the line, and the terminator, up one place
shift:		lda INBUF,x										// [4]		get a character
			sta INBUF+1,x									// [5]		move it up
			cpx INPOS										// [4]		check for the cursor position
			beq place										// [2/3]	stop when it has been reached
			dex												// [2]
			bpl shift										// [3/2]	loop until the cursor position (always taken: the loop stops there)

			// put the character in the gap
place:		lda INCHAR										// [4]		get the character
			sta INBUF,x										// [5]		set it
			inc INLEN										// [6]		the line is one longer
			clc												// [2]		return with Carry clear
exit:		rts												// [6]
}


// Check whether a key is a character to type: space to Z, and the shifted letters
// => A		Key (PETSCII)
// <= A		Unchanged
// <= C		Set if the key is a character to type
accept:
.pc = * "accept"
{
			cmp #$C1										// [2]		check for the shifted letters ($C1-$DA)
			bcs shifted										// [3/2]
			cmp #$5B										// [2]		check for the range space to Z ($20-$5A)
			bcs no											// [2/3]	reject anything above it
			cmp #$20										// [2]		Carry is set if the key is $20 or more
			rts												// [6]
shifted:	cmp #$DB										// [2]		check for the end of the shifted letters
			bcs no											// [2/3]	reject anything above them
			sec												// [2]		accept it
			rts												// [6]
no:			clc												// [2]		reject it
			rts												// [6]
}


// Move the print position along its row to a column, with the package's LEFT and RIGHT codes
// => A		Column (0-38)
move_to:
.pc = * "move_to"
{
			sta INTARG										// [4]		stash the column
moveloop:	sec												// [2]		set Carry to read the print position
			jsr PLOT										// [6]		get the print position (.Y = column)
			cpy INTARG										// [4]		compare it with the column wanted
			beq exit										// [2/3]	done when they are the same
			lda #RIGHT										// [2]		move right if it is to the left of it
			bcc move										// [3/2]	(Carry is clear if .Y is less than the column wanted)
			lda #LEFT										// [2]		otherwise move left
move:		jsr L40_CHROUT									// [6]		move one column
			jmp moveloop									// [3]		check again
exit:		rts												// [6]
}


// Get the index of the character under the cursor: its position, or the last character if the line is full
// <= X		Index (0 to INCAP-1)
cell_index:
.pc = * "cell_index"
{
			ldx INPOS										// [4]		get the cursor position
			cpx INCAP										// [4]		check for the position after the last character of a full line
			bcc exit										// [2/3]
			dex												// [2]		show the cursor over the last character instead: there is no room after it
exit:		rts												// [6]
}


// Draw the character cell under the cursor, plain or reversed, and leave the print position on it
// => A		$80 to draw it reversed (the cursor), $00 to draw it plain
show_cell:
.pc = * "show_cell"
{
			sta INSHOWN										// [4]		stash the style
			jsr cell_index									// [6]		get the index of the character under the cursor
			txa												// [2]
			clc												// [2]
			adc INSTART										// [4]		add the start column to get its column
			jsr move_to										// [6]		move the print position to it
			jsr cell_index									// [6]		get the index again (move_to changed .X)
			lda #' '										// [2]		use a space past the end of the line
			cpx INLEN										// [4]		check for the end of the line
			bcs blank										// [3/2]
			lda INBUF,x										// [4]		get the character
blank:		pha												// [3]		stash it
			bit INSHOWN										// [4]		check the style (b7 is set for reversed)
			bpl plain										// [2/3]
			lda #RVS_ON										// [2]		start reverse mode
			jsr L40_CHROUT									// [6]
plain:		pla												// [4]		get the character
			jsr L40_CHROUT									// [6]		draw it
			lda #RVS_OFF									// [2]		end reverse mode
			jsr L40_CHROUT									// [6]
			lda #LEFT										// [2]		move back onto the cell
			jmp L40_CHROUT									// [3]		exit via L40_CHROUT
}


// Redraw the line from an index to the end, blank the cell after it, and draw the cursor
// => X		Index of the first character to redraw
repaint:
.pc = * "repaint"
{
			stx INFROM										// [4]		stash the index
			txa												// [2]
			clc												// [2]
			adc INSTART										// [4]		add the start column to get its column
			jsr move_to										// [6]		move the print position to it
			lda INFROM										// [4]		get the index
			clc												// [2]
			adc #<INBUF										// [2]		add it to the address of the line (INBUF is inside one page, so there is no carry)
			ldy #>INBUF										// [2]
			jsr L40_STROUT									// [6]		draw the rest of the line (up to its terminator)
			lda INLEN										// [4]		check for a full line: there is no cell after it
			cmp INCAP										// [4]
			bcs full										// [3/2]
			lda #' '										// [2]		blank the cell after the line (a deleted character leaves one behind)
			jsr L40_CHROUT									// [6]
full:		lda #$80										// [2]		draw the cursor
			jmp show_cell									// [3]		exit via show_cell
}


// Show the cursor, and start the time to the next blink from now
restart_blink:
.pc = * "restart_blink"
{
			lda JIFFYLO										// [3]		get the jiffy clock
			clc												// [2]
			adc #BLINK										// [2]		add the time to the next blink
			sta INFLIP										// [4]		set it
			lda INSHOWN										// [4]		check whether the cursor is on
			bmi exit										// [2/3]	done if it is
			lda #$80										// [2]		draw it reversed
			jmp show_cell									// [3]		exit via show_cell
exit:		rts												// [6]
}


// Draw the cursor's cell plain if it is reversed and reversed if it is plain, when the time has come
blink:
.pc = * "blink"
{
			lda JIFFYLO										// [3]		get the jiffy clock
			sec												// [2]
			sbc INFLIP										// [4]		subtract the time of the next blink (negative if it has not come: it can be up to 127 jiffies away)
			bmi exit										// [2/3]	wait if it has not
			lda JIFFYLO										// [3]		get the jiffy clock
			clc												// [2]
			adc #BLINK										// [2]		add the time to the next blink
			sta INFLIP										// [4]		set it
			lda INSHOWN										// [4]		get the style the cell is drawn in
			eor #$80										// [2]		flip it
			jmp show_cell									// [3]		exit via show_cell
exit:		rts												// [6]
}


// ------------------------------------------------ DATA ------------------------------------------------
// Every string ends with a $00 byte

INPUTTEXT:				// Heading, instructions and prompt string
.pc = * "INPUTTEXT"		// State, CLR, word wrap on, heading, instructions, a prompt of two characters, $00 terminator
.byte UPPER, RVS_OFF, BLUE, CLR, WRAP_ON			// word wrap is on when the line editor is called: it turns it off while editing and back on
.byte YELLOW
.text "LINE INPUT: AN EXAMPLE HOST ROUTINE"
.byte RETURN, RETURN
.byte WHITE
.text "TYPE A LINE. THE CURSOR KEYS MOVE IT,"
.byte RETURN
.text "DEL DELETES, INS OPENS A SPACE, RETURN"
.byte RETURN
.text "ENDS IT. THE LINE HOLDS 37 CHARACTERS."
.byte RETURN, RETURN
.byte GREEN
.text "> "
.byte 0

YOUTYPED:				// Label string for the line that was typed
.pc = * "YOUTYPED"		// RETURN, CYAN, text, RETURN, WHITE, $00 terminator
.byte RETURN, CYAN
.text "YOU TYPED:"
.byte RETURN, WHITE, 0

AGAIN:					// Prompt string for the end
.pc = * "AGAIN"			// RETURN x 2, text, $00 terminator
.byte RETURN, RETURN
.text "PRESS A KEY TO TRY AGAIN"
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
