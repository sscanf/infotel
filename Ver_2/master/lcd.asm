;                                IDNT lcd

;                        BTEXT
;
;******************************************************************************
; DESCRIPCION  : Módulo para controlar un display LCD de 2 líneas
; LENGUAJE     : ENSAMBLADOR PARA MC68HC705/C8
; EDITOR       :
; OBSERVACIONES:
;
;******************************************************************************

;                        ETEXT

; DEFINICION DE LOS PORTS
PORTA   equ 00h
PORTB   equ 01h
PORTC   equ 02h
PORTD   equ 03h

CTR_DISP equ 2      ;PUERTO DONDE ESTÁN CONECTADAS LAS LÍNEAS DE CONTROL
DAT_DISP equ 1      ;PUERTO DONDE ESTÁN CONECTADAS LAS LÍNEAS DE DATOS
E        equ 0      ;Bit del puerto donde está conectada la línea E
WR       equ 2      ;Bit del puerto donde está conectada la línea WR
RS       equ 1      ;Bit del puerto donde está conectada la línea RS

ram2	section

sava	  ds.b 01
condis    ds.b 01
datdis    ds.b 01
statcr    ds.b 01         ;// Estado cursor (on/off)
crdir     ds.b 01         ;// Direcci¢n cursor

	xdef IniDis
	xdef ClrDsp
	xdef wadc
	xdef wrdat
	xdef wrcon

text	section

;       inicializacion display
IniDis:

        lda #$3c
        sta condis
        jsr wrcon
        lda #$0c        ;//inicia con cursor off
        sta condis
        sta statcr
        jsr wrcon
        lda #$01
        sta condis
        jsr wrcon

ClrDsp:
        lda #$01        ;//clear display
        sta condis
        jsr wrcon
        RTS
cradd:
        clr DAT_DISP+4
        bset E,CTR_DISP
        bset WR,CTR_DISP
        bclr RS,CTR_DISP
        lda DAT_DISP
        and #$7f
        rts

wrcon:
	sta sava
        jsr busy
        bset E,CTR_DISP     ;sube e
        bclr WR,CTR_DISP    ;baja wr
        bclr RS,CTR_DISP    ;baja rs
        lda #$ff
        sta DAT_DISP+4
        lda sava
        sta DAT_DISP
        bclr E,CTR_DISP    ;ds.btablece rs
        bset WR,CTR_DISP    ;   ""      wr
        bset RS,CTR_DISP     ;   ""      e
        clr DAT_DISP
        rts

; Polsiciona el cursor donde indique condis

wadc:
        ora #$80
        sta condis
        jsr wrcon
        bclr 7,condis
        rts


busy:
        clra
        sta DAT_DISP+4
	clr DAT_DISP
        bclr RS,CTR_DISP
        bset WR,CTR_DISP
        bset E,CTR_DISP
	NOP
	NOP
	NOP
	NOP
busy1:
        brset 7,DAT_DISP,busy1
        rts


wrdat:
	sta sava
        jsr busy
        bset RS,CTR_DISP
        bclr WR,CTR_DISP
        bset E,CTR_DISP
        lda #$ff
        sta DAT_DISP+4
	lda sava
        sta DAT_DISP
        bclr E,CTR_DISP
        bset WR,CTR_DISP
        bclr RS,CTR_DISP
        clra
        sta DAT_DISP
        rts
