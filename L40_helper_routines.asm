// LITE-40 helper routines (location-independent)
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace L40_helper_routines

// Clear the bitmap and fill colour RAM with the current text colour
// <= A		Current text colour
// The loop runs 240 times and a taken branch that crosses a page costs an extra cycle, so a CLR would be 239 cycles slower
// if the loop straddled a page boundary: the routine is pushed up to the next page if it would not fit in the rest of
// this one (INIT_SIZE is checked against the real size by the .errorif after the routine).
.var INIT_SIZE = 63
.if (((* & $FF) + INIT_SIZE) > $100)
{
	.align 256
}
initialise_screen:
.pc = * "initialise_screen"
{
			ldx vic20.os_vars.CURRCOLR						// [4]		get current text colour
			ldy #240										// [2]		bitmap index (240 * 16 = 3840)
@initloop:	lda #0											// [2]		initialise bitmap to zero
			sta L40_runtime_memory.Screen_Bitmap-1,y		// [5]		clear byte at offset on each page in bitmap
			sta L40_runtime_memory.Screen_Bitmap+239,y		// [5]		3x faster than a loop
			sta L40_runtime_memory.Screen_Bitmap+479,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+719,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+959,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+1199,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+1439,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+1679,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+1919,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+2159,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+2399,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+2639,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+2879,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+3119,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+3359,y		// [5]
			sta L40_runtime_memory.Screen_Bitmap+3599,y		// [5]
			txa												// [2]		get text colour from .X
			sta vic20.colour_ram.COLOUR1-1,y				// [5]		set byte at offset in colour matrix
			dey												// [2]		decrement index
			bne initloop									// [3/2]	loop for next location
@initend:	rts												// [6]
}
.errorif (initloop >> 8) != (initend >> 8), "The initialise_screen loop crosses a page: +239 cycles on every CLR"
.errorif (initend - initialise_screen) + 1 != INIT_SIZE, "INIT_SIZE does not match the size of initialise_screen"


// Scroll the screen up two text rows (one character matrix row) by rotating the character and colour matrices,
// then clear the freed bitmap strip. The print position is left for the caller to set.
// The loops in this routine run hundreds of times per scroll, and a taken branch that crosses a page costs an extra
// cycle, so the routine is pushed up to the next page boundary if it would not fit in the rest of the current page
// (SCROLL_SIZE is checked against the real size at the end of this file).
.var SCROLL_SIZE = 96
.if (((* & $FF) + SCROLL_SIZE) > $100)
{
	.align 256
}
scroll_lines_up:
.pc = * "scroll_lines_up"
{
			// stash matrix character pointer for top row
			lda L40_runtime_memory.Character_Matrix			// [4]		get first character from first matrix row
			and #$0F										// [2]		mask top nybble
			tay												// [2]		set matrix lookup row offset
			lda L40_static_data.CROWOFFS,y					// [4]		get matrix lookup row pointer lo-byte
			sta L40_runtime_memory.MATROWL					// [3]		set matrix row pointer lo-byte

			// shuffle character and colour matrices 'up' a row
			ldy #36											// [2]		set character matrix index
matrixup:	lda L40_runtime_memory.Character_Matrix-16,y	// [4]		get character matrix byte (1st)
			sta L40_runtime_memory.Character_Matrix-36,y	// [5]		set character one row back
			lda vic20.colour_ram.COLOUR1-16,y				// [5]		get byte at offset in colour matrix
			sta vic20.colour_ram.COLOUR1-36,y				// [5]		set byte at offset in colour matrix
			iny												// [2]		increment index
			lda L40_runtime_memory.Character_Matrix-16,y	// [4]		get character matrix byte (2nd)
			sta L40_runtime_memory.Character_Matrix-36,y	// [5]		set character one row back
			lda vic20.colour_ram.COLOUR1-16,y				// [5]		get byte at offset in colour matrix
			sta vic20.colour_ram.COLOUR1-36,y				// [5]		set byte at offset in colour matrix
			iny												// [2]		increment index
			bne matrixup									// [3/2]	loop until done

			// set bottom row bitmap pointer and clear for matrix character
			ldy #19											// [2]		set character matrix index
resetchars:	sty L40_runtime_memory.REGYSAVE					// [3]		stash character matrix index
			lax (L40_runtime_memory.MATROWL),y				// [5]		get matrix character
			sta L40_runtime_memory.Character_Matrix+220,y	// [5]		store in character matrix
			lda vic20.os_vars.CURRCOLR						// [4]		get current text colour
			sta vic20.colour_ram.COLOUR1+220,y				// [5]		set byte at offset in colour matrix
			txa												// [2]		get matrix character from X
			lsr												// [2]		shift hi-nybble down
			lsr												// [2]
			lsr												// [2]
			lsr												// [2]
			tay												// [2]		set hi-byte table index
			lda L40_static_data.BITADDRH-1,y				// [4]		get bitmap address hi-byte
			sta L40_runtime_memory.TEMPAH					// [3]		set bitmap draw address hi-byte
			txa												// [2]		get matrix character from X
			and #%00001111									// [2]		mask low nybble for table index
			tay												// [2]		set bitmap lo-byte table index
			lda L40_static_data.BITADDRL,y					// [4]		get bitmap address lo-byte
			sta L40_runtime_memory.TEMPAL					// [3]		set bitmap draw address lo-byte

			lda #0											// [2]
			ldy #15											// [2]		bitmap row index
zapbitmap:	sta (L40_runtime_memory.TEMPAL),y				// [6]		clear bitmap row byte
			dey												// [2]		decrement row index
			bpl zapbitmap									// [3/2]	loop until done

			ldy L40_runtime_memory.REGYSAVE					// [3]		get character matrix index
			dey												// [2]		decrement index
			bpl resetchars									// [3/2]	loop until done
			rts												// [6]
}

SCROLL_END:

.errorif (SCROLL_END - scroll_lines_up) > SCROLL_SIZE, "scroll_lines_up has outgrown SCROLL_SIZE: raise it"
.errorif (scroll_lines_up >> 8) != ((SCROLL_END - 1) >> 8), "scroll_lines_up must sit inside one page: its loops pay a cycle per page-crossing branch"
