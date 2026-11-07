// LITE-40 character output
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace L40_character_output

// The routines in this file are laid out so that the hot path (a printable character) runs straight through
// character_output, and every short branch reaches its target:
//
//   actionit -> charout_tidyup -> dispatch -> lowcode -> highrange -> rvs_stub -> character_output -> line_continuation -> rvs_draw
//
// actionit must stay directly in front of charout_tidyup, because it falls into it.

// Call a control code handler, then fall into charout_tidyup
// => Y		CONCODEL index of the handler
// => X		Control code (the colour, case and RVS handlers read it)
actionit:
.pc = * "actionit"
{
			lda L40_static_data.CONCODEL,y					// [4]		get control code handler address lo-byte
			sta L40_runtime_memory.TEMPBL					// [3]		set dispatch address lo-byte
			lda #>L40_controlcode_handlers.HANDLER_PAGE		// [2]		get control code handler page hi-byte
			sta L40_runtime_memory.TEMPBH					// [3]		set dispatch address hi-byte
			lda #0											// [2]		zero .A for any handlers that need it
			jsr dispatch									// [6]		call the handler (every handler ends in RTS)
// Fall-through into charout_tidyup
}


// Finalise a control code or a row wrap: recompute the column mask and bitmap cell address for the print position
charout_tidyup:
.pc = * "charout_tidyup"
{
			lda vic20.os_zpvars.CRSRROW						// [3]		get print row
			lsr												// [2]		divide by two for character matrix row
			tay												// [2]		stash index into row offset table

			ldx vic20.os_zpvars.CRSRLPOS					// [3]		get print column
			lda L40_static_data.COLOFFS,x					// [4]		get column nybble mask
			sta L40_runtime_memory.COLMASK					// [3]		set column nybble mask

			txa												// [2]		get print column back
			lsr												// [2]		divide by two for character matrix column
			clc												// [2]		clear Carry for addition
			adc L40_static_data.CROWOFFS,y					// [4]		add character matrix offset
			tay												// [2]		set character matrix index

			lax L40_runtime_memory.Character_Matrix,y		// [4]		get matrix character into .A and .X
			lsr												// [2]		divide by 16 for table index
			lsr												// [2]
			lsr												// [2]
			lsr												// [2]

			tay												// [2]		set hi-byte table index
			lda L40_static_data.BITADDRH-1,y				// [4]		get bitmap address hi-byte
			sta L40_runtime_memory.CELLBITH					// [3]		set cell bitmap address hi-byte

			txa												// [2]		restore matrix character from .X
			and #%00001111									// [2]		mask low nybble for table index
			tax												// [2]		set bitmap lo-byte table index
			ldy vic20.os_zpvars.CRSRROW						// [3]		get print row
			lda L40_static_data.ROWOFFS,y					// [4]		get bitmap row offset for row
			clc												// [2]		clear Carry (lsr chain above may have set it)
			adc L40_static_data.BITADDRL,x					// [4]		add bitmap address lo-byte (carry always 0 after)
			sta L40_runtime_memory.CELLBITL					// [3]		set cell bitmap address lo-byte

			return_to_caller()
}


// Jump to the control code handler whose address is in TEMPBL/H (a JSR here makes the handler's RTS return to actionit)
dispatch:
.pc = * "dispatch"
{
			jmp (L40_runtime_memory.TEMPBL)					// [5]		jump to control code handler
}


// Look up a low-range control code ($00-$1F)
// => A		Control code
// => X		Control code
lowcode:
.pc = * "lowcode"
{
			tay												// [2]		set low-range control code lookup index
			lda L40_static_data.CODEIDXL,y					// [4]		get low-range control code handler index
			tay												// [2]		set control code handler address table index
			bpl actionit									// [3/3]	always taken: handler indexes are below $80
}


// Handle a character in the high range ($80-$FF): look up a control code, or convert to a screen code
// => A		Character
// => X		Character
highrange:
.pc = * "highrange"
{
			cmp #vic20.screencodes.INVSPACE					// [2]		check if high-range control code (char < $A0)
			bcc highcode									// [2/3]	look up the high-range control code ($80-$9F)
			cmp #%11000000									// [2]		check b7/b6
			bcs clearb7										// [3/2]	SHIFTed glyph if both set
			sbc #63											// [2]		CBMed glyph if only b6 (Carry is clear, so this subtracts 64)
clearb7:	and #%01111111									// [2]		clear b7 for appropriate glyph
			bne setrvs										// [3/3]	always taken: the glyph code is never zero

highcode:	and #$1F										// [2]		mask for 5-bit index ($80-$9F)
			tay												// [2]		set high-range control code handler lookup index
			lda L40_static_data.CODEIDXH,y					// [4]		get high-range control code handler index
			tay												// [2]		set control code handler address table index
			bpl actionit									// [3/3]	always taken: handler indexes are below $80
}


// Reverse mode: character_output's branch cannot reach rvs_draw directly (it sits after line_continuation)
rvs_stub:
			jmp rvs_draw									// [3]

// Output a character or control code to the 40x24 display (the package entry point, reached through L40_CHROUT)
// => A		PETSCII character or control code
// <= A, X, Y	Preserved (flags undefined)
character_output:
.pc = * "character_output"
{
			sta vic20.os_zpvars.CHARBYTE					// [3]		save output character
			stx L40_runtime_memory.SAVEX					// [3]		save .X and .Y
			sty L40_runtime_memory.SAVEY					// [3]
			tax												// [2]		copy character to .X (and set N)
			bmi highrange									// [2/3]	handle $80-$FF
			cmp #vic20.screencodes.SPACE					// [2]		check if low-range control code (char < $20)
			bcc lowcode										// [2/3]	handle $00-$1F
			and #%00111111									// [2]		clear b6 for screen code ($20-$7F)
@setrvs:

			// set colour, glyph data pointer and Carry (odd column)
			ora L40_runtime_memory.CASEFLAG					// [3]		add the character set offset (0, or 128 for the upper/lower-case set)
			tax												// [2]		set glyph address table index
			lda vic20.os_zpvars.CRSRLPOS					// [3]		get print column (0-39)
			lsr												// [2]		divide by two for matrix column (Carry = odd column)
			tay												// [2]		stash character matrix column in .Y
			lda vic20.os_vars.CURRCOLR						// [4]		get character colour
			sta (vic20.os_zpvars.COLRPTRL),y				// [6]		set colour RAM byte under print position

			lda L40_static_data.GLPHADDR.lo,x				// [4]		get character glyph data address lo-byte
			sta L40_runtime_memory.TEMPAL					// [3]		set ZP glyph pointer lo-byte
			lda L40_static_data.GLPHADDR.hi,x				// [4]		get character glyph data address hi-byte
			sta L40_runtime_memory.TEMPAH					// [3]		set ZP glyph pointer hi-byte
			ldy #7											// [2]		glyph bytes to process (zero-based)
			lda vic20.os_zpvars.RVSFLAG						// [3]		get reverse flag
			bne rvs_stub									// [2/3]	reverse mode: draw the glyph inverted
			lda L40_runtime_memory.COLMASK					// [3]		get column mask
			bmi evencol										// [2/3]	even column if b7 set

			// odd column: right nybble, then move to the next cell
oddmerge:	glyph_merge($0F, false)								// [198]	unrolled right-column glyph merge
			bcs oddnext										// [3/3]	always taken: Carry is still set by the LSR above (odd column)
evenmerge:

			// even column: the next position is the odd column of the same bitmap byte, so only the mask changes
evencol:	glyph_merge($F0, false)								// [198]	unrolled left-column glyph merge
@eventail:	inc vic20.os_zpvars.CRSRLPOS					// [5]		move print position to next column
			lda #%00001111									// [2]
			sta L40_runtime_memory.COLMASK					// [3]		set odd-column mask
			return_to_caller()

			// odd column: the next position is the even column of the next character cell (+192 bytes in the
			// bitmap), unless this was the last column on the row, which takes the row wrap path
@oddnext:	lda vic20.os_zpvars.CRSRLPOS					// [3]		get print column (0-39)
			cmp #L40_runtime_constants.SCREEN_COLUMNS		// [2]		check for last column (Carry clear if not)
			beq line_continuation							// [2/3]	last column: wrap to the next row
			inc vic20.os_zpvars.CRSRLPOS					// [5]		move print position to next column
			lda #%11110000									// [2]
			sta L40_runtime_memory.COLMASK					// [3]		set even-column mask
			lda L40_runtime_memory.CELLBITL					// [3]		get cell bitmap address lo-byte
			adc #[L40_runtime_constants.BITMAP_OFFSET+1]	// [2]		add 192 for next character cell (Carry is clear)
			sta L40_runtime_memory.CELLBITL					// [3]		set cell bitmap address lo-byte
			bcc oddexit										// [3/2]	skip hi-byte increment if no carry
			inc L40_runtime_memory.CELLBITH					// [5]		increment cell bitmap address hi-byte
oddexit:	return_to_caller()

			// A taken branch costs an extra cycle if it crosses a page, so the four hot-path branches that are taken for
			// most characters must not: bmi evencol (even columns), bcs oddnext (odd columns) and bcc oddexit (odd columns
			// that do not carry into the next bitmap page). The branch to line_continuation is taken once per row only.
			// The package starts at a fixed address, so character_output sits where the code in front of it puts it. If one of these
			// fires after a change to the code, put a .fill in front of this file's import in lite40.asm (the bytes in front of
			// character_output are never executed through, so padding is harmless, and it comes out of the package's spare room)
			// or change the order of the code files, until the build passes.
.errorif (oddmerge >> 8) != (evencol >> 8), "bmi evencol crosses a page: +1 cycle on every even-column character"
.errorif (evenmerge >> 8) != (oddnext >> 8), "bcs oddnext crosses a page: +1 cycle on every odd-column character"
.errorif ((oddexit - 2) >> 8) != (oddexit >> 8), "bcc oddexit crosses a page: +1 cycle on most odd-column characters"
}


// Wrap the print position to the start of the next row after a character in the last column
line_continuation:
.pc = * "line_continuation"
{
			jsr L40_controlcode_handlers.cursor_right		// [6]		move print position to column 0 of the next row (scrolls at the bottom)
			jmp charout_tidyup								// [3]		recompute the column mask and cell address
}


// Reverse mode: the same merge as in character_output, with each glyph byte inverted as it is read. The reverse copies of
// the glyphs are not stored, so this replaces them. Entered with .Y = 7 from character_output (through rvs_stub), and
// leaves through the same position update as the normal path.
// => X		Glyph index (unused here)
// => Y		7
rvs_draw:
.pc = * "rvs_draw"
{
			lda L40_runtime_memory.COLMASK					// [3]		get column mask
			bmi evenrvs										// [2/3]	even column if b7 set
			glyph_merge($0F, true)							// [214]	unrolled right-column inverted glyph merge
			jmp oddnext										// [3]		update the position (the normal odd-column exit)
evenrvs:	glyph_merge($F0, true)							// [214]	unrolled left-column inverted glyph merge
			jmp eventail									// [3]		update the position (the normal even-column exit)
}


// Restore the caller's registers and return
.macro return_to_caller()
{
			ldy L40_runtime_memory.SAVEY					// [3]		restore .Y and .X
			ldx L40_runtime_memory.SAVEX					// [3]
			lda vic20.os_zpvars.CHARBYTE					// [3]		restore .A
			rts												// [6]
}


// Left/right bitmap glyph merge routine macro (87 bytes, 198 cycles; inverted: 103 bytes, 214 cycles)
// => mask	Column nybble mask
// => inv	True to invert each glyph byte (reverse mode)
.macro glyph_merge(mask, inv)
{
	.for (var i = 0; i < 7; i++)							// 			unrolled loop
	{
			lda (L40_runtime_memory.TEMPAL),y				// [5]		get character glyph byte
		.if (inv)
		{
			eor #$FF										// [2]		invert it (reverse mode)
		}
			eor (L40_runtime_memory.CELLBITL),y				// [5]		XOR with bitmap byte
			and #mask										// [2]		apply column mask
			eor (L40_runtime_memory.CELLBITL),y				// [5]		merge glyph and bitmap
			sta (L40_runtime_memory.CELLBITL),y				// [6]		set merged bitmap byte
			dey												// [2]		decrement byte index
	}
			lda (L40_runtime_memory.TEMPAL),y				// [5]		get character glyph byte
		.if (inv)
		{
			eor #$FF										// [2]		invert it (reverse mode)
		}
			eor (L40_runtime_memory.CELLBITL),y				// [5]		XOR with bitmap byte
			and #mask										// [2]		apply column mask
			eor (L40_runtime_memory.CELLBITL),y				// [5]		merge glyph and bitmap
			sta (L40_runtime_memory.CELLBITL),y				// [6]		set merged bitmap byte
}
