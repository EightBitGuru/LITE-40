// LITE-40 string output
// Copyright (C) 2026 8BitGuru <the8bitguru@gmail.com>

.filenamespace L40_string_output

// A string is printed by sending each byte to character_output in turn. With word wrap on (control code $01 turns it on and $02 turns it off,
// and it stays as it is between calls) the next word is measured before it is printed, and if it is too long for what is left of
// the line it is moved to the start of the next line by a line break first. A word is the characters up to the next space or
// the next control code that moves the print position, and is measured at three places: at the start of the string (if word wrap
// is already on), after the code that turned word wrap on, and after every space and every code that moves the print position
// (RETURN, HOME, CLR and the cursor keys). The control codes that do not move it (colours, reverse, case) take no room and do
// not end a word. A word of 41 or more characters can never fit on a line, so it is left to run on. The line break is a RETURN
// that leaves reverse mode as it was, because a break the program did not ask for must not change what it prints next.
//
// A space that would be the first character of a line the text ran on to by itself (a word that ends in column 39 is followed by
// one) is left out, however many follow it. A space at the start of a line the program chose (the start of the string, or after
// RETURN, HOME, CLR or a cursor key) is sent, so an indent still works. WRAPLEAD tells the two apart: it is $80 at the start of
// the string and after a code that moves the print position, and a character or space that is sent clears it.
//
// There are four routines. print_string is the entry point. print_plain sends the bytes while word wrap is off, and print_wrapped
// while it is on. measure_word does the measuring, and falls into print_wrapped. Everything that can change the flag (a $01 or $02, or the
// first CLR, which sets it off) is followed by measure_word, which looks at the flag again and carries on in the loop that matches
// it, so the loop in use is always the one the flag asks for, whatever the flag held when the string started.

// Print a $00-terminated string of any length, wrapping the words that do not fit if word wrap is on
// => A		String address lo-byte
// => Y		String address hi-byte
// <= A, X, Y	Preserved (flags undefined)
print_string:
.pc = * "print_string"
{
			sta L40_runtime_memory.STRPTRL					// [3]		set string pointer lo-byte
			sty L40_runtime_memory.STRPTRH					// [3]		set string pointer hi-byte
			pha												// [3]		stash the caller's .A and .Y on the Stack (.X is never changed: character_output preserves it)
			tya												// [2]
			pha												// [3]
			ldy #0											// [2]		clear the string index (an offset within the current page)
			lda #$80										// [2]		the start of a string counts as the start of a line the program chose
			sta L40_runtime_memory.WRAPLEAD					// [3]
			bit L40_runtime_memory.WRAPFLAG					// [3]		get the word wrap flag (b7) into N
			bmi measure_word								// [2/3]	word wrap is on: measure the first word before printing it
// Fall-through into print_plain
}


// Send the bytes of the string while word wrap is off, and measure the next word when a $01 turns it on
// => Y		String index (an offset from the string pointer)
print_plain:
.pc = * "print_plain"
{
nextchar:	lda (L40_runtime_memory.STRPTRL),y				// [5]		get the next character
			cmp #2											// [2]		check for $00 (the terminator) or $01 (word wrap)
			bcc special										// [2/3]	handle $00 and $01
			jsr L40_character_output.character_output		// [6]		output it (.A, .X and .Y come back unchanged)
			iny												// [2]		step to the next character
			bne nextchar									// [3/2]	loop until the end of the page
			inc L40_runtime_memory.STRPTRH					// [5]		continue on the next page
			jmp nextchar									// [3]		loop for the next page (not a branch: the string may run up to the end of memory)

@done:		pla												// [4]		restore the caller's .Y and .A
			tay												// [2]
			pla												// [4]
			rts												// [6]

special:	lsr												// [2]		move b0 to Carry ($00 clears it, $01 sets it)
			bcc done										// [3/2]	exit at the $00 terminator (not printed: it is an ignored control code anyway)
			lda #1											// [2]		send the $01 that turns word wrap on
			jsr L40_character_output.character_output		// [6]		(.A, .X and .Y come back unchanged)
			iny												// [2]		step past it
			bne measure_word								// [3/2]	carry on in whichever loop the flag now says
			inc L40_runtime_memory.STRPTRH					// [5]		continue on the next page
// Fall-through into measure_word
}


// Measure the word that starts at the string index, and move to the next line if it will not fit in the rest of this one; if word wrap is off, carry on in print_plain instead
// => Y		String index of the first character to measure
// <= Y		Zero (the string pointer has moved on by the index, so it addresses the same character)
measure_word:
.pc = * "measure_word"
{
			bit L40_runtime_memory.WRAPFLAG					// [3]		get the word wrap flag (b7) into N
			bpl print_plain									// [2/3]	word wrap is off (a $02 turned it off, or the first CLR did): carry on in print_plain
			tya												// [2]		get the string index
			clc												// [2]
			adc L40_runtime_memory.STRPTRL					// [3]		add it to the string pointer lo-byte
			sta L40_runtime_memory.STRPTRL					// [3]
			bcc scan										// [3/2]	skip the hi-byte increment if there is no carry
			inc L40_runtime_memory.STRPTRH					// [5]		increment the string pointer hi-byte

			// each byte is looked at with its b7 ignored: $A0-$FF are the glyphs of $20-$7F, and $80-$9F the control codes of $00-$1F

			// the scan stops at the end of the word, or after 256 bytes, or as soon as the word is 41 characters long
scan:		ldy #0											// [2]		clear the string index
			sty L40_runtime_memory.WRAPCNT					// [3]		clear the word length
scanloop:	lda (L40_runtime_memory.STRPTRL),y				// [5]		get the next byte
			beq endword										// [2/3]	the terminator ends the word
			and #$7F										// [2]		ignore b7
			cmp #$21										// [2]		check for a printable character other than a space
			bcs countchar									// [3/2]	count it
			cmp #$20										// [2]		check for a space
			beq endword										// [2/3]	a space ends the word
			cmp #$0D										// [2]		check for RETURN
			beq endword										// [2/3]	RETURN ends the word
			cmp #$11										// [2]		check for cursor down
			beq endword										// [2/3]
			cmp #$13										// [2]		check for HOME
			beq endword										// [2/3]
			cmp #$1D										// [2]		check for cursor right (CLR, cursor up and cursor left are the same codes with b7 set)
			beq endword										// [2/3]
			cmp #$02										// [2]		check for word wrap off: the text after it is not wrapped, so it is not part of the word
			beq endword										// [2/3]
nextbyte:	iny												// [2]		step to the next byte
			bne scanloop									// [3/2]	loop until 256 bytes have been looked at
			beq endword										// [3/3]	always taken: .Y wrapped round to zero

countchar:	inc L40_runtime_memory.WRAPCNT					// [5]		count a character of the word
			lda L40_runtime_memory.WRAPCNT					// [3]
			cmp #41											// [2]		check for a word that is too long to fit on any line
			bcc nextbyte									// [3/2]	keep measuring if it is not
endword:	lda L40_runtime_memory.WRAPCNT					// [3]		get the word length
			cmp #41											// [2]		check for a word of 41 or more characters
			bcs fits										// [3/2]	it can never fit, so leave it where it is
			clc												// [2]
			adc vic20.os_zpvars.CRSRLPOS					// [3]		add the print column: this is the last column the word would reach, plus one
			cmp #41											// [2]		check for a word that would pass the end of the line (column 39)
			bcc fits										// [3/2]	it fits in what is left of the line
			lda vic20.os_zpvars.RVSFLAG						// [3]		get the reverse flag (RETURN would clear it)
			sta L40_runtime_memory.WRAPCNT					// [3]		keep it (the word length is no longer needed)
			lda #$0D										// [2]		send RETURN: column 0 of the next row (scrolls at the bottom)
			jsr L40_character_output.character_output		// [6]
			lda L40_runtime_memory.WRAPCNT					// [3]		get the reverse flag back
			sta vic20.os_zpvars.RVSFLAG						// [3]		set it, so that the line break does not end reverse mode
fits:		ldy #0											// [2]		clear the string index
// Fall-through into print_wrapped
}


// Send the bytes of the string while word wrap is on, measuring the next word after every space and every code that moves the print position
// => Y		String index (an offset from the string pointer)
print_wrapped:
.pc = * "print_wrapped"
{
wrapnext:	lda (L40_runtime_memory.STRPTRL),y				// [5]		get the next character
			cmp #3											// [2]		check for $00 (the terminator), $01 (word wrap on) or $02 (word wrap off)
			bcc special										// [2/3]	handle $00, $01 and $02
			cmp #$20										// [2]		check for a space
			beq space										// [2/3]
			cmp #$A0										// [2]		check for a shifted space
			beq space										// [2/3]
			jsr L40_character_output.character_output		// [6]		output it (.A, .X and .Y come back unchanged)
			and #$7F										// [2]		ignore b7
			cmp #$21										// [2]		check for a printable character
			bcs printed										// [3/2]
			cmp #$0D										// [2]		check for RETURN
			beq boundary									// [2/3]
			cmp #$11										// [2]		check for cursor down
			beq boundary									// [2/3]
			cmp #$13										// [2]		check for HOME
			beq boundary									// [2/3]
			cmp #$1D										// [2]		check for cursor right (and CLR, cursor up and cursor left with b7 set)
			bne advance										// [3/2]	carry on with the next character unless it moves the print position
boundary:	lda #$80										// [2]		the print position is now where the program put it
			sta L40_runtime_memory.WRAPLEAD					// [3]
			bne trigger										// [3]		always taken: measure the next word

space:		lda vic20.os_zpvars.CRSRLPOS					// [3]		get the print column
			bne sendspace									// [2/3]	not at the start of a line: send the space
			lda L40_runtime_memory.WRAPLEAD					// [3]		at the start of a line: check how it got there
			beq advance										// [2/3]	by wrapping on its own, after a character: leave the space out
sendspace:	lda (L40_runtime_memory.STRPTRL),y				// [5]		get the space again
			jsr L40_character_output.character_output		// [6]		output it
			asl L40_runtime_memory.WRAPLEAD					// [5]		a character has been sent: a later start of a line is a wrap
trigger:	iny												// [2]		step to the next character
			bne gomeasure									// [3/2]	measure the next word
			inc L40_runtime_memory.STRPTRH					// [5]		continue on the next page
gomeasure:	jmp measure_word								// [3]		measure the next word (a jump: measure_word is too far back for a branch)

printed:	asl L40_runtime_memory.WRAPLEAD					// [5]		a character has been sent: a later start of a line is a wrap
advance:	iny												// [2]		step to the next character
			bne wrapnext									// [3/2]	loop until the end of the page
			inc L40_runtime_memory.STRPTRH					// [5]		continue on the next page
			jmp wrapnext									// [3]		loop for the next page (not a branch: the string may run up to the end of memory)

special:	cmp #1											// [2]		check for the $00 terminator (Carry is set for $01 and $02)
			bcs setwrap										// [3/2]	handle the $01 and the $02
			jmp done										// [3]		exit at the $00 terminator (a jump: done is too far back for a branch)
setwrap:	jsr L40_character_output.character_output		// [6]		send the $01 or $02 that sets word wrap on or off (.A, .X and .Y come back unchanged)
			iny												// [2]		step past it
			bne gomeasure									// [3/2]	carry on in whichever loop the flag now says
			inc L40_runtime_memory.STRPTRH					// [5]		continue on the next page
			jmp measure_word								// [3]		carry on in whichever loop the flag now says (measure_word looks at it)
}
