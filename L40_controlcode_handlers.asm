// LITE-40 control code output handlers
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace L40_controlcode_handlers

// Every handler below ends in RTS: the dispatcher calls it with a JSR and carries on into charout_tidyup, and
// cursor_right is also called directly by line_continuation. All of them must stay inside one page (checked at the end of this
// file): the dispatch table holds only their lo-bytes, and HANDLER_PAGE supplies the page hi-byte of every handler address.
HANDLER_PAGE:

// Handle control code $93 (CLR)
// The first call to the package must be CLR: it sets the VIC up if it is not already in 40-column mode.
clear_screen:
.pc = * "clear_screen"
{
			lda #1											// [2]		non-zero disables the stock cursor flash
			sta vic20.os_zpvars.CRSRMODE					// [3]		set cursor blink mode (done first: the mode switch below can take a frame)
			lda #$80										// [2]		b7 set locks the stock SHIFT/C= case toggle
			sta vic20.os_vars.SHFTMODE						// [4]		set shift mode lock
			lda #>vic20.colour_ram.COLOUR1					// [2]		colour RAM hi-byte
			sta vic20.os_zpvars.COLRPTRH					// [3]		set colour line pointer hi-byte
			lda #>L40_static_data.MATDATA					// [2]		get matrix row address table hi-byte
			sta L40_runtime_memory.MATROWH					// [3]		set matrix row pointer hi-byte

			jsr L40_runtime_setup.ensure_40col				// [6]		check for 40-column mode
			beq clear										// [2/3]	skip setup if already in 40-column mode
			jsr L40_runtime_setup.setup_display				// [6]		switch to 40-column mode
clear:		jsr L40_helper_routines.initialise_screen		// [6]		clear bitmap and colour RAM
			lda #0											// [2]		cursor_home requires .A to be zero
// Fall-through into cursor_home
}


// Handle control code $13 (HOME)
// => A		Must be zero
cursor_home:
.pc = * "cursor_home"
{
			sta vic20.os_zpvars.CRSRLPOS					// [3]		reset print column
			sta vic20.os_zpvars.CRSRROW						// [3]		reset print row
			beq reset_colour_pointer						// [3/3]	always taken: .A is zero
}


// Handle control code $0D (CARRIAGE RETURN)
// => A		Must be zero
// => Z		Must be set
carriage_return:
.pc = * "carriage_return"
{
			sta vic20.os_zpvars.RVSFLAG						// [3]		clear reverse flag
			sta vic20.os_zpvars.CRSRLPOS					// [3]		reset print column
			beq cursor_down									// [3/3]	always taken: .A is zero, move down a row
}


// Handle control code $9D (CURSOR LEFT)
// => A		Must be zero
cursor_left:
.pc = * "cursor_left"
{
			dec vic20.os_zpvars.CRSRLPOS					// [5]		decrement print column (0-39)
			bpl reset_colour_pointer						// [3/2]	exit via colour pointer reset if no underrun (column < 0)
			ldy vic20.os_zpvars.CRSRROW						// [3]		get print row (0-23)
			beq resetpos									// [2/3]	skip cursor-up if already on row 0
			ldy #L40_runtime_constants.SCREEN_COLUMNS		// [2]		last column on line
resetpos:	sty vic20.os_zpvars.CRSRLPOS					// [3]		reset print column
// Fall-through into cursor_up
}


// Handle control code $91 (CURSOR UP)
// => A		Must be zero
cursor_up:
.pc = * "cursor_up"
{
			dec vic20.os_zpvars.CRSRROW						// [5]		decrement print row
			bpl reset_colour_pointer						// [3/2]	exit via colour pointer reset if no underrun (row >= 0)
			sta vic20.os_zpvars.CRSRROW						// [3]		reset print row to zero
			bmi reset_colour_pointer						// [3/3]	always taken: N is still set by the DEC above
}


// Handle control code $1D (CURSOR RIGHT)
cursor_right:
.pc = * "cursor_right"
{
			sec												// [2]		set Carry for subtraction
			lda #[L40_runtime_constants.SCREEN_COLUMNS+1]	// [2]		one column beyond end of line
			isb vic20.os_zpvars.CRSRLPOS					// [5]		increment print column (ZP required)
			bne reset_colour_pointer						// [3/2]	exit via colour pointer reset if no overrun (column > 39)
			sta vic20.os_zpvars.CRSRLPOS					// [3]		reset print column to start of line
// Fall-through into cursor_down
}


// Handle control code $11 (CURSOR DOWN)
cursor_down:
.pc = * "cursor_down"
{
			sec												// [2]		set Carry for subtraction
			lda #[L40_runtime_constants.SCREEN_ROWS+1]		// [2]		one line beyond end of screen
			isb vic20.os_zpvars.CRSRROW						// [5]		increment print line in .A (ZP required)
			bne reset_colour_pointer						// [3/2]	exit via colour pointer reset if not beyond end of screen
			jsr L40_helper_routines.scroll_lines_up			// [6]		scroll all lines up when beyond last line
			lda #[L40_runtime_constants.SCREEN_ROWS-1]		// [2]		print row after scroll
			sta vic20.os_zpvars.CRSRROW						// [3]		set print row
// Fall-through into reset_colour_pointer
}


// Reset colour pointer for the print row
reset_colour_pointer:
.pc = * "reset_colour_pointer"
{
			lda vic20.os_zpvars.CRSRROW						// [3]		get print row
			lsr												// [2]		divide row by two for colour offset
			tax												// [2]		copy colour offset to .X
			lda L40_static_data.CROWOFFS,x					// [4]		get colour matrix row offset
			sta vic20.os_zpvars.COLRPTRL					// [3]		set colour line pointer lo-byte
			rts												// [6]
}


// Handle control code $01 (WORD WRAP ON): turn word wrap on, whatever state it is in
// The flag only affects the string entry point (print_string), which can see a whole word before it prints it; the character entry
// point prints each character as it arrives. $01 and $02 set the state rather than flipping it, so a program never needs to know it.
wrap_on:
.pc = * "wrap_on"
{
			lda #$80										// [2]		b7 set means word wrap is on
			sta L40_runtime_memory.WRAPFLAG					// [3]		set the word wrap flag ($00=off, $80=on)
			rts												// [6]
}


// Handle control code $02 (WORD WRAP OFF): turn word wrap off, whatever state it is in
// => A		Must be zero
wrap_off:
.pc = * "wrap_off"
{
			sta L40_runtime_memory.WRAPFLAG					// [3]		set the word wrap flag off ($00)
			rts												// [6]
}


// Handle colour control codes $05,$1C,$1E,$1F,$90,$9C,$9E,$9F (WHITE,RED,GREEN,BLUE,BLACK,PURPLE,YELLOW,CYAN)
// => X		Control code passed from the dispatcher
// The ROM routine SETCOLCD stores the colour in the stock CURRCOLR ($0286), which is why the package's current colour lives there
set_colour_byte:
.pc = * "set_colour_byte"
{
			lda vic20.os_zpvars.CRSRLPOS					// [3]		get print column
			lsr												// [2]		divide by 2 for colour matrix
			tay												// [2]		set index for colour byte update
			txa												// [2]		move control code in .X to .A
			jsr vic20.kernal.SETCOLCD						// [6]		set current colour and return screen colour code in .X
			txa												// [2]		move screen colour code to .A
			sta (vic20.os_zpvars.COLRPTRL),y				// [6]		set colour RAM byte
			rts												// [6]
}


// Handle control code $0E/$8E (SWITCH CASE)
// => X		Control code passed from the dispatcher
switch_case:
.pc = * "switch_case"
{
			lda vic20.basic.OROP+19,x						// [4]		get case value for switch ($00=upper-case, $08=lower-case)
			asl												// [2]		multiply it by 16: the lower-case entries of the glyph address table are 128 on, so the offset is $80
			asl												// [2]
			asl												// [2]
			asl												// [2]
			sta L40_runtime_memory.CASEFLAG					// [3]		set glyph case flag
			rts												// [6]
}


// Handle control codes $12/$92 (RVS ON/OFF)
// => X		Control code passed from the dispatcher
rvs_mode:
.pc = * "rvs_mode"
{
			txa												// [2]		move control code to .A
			eor #$92										// [2]		$12^$92=$80 (RVS ON), $92^$92=$00 (RVS OFF)
			sta vic20.os_zpvars.RVSFLAG						// [3]		set screen reverse flag
// Fall-through into inactive_code
}


// Handle every control code that does nothing ($00, $02-$04, $06-$0C, $0F, $10, $14-$1B, $80-$8D, $8F, $94-$9B)
inactive_code:
.pc = * "inactive_code"
{
			rts												// [6]
}

HANDLERS_END:

.errorif (HANDLER_PAGE >> 8) != ((HANDLERS_END - 1) >> 8), "All control code handlers must sit in one page"
