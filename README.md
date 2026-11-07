# <div><div>LITE-40</div><div>Copyright © 2026 [8-Bit Guru](mailto:the8bitguru@gmail.com)</div></div>

LITE-40 is a 3.4 KB relocatable machine-code display package for the Commodore VIC-20 which draws a dense 40x24 text screen. Your program calls it instead of `CHROUT`:

    JSR L40_CHROUT       ; A = PETSCII character or control code
                        ; A, X, Y preserved; flags undefined

    JSR L40_STROUT       ; A = lo-byte, Y = hi-byte of the address of a $00-terminated string (any length)
                        ; A, X, Y preserved; flags undefined

It is derived from the [FAST-40](https://github.com/EightBitGuru/FAST-40) cartridge (v1.5) and keeps its renderer, its colour handling and its fast screen scroll, but removes everything that made FAST-40 a *screen editor*: there is no cartridge, no keyboard input, no cursor, no BASIC integration, no interrupt hooks and no insert/delete. What is left is a small, fast, write-only display routine that a game, a demo or a utility can include.

No video hardware modification is required. The package needs an NMOS 6502 and a VIC-20 with at least an 8K RAM expansion. It sits at the top of the RAM block you choose (`$3FFF` with an 8K expander, `$5FFF` with 16K, `$7FFF` with 24K, or `$BFFF` if you have RAM at `$A000`), so no memory is wasted above it; it does not use the 3K expansion at all.

It draws text about a fifth faster than the FAST-40 cartridge, and about as fast as the stock 22-column screen. See [LITE-40 and FAST-40](#lite-40-and-fast-40).

**NOTE:** the package expects to run on a real or emulated VIC-20 with an NMOS 6502 and makes use of several undocumented opcodes. It will not operate correctly on later 6502 variants (e.g. the CMOS 65C02) which disable or repurpose these opcodes.

## License

The FAST-40 project is hosted on [GitHub](https://github.com/EightBitGuru/FAST-40).

Creation of modified or derivative works using, in whole or in part, any sourcecode, assets, or binary artifact originating from this project is subject to the following:

* **Free for non-commercial use** (you must clearly include a credit link to this project within your project).

* **Commercial use is expressly forbidden** except by explicit consent from the copyright holder.

## Quickstart

The **artifacts** folder holds the package ready to use, one binary for each RAM block it can sit at the top of. Each is a single file (no load address) for `.import binary`, 3,402 bytes long (the 3,381-byte package and 21 spare bytes), and ends at the top of its block:

* **lite40_1.bin**   block 1, the 8K expander (`$2000-$3FFF`): the package occupies `$32B6-$3FFF`
* **lite40_2.bin**   block 2, the 16K expander (`$4000-$5FFF`): `$52B6-$5FFF`
* **lite40_3.bin**   block 3, the 24K expander (`$6000-$7FFF`): `$72B6-$7FFF`
* **lite40_5.bin**   block 5, RAM at `$A000-$BFFF`: `$B2B6-$BFFF`
* **lite40_output_demo.prg**   the output demo: shows how to print characters, control codes and strings. Built from **lite40_output_demo.asm** in the project folder (it uses `lite40_1.bin`)
* **lite40_input_demo.prg**   the input demo: reads a line from the keyboard with a line editor. Built from **lite40_input_demo.asm**, a separate program (it uses `lite40_1.bin` too)

There are two demo programs, and each is a complete program on its own. To see them run, start ***xvic*** with either one:

    xvic.exe -memory 8k artifacts\lite40_output_demo.prg
    xvic.exe -memory 8k artifacts\lite40_input_demo.prg

VICE autostarts the program. The **output demo** switches to the 40x24 display and shows single characters, control codes (colours, reverse, character sets, cursor movement) and strings, including a string with embedded colour codes. A key press then shows a long string that scrolls the screen, another shows word wrap (the same kind of paragraph with it on and then off), and one more starts it again. The **input demo** asks for a line, which you edit with the cursor keys, INS and DEL, and shows it back when you press RETURN (see [Line input](#line-input)); it respects whatever word wrap is in effect when it asks. On real hardware use `LOAD"*",8` and `RUN` (each program carries a one-line BASIC loader at `$1201`, where BASIC starts on a VIC-20 with an 8K or larger expansion). Each is a small file, about 5 KB and 4 KB: it carries the program and the package packed together, and when it starts it copies the package to the top of the 8K expander (`$2000-$3FFF`) and the program to `$2000`, so an unexpanded-plus-8K machine runs it.

Both demo sources are also the examples to copy from. Each is one self-contained file that includes the pre-assembled binary the recommended way: imported as one contiguous item, packed after the program in the file, and copied to the address it runs at when the program starts (the comments in the files explain it). `build.bat` builds the package binaries and both demos:

    build.bat

## Using the package from your own program

The first call must be CLR (`$93`). It is the setup call: it switches the VIC to the 40x24 display if it is not already there (PAL or NTSC is detected), disables the stock cursor, and clears the screen. Every other call just writes a character or a control code.

### Include it as a single binary file

    .const L40_FILE = "artifacts/lite40_1.bin"              // the binary for block 1, the 8K expander
    .var L40_TOP = $4000                                    // the top of that block: the package ends at $3FFF
    .var lite40 = LoadBinary(L40_FILE)                      // read the file to find its length
    .label L40_CHROUT = L40_TOP - 1192 - 6                  // the entry points are just below the glyph block, whichever block:
    .label L40_STROUT = L40_CHROUT + 3                      // L40_CHROUT prints one character, L40_STROUT a string

    .pc = L40_TOP - lite40.getSize() "LITE-40"
    .import binary L40_FILE

    .pc = $2000 "MYPROGRAM"
    start:      lda #$93                                    // CLR
                jsr L40_CHROUT
                lda #'H'
                jsr L40_CHROUT
                ...

The binary contains absolute addresses, so it must sit at exactly the address it was built for: the top of its block minus its length. For another block use its file and its top: `lite40_2.bin` with `$6000`, `lite40_3.bin` with `$8000` or `lite40_5.bin` with `$C000`. Your own program goes anywhere below the package that you have RAM for.

### Assemble it in from the sources

    .import source "lite40.asm"                               // the whole package (it defines L40_TOP, L40_CHROUT and L40_STROUT)

    .pc = $4000 "MYPROGRAM"
    ...

Assemble with `-libdir <project folder>` so the package finds its own files. The package ends at `L40_TOP`, which `lite40.asm` defines as `$4000`, the top of block 1; to use another block, add `:L40_TOP=<decimal address>` to the command line (`24576` for block 2, `32768` for block 3, `49152` for block 5) or switch on one of the commented-out `L40_TOP` lines in `lite40.asm`. `L40_TOP` is the only address in the sources; everything else is derived from it, and the assembler rejects any value that is not the top of block 1, 2, 3 or 5. `L40_TOP` is available to your program after the import. The two demos include the pre-assembled binary instead (below), the recommended way for a program that only needs to call the package.

### Including the binary

The binary holds absolute addresses, so it must run at the address it was built for: the top of its block minus its length. The recommended way to use it is to import it as one contiguous item, wherever it falls in your program file, and copy it to that address when the program starts. The file then carries only the program and the package, packed together. The alternative, importing it at its home address, makes the file hold every byte from the start of your program to the top of the block, with the gap between them as filler (about 7 KB more in the demos, and a file that does not fit on a smaller disk image). The demos do it the recommended way: their start-up routine copies the package up, then the program, and runs the program; `lite40_output_demo.asm` is the one to copy it from.

### Control codes

The package acts on these and ignores every other value in `$00-$1F` and `$80-$9F`. `$20-$7F` and `$A0-$FF` print as on the stock VIC-20.

| Code | Key | Effect |
|------|-----|--------|
| `$93` | CLR | Set up if needed, clear the screen, home the print position (also the first call) |
| `$01` | (none) | Turn word wrap on: see below |
| `$02` | (none) | Turn word wrap off |
| `$13` | HOME | Print position to column 0, row 0 |
| `$0D` | RETURN | Column 0 of the next row (scrolls at the bottom); reverse off |
| `$11` `$91` | CRSR down / up | Next row (scrolls at the bottom) / previous row (stops at row 0) |
| `$1D` `$9D` | CRSR right / left | Next column, wrapping to the next row / previous column, wrapping to the previous row |
| `$12` `$92` | RVS on / off | Reverse mode for later characters |
| `$0E` `$8E` | lower / upper case | Glyph set for later characters (text already on the screen is unchanged) |
| `$90 $05 $1C $9F $9C $1E $1F $9E` | colours | Black, white, red, cyan, purple, green, blue, yellow |

These are the standard VIC-20 PETSCII codes (the VIC-20 User's Guide, the Programmer's Reference Guide and the stock `CHROUT` use the same values), so there are no symbolic names. There is no cursor; the print position is where the next character goes.

### Printing a string

`L40_STROUT` takes the address of a `$00`-terminated string of any length, with the low byte in `.A` and the high byte in `.Y` (the same convention as BASIC's own string printer). It is the same as calling `L40_CHROUT` for each byte in turn, except for word wrap (below): control codes in the string are executed wherever they appear (there is no quote mode), so the string can set colours, move the print position and so on. `.A`, `.X` and `.Y` come back unchanged. The terminator is never printed; `$00` is an ignored control code anyway, so nothing is lost.

    message:    .encoding "petscii_upper"                   // PETSCII, not ASCII (the letters match, other characters may not)
                .byte $93                                   // CLR
                .text "HELLO, WORLD"
                .byte $0D                                   // RETURN
                .byte $1C                                   // red
                .text "IN RED"
                .byte 0                                     // end of string

    show:       lda #<message
                ldy #>message
                jsr L40_STROUT

The two entry points are consecutive `JMP`s just below the glyph data, `L40_CHROUT` (`L40_TOP - 1198`) and `L40_STROUT` (`L40_TOP - 1195`), so a program that links the pre-assembled binary needs only the top of the block to find both. As with `L40_CHROUT`, the first call must be a CLR.

### Word wrap

Control code `$01` turns word wrap on and `$02` turns it off. Each one sets the state and neither flips it, so a program never needs to know what the state was. Word wrap is off after the first CLR, and it stays as it is from one call to the next, across `L40_STROUT` calls and across later CLRs, so a program can turn it on once and leave it. With it on, `L40_STROUT` moves a word that will not fit in the rest of the line to the start of the next line:

    message:    .byte $93, $01                              // CLR, word wrap on
                .text "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG AND KEEPS RUNNING"
                .byte 0

The word is measured before it is printed, so this works only for strings sent with `L40_STROUT`: `L40_CHROUT` is given one character at a time and cannot know how long the word is going to be, so it always prints where the print position is. Sending `$01` or `$02` to `L40_CHROUT` still sets the flag, which the next string then uses.

* A word is the printable characters up to the next space or the next code that moves the print position (RETURN, HOME, CLR and the cursor keys). Only the printable characters count towards its length. The codes that move the print position are not counted: they only end the word, because what follows them is printed somewhere else. The other control codes (colours, reverse, case) take no room and do not end a word, so a colour change in the middle of a word does not split it.
* A word is measured at the start of a string (if word wrap is already on), right after the `$01` that turns it on, and after every space and every code that moves the print position. A word that is split between two strings is measured as two words.
* A word that has no room (its length plus the print column is more than 40) is moved by a line break, which is a RETURN that leaves reverse mode as it was; a RETURN from the program would turn it off.
* A `$02` inside a word ends it, as far as measuring goes: the text after it is not wrapped, so it is not part of the word.
* A word of 41 characters or more can never fit on a line, so it is left to run on and wraps at the edge like any other text.
* A word that fits exactly stays where it is.
* A space that would be the first character of a line the text ran on to by itself is left out, however many spaces there are. This is the space after a word that ends in the last column, or after a space that fell in the last column. A space at the start of a line the program chose is sent, so an indent still works: the first character of a string, and after RETURN, HOME, CLR and the cursor keys. A string does not know how the previous one ended, so a string that starts on a line the previous string ran on to sends its first space.
* A line break at the bottom of the screen scrolls it, like any other RETURN.

### Line input

The package only displays, so a program that needs the player to type a line (an adventure game, say) does the editing itself, using the package to draw and the stock KERNAL routines for the rest: `GETIN` (`$FFE4`) reads the keys, because the stock keyboard scan keeps running, and `PLOT` (`$FFF0`) finds where the print position is. The package keeps no copy of the text, so the program keeps the line in its own RAM and redraws what an edit changes. Its cursor is a reverse-video copy of the character under it, drawn with the reverse codes, and it moves the print position with the cursor codes.

**lite40_input_demo.asm** is a complete line editor written that way, as a reference for a host program: copy the routines from it into your program (it is a program of its own, `lite40_input_demo.prg`, so you can try it first). It uses only the package's public entry points and the control codes:

    lda #38                     // the most characters to accept
    jsr input_line              // edit a line at the print position until RETURN
                                // .A = the length; INBUF holds the line, followed by $00

It edits the line at the print position, so print a prompt first. Typing inserts at the cursor; cursor left and right move it; DEL deletes the character before it; INS opens a blank space at it; RETURN ends the line and moves down a row. The cursor blinks. After a key, only the part of the line that changed is redrawn, with one `L40_STROUT`.

* The line stays in columns 0-38, so it is at most 39 characters less the length of the prompt: printing in the last column moves the print position on to the next row (and scrolls the screen on the bottom row), so the cursor never goes there. When the line is full, the cursor is drawn over its last character.
* It respects the word wrap state it is called with: it reads the package's flag (`$E8`, bit 7 set for on), sends `$02` so that the redrawn text is never wrapped, and sends `$01` again before it returns if word wrap was on. It leaves reverse mode off.
* Colour applies to blocks of 2x2 characters: print the prompt in the colour you want for the line, and do not change colour while editing.
* The line is PETSCII. Shifted letters (`$C1-$DA`) print as upper-case letters in the lower-case character set, so fold the case before comparing words. Only space to Z and the shifted letters are accepted; the routine `accept` is the place to change that.

## LITE-40 and FAST-40

| | FAST-40 (the cartridge) | LITE-40 |
|---|---|---|
| What it is | An 8K cartridge that replaces the VIC-20's screen editor, giving BASIC, the keyboard and your programs a 40x24 screen | A small output-only package that your program calls (`JSR L40_CHROUT`, `JSR L40_STROUT`); BASIC and the stock screen editor are not involved |
| Where it lives | Cartridge ROM: it starts itself, and takes over the vectors and the interrupt | RAM, at the top of an 8K, 16K or 24K expansion block (or RAM at `$A000`): it installs and replaces nothing |
| Size | An 8K cartridge | 3.4 KB |
| Input | Keyboard, cursor, quote mode, insert and delete, line editing | None: it only displays (a line-input routine for programs that need one is included as an example) |
| Speed | The baseline | About a fifth faster per character, and about as fast as the stock 22-column screen; scrolling and the control codes are faster too; clearing the screen is faster than FAST-40's, though slower than the stock ROM's |
| Strings | One character at a time | Also prints a `$00`-terminated string of any length, with optional word wrap |
| Glyph data | The full table, with a copy of every glyph in reverse | Each distinct glyph stored once, and reverse mode inverts the glyphs as they are drawn: under a third of the space |
| The rest of the hardware | Sets up the machine, including memory, BASIC and JiffyDOS | Writes only the screen geometry registers: the sound registers, border and background colours, KERNAL vectors and interrupts are the program's |
| The same | The renderer (4-pixel-wide glyphs drawn in a 160x192 bitmap), the two character sets, colours in 2x2 blocks, PAL and NTSC detection, and the fast scroll | The same, taken from FAST-40 |

Two things are different under the bonnet. The two character sets are 256 glyphs between them but only 149 different patterns, so LITE-40 stores each pattern once and gives each set a small address table, instead of keeping a full table; and reverse mode has no glyphs of its own: with RVS on, each glyph byte is inverted as it is drawn. RETURN turns reverse off as it always has, and the line break that word wrap sends keeps it on.

## What it is, and is not

* The renderer, glyph set, colour handling (2x2 character blocks), PAL and NTSC support and the screen scroll are FAST-40's. Text from both character sets can be on the screen at the same time.
* **No input.** `CHRIN`, the keyboard decoder, the cursor and its blink, quote mode, insert/delete and line linking are gone. INS (`$94`) and DEL (`$14`) do nothing. A program that needs a line of input writes it itself: [Line input](#line-input) describes how, and the project has a working example.
* **No read-back.** The package keeps no copy of the text, so nothing can be read back from the screen.
* **Differences from the cartridge** that a program can see: cursor movement does not change the current colour (send a colour code); SHIFT-RETURN (`$8D`), `$08`/`$09` and the unassigned control codes are ignored (the cartridge printed some of them as glyphs); printing past the end of a row flows onto the next row without inserting a blank line; scrolling never waits on the keyboard.
* **The host owns the rest of the hardware.** The package writes only the screen geometry registers `$9000-$9005`. It never touches the sound registers `$900A-$900E` or `$900F` (border, background, inverse). It does not take over any KERNAL vector, interrupt or the stack beyond 5 bytes (8 for `L40_STROUT`).

## Programming caveats

* Use only the package for output once it is running. The stock `CHROUT`, the screen editor and the stock cursor all assume the 22-column screen and write over the 40-column bitmap.
* Do not use `$D9-$EA` or the shared locations `$C7`, `$D3`, `$D6`, `$D7`, `$F3` and `$F4`. `$EB-$F1` and the rest of zero page are yours. One of them you may read: the word wrap flag at `$E8` (bit 7 set for on), so that a routine can put word wrap back as it found it, as the line input demo does; change it only with the control codes `$01` and `$02`.
* The print position is the stock cursor position, so the stock `PLOT` routine (`$FFF0`) with Carry set returns it: `.X` = row (0-23), `.Y` = column (0-39). That is what BASIC's `POS`, `TAB` and `SPC` read. Calling `PLOT` with Carry clear to *set* the position is not supported: it changes the row and column but not the package's cached cell address and colour pointer, so use the cursor control codes instead.
* The stock IRQ keeps running (clock, keyboard scan) and is not touched. The first CLR on a screen that is not yet 40x24 briefly masks interrupts, for up to a frame, to detect PAL or NTSC reliably.
* Limitations in the VIC design mean there is no way to preserve the usual 1:1 relationship between individual text-mode characters and their respective colour attributes when in 40x24 mode. All text colours are supported but they operate on 2x2 blocks of characters; in other words, the colour resolution is half that of the text resolution and colour layout should therefore be planned accordingly to avoid attribute clash.
* The package does not set the border or background colour; set `$900F` yourself (before or after the first CLR).
* It reads two things from ROM: the colour code table (through the KERNAL routine `SETCOLCD`, `$E912`) and the two case values from BASIC ROM (`$D007` and `$D087`), which are the same in the stock and JiffyDOS ROMs.
* The screen is the whole of the onboard RAM (`$1000-$1FFF`, which holds the character matrix and the bitmap) and the colour matrix at `$9400-$94EF`; the package writes the VIC screen geometry registers (`$9000-$9005`) on the first CLR, and again by a CLR after anything changes `$9005`.

## Accidental breakage

If a program overwrites something the package depends on, a CLR repairs it: it rebuilds the pointers it keeps in zero page, re-checks the VIC (`$9005`) and sets the display up again if it has changed, and clears the bitmap and colour RAM. Reverse mode, the character set and the current colour are kept across a CLR unless the display had to be set up again, which resets them to reverse off, upper case, blue.

## Building

Tools: [KickAssembler 5.25](https://theweb.dk/KickAssembler/Main.html#frontpage) (needs Java), and [VICE 3.10](https://vice-emu.sourceforge.io/) to run the demos. The path to KickAssembler is at the top of `build.bat`.

    build.bat               builds artifacts\ (lite40_1.bin, lite40_2.bin, lite40_3.bin and lite40_5.bin, and the two demos, lite40_output_demo.prg and lite40_input_demo.prg)

## Release history

### Release 1.0 (6th November 2026)
* New display-only package derived from FAST-40 v1.5: 40x24 text output through a single `JSR`, with colour, reverse, case switching, cursor movement and fast scrolling
* Added `artifacts` with the package as four single binaries, one for each RAM block it can sit at the top of (`lite40_1.bin`, `lite40_2.bin`, `lite40_3.bin` and `lite40_5.bin`), and the output demo (`lite40_output_demo.prg`, built from `lite40_output_demo.asm`, which includes the binary as one contiguous item and copies it to the top of the block when it starts)
* Added a second entry point, `L40_STROUT`, which prints a `$00`-terminated string of any length
* Added word wrap: control code `$01` turns it on and `$02` turns it off (each sets the state, neither flips it), and with it on `L40_STROUT` moves a word that will not fit in the rest of the line to the start of the next one, and leaves out a space that would start a line the text ran on to by itself
* Added `lite40_input_demo.asm`, a reference line-input routine for a host program (typing, cursor left and right, insert, delete and a blinking cursor, built on `GETIN`, `PLOT` and the package's own entry points), and an input demo of its own (`lite40_input_demo.prg`) that uses it
* Refactored the package to end at the top of a RAM block, with the glyph data at the very top and the entry points just below it, so no memory is wasted above it; the block is chosen with `L40_TOP` (the 8K expander by default)
* Refactored reverse mode to invert the glyphs as they are drawn, so the reverse copies are no longer stored: the package shrank from 5.8 KB to 3.8 KB
* Refactored the glyph data to store each distinct glyph once (149 patterns for the 256 glyphs of the two character sets) with a glyph address table for each set: the glyph data shrank from 4096 to 1192 bytes at no cost in drawing speed (the case codes take 6 cycles longer); packing the two sets a nibble each was tried and was 12% slower
* Refactored the layout so that no byte is wasted: the tables are placed from the top down, in two groups of small tables either side of the two page-aligned tables, so that the page-aligned tables land on page boundaries, and the code starts at an unaligned address (`$32B6` in block 1), with the order of the code files chosen so that nothing is padded; the package is 3381 bytes in a 3402-byte image (21 spare), down from 3998 bytes in 4096
* Refactored `L40_SPACE` to be the exact room reserved in bytes rather than a multiple of 256: the build checks every placement rule and says which one a change breaks
* Refactored the print position, colour pointer, character scratch and reverse flag to use the stock KERNAL zero-page locations, so the stock `PLOT` routine (and BASIC's `POS`, `TAB` and `SPC`) can read the print position
* Tweaked the character output hot path: the caller's registers are saved in zero page instead of on the stack, control codes are dispatched with a JSR, and the cursor, quote-mode, insert and text-buffer work is gone (310 cycles per glyph against 376 in v1.5)
* Tweaked the display setup to mask interrupts during the PAL/NTSC test so a stock IRQ cannot make a PAL machine look like NTSC
* Removed the cartridge, memory test, BASIC and JiffyDOS setup, SYS interface, hi-res plot and character poke, keyboard decode and input, interrupt and BRK handlers, text buffer, insert/delete and line continuation

# Who is 8-Bit Guru?

8-Bit Guru (also: Eight-Bit Guru, 8BitGuru, 8BG) is the *nom de guerre* of Mark Johnson. I'm a professional coder from the UK who has been telling computers what to do since 1981. My day job is all about C# and Azure, whilst my hobby projects mostly involve writing 6502 assembly language for the VIC-20 (my first computer, back in '81).
