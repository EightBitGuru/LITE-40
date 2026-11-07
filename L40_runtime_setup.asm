// LITE-40 display setup
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace L40_runtime_setup

// Check whether the VIC is already set up for the 40x24 display
// <= Z		Set if the screen is already in 40-column mode
// <= A		VIC screen/character address register
ensure_40col:
.pc = * "ensure_40col"
{
			lda vic20.vic.VCSCRNAD							// [4]		get VIC screen and character generator address
			cmp L40_static_data.VICNTSC+5					// [4]		compare with the 40-column value
			rts												// [6]
}


// Switch the VIC to the 40x24 display
// The whole routine runs with interrupts masked: the PAL/NTSC raster test below is only reliable if nothing steals the
// couple of raster lines it is watching for, and a stock cursor blink must not touch the character matrix mid-switch.
// <= RVSFLAG, CASEFLAG, WRAPFLAG, CURRCOLR	Reset to reverse off, upper-case, word wrap off, blue
setup_display:
.pc = * "setup_display"
{
			php												// [3]		stash the caller's interrupt flag
			sei												// [2]		mask interrupts

			// initialise 40x24 screen character matrix
			ldy #240										// [2]		initialise table index
copychar:	lda L40_static_data.MATDATA-1,y					// [4]		get matrix character
			sta L40_runtime_memory.Character_Matrix-1,y		// [5]		store character in screen matrix
			dey												// [2]		decrement for next character
			bne copychar									// [3/2]	loop until all 240 characters copied

			// set the VIC screen geometry (the sound registers and $900F belong to the host)
			ldx #5											// [2]		set register index
vicloop:	lda L40_static_data.VICNTSC,x					// [4]		get VIC register value
			sta vic20.vic.VCSCRNX,x							// [5]		set VIC register
			dex												// [2]		decrement index
			bpl vicloop										// [3/2]	loop until done

			// check for PAL or NTSC, and alter VIC settings for PAL mode if required
			lda #1											// [2]		raster line #2 (register counts in twos)
wait2:		cmp vic20.vic.VCRASTER							// [4]		check for line
			bne wait2										// [3/2]	loop until we hit it
wait268:	lda vic20.vic.VCRASTER							// [4]		get current raster line
			beq defaults									// [3/2]	video mode is NTSC if we find line 0 before line 268
			cmp #134										// [2]		look for line 268 for PAL
			bne wait268										// [3/2]	loop until we find 0 or 268
			lda L40_static_data.VICPAL						// [4]		get PAL value
			sta vic20.vic.VCSCRNX							// [4]		set VIC register
			lda L40_static_data.VICPAL+1					// [4]		get PAL value
			sta vic20.vic.VCSCRNY							// [4]		set VIC register

			// set the default state
defaults:	lda #0											// [2]
			sta vic20.os_zpvars.RVSFLAG						// [3]		set reverse off
			sta L40_runtime_memory.CASEFLAG					// [3]		set glyph case flag ($00=upper-case, $80=lower-case)
			sta L40_runtime_memory.WRAPFLAG					// [3]		set word wrap off ($00=off, $80=on)
			lda #BLUE										// [2]
			sta vic20.os_vars.CURRCOLR						// [4]		set current text colour
			plp												// [4]		restore the caller's interrupt flag
			rts												// [6]
}
