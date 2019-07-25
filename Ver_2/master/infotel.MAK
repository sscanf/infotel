##
## sample make file (see demoguid.txt)
##

COMP = Y:\HIWARE\PROG\Chc05.exe
LINK = Y:\HIWARE\PROG\linker.exe
ASM =  Y:\HIWARE\PROG\AHC05.exe

makeall: 
	$(COMP) main.c
	$(ASM) infotel.asm lcd.asm memo.asm

	$(LINK) infotel.prm