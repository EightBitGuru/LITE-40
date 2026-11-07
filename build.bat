@echo off
rem Build the LITE-40 package, one binary for each RAM block it can sit at the top of, and the two demo programs.
rem
rem Set KICKASS to the KickAss.jar path if it is not in the default place below.
rem
rem Outputs (artifacts\):  lite40_1.bin  the package for block 1, the 8K expander ($2000-$3FFF): it ends at $3FFF
rem                        lite40_2.bin  the same for block 2, the 16K expander ($4000-$5FFF): it ends at $5FFF
rem                        lite40_3.bin  the same for block 3, the 24K expander ($6000-$7FFF): it ends at $7FFF
rem                        lite40_5.bin  the same for block 5, RAM at $A000-$BFFF: it ends at $BFFF
rem                        lite40_output_demo.prg      the output demo program (lite40_output_demo.asm), which uses lite40_1.bin
rem                        lite40_input_demo.prg       the line input demo program (lite40_input_demo.asm), which uses lite40_1.bin
rem
rem Each binary is a single file with no load address (for .import binary) and is 3,402 bytes long (the 3,381-byte package and 21 spare
rem bytes): a host places it at the top of the block minus its size (see lite40_output_demo.asm).

setlocal
if "%KICKASS%"=="" set KICKASS=C:\6502\Tools\KickAssembler-5.25\KickAss.jar

if not exist artifacts mkdir artifacts
call :build 1 16384 || exit /b 1
call :build 2 24576 || exit /b 1
call :build 3 32768 || exit /b 1
call :build 5 49152 || exit /b 1

echo Output demo program
java -jar "%KICKASS%" lite40_output_demo.asm -o artifacts\lite40_output_demo.prg -odir "%CD%\artifacts" || exit /b 1
echo Input demo program
java -jar "%KICKASS%" lite40_input_demo.asm -o artifacts\lite40_input_demo.prg -odir "%CD%\artifacts" || exit /b 1
endlocal
exit /b 0

rem  call :build <block number> <top of the block in decimal>
:build
echo Package for block %1 (L40_TOP=%2)
java -jar "%KICKASS%" lite40.asm -binfile -o artifacts\lite40_%1.bin -odir artifacts :L40_TOP=%2 || exit /b 1
exit /b 0
