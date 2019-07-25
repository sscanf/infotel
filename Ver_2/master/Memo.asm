;                                IDNT memoria

;                        BTEXT
;
;******************************************************************************
; DESCRIPCION  : Módulo para controlar la memoria externa X25128
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

SCDAT   equ 11h       ; Serial Comunications Data Register
SCCR1   equ 0eh       ; Serial Comunication Register 1
SCCR2   equ 0fh       ; Serial Comunication Register 2
SCSR    equ 10h       ; Serial comunication Status Register
TCR     equ 12h       ; Timer Control Register
TSR     equ 13h       ; Timer Status Register
SPCR    equ 0ah       ; spcr (serial peripheral control register)
SPSR    equ 0bh       ; Serial Peripheral Status Register
SPDR    equ 0ch       ; Serial Peripheral Data I/O Register
TCRH    equ 001ah     ;timer count register (high)
TCRL    equ 001bh     ;timer count register (low)
BAUD    equ 0000dh    ; Baud Rate Register

	include "memo_conf.inc"
;*********************************** CONSTANTES *****************************

; COMANDOS PARA LA EEPROM

WREN    equ 06h
WRDI    equ 04h
RDSR    equ 05h
WRSR    equ 01h
READ    equ 03h
WRITE   equ 02h


;*********************************** RAM ************************************
ram2	section

MemH    ds.b 1
MemL    ds.b 1
nBytes  ds.b 1
status  ds.b 1
BtsSent ds.b 1
temp_    ds.b 1

;************************************ ROM ***********************************

        xdef MemoIni
        xdef MemoWrtBuff
        xdef MemoRdBuff
        xdef MemoWREN
        xdef MemoWRDI
        xdef MemoWRITE
        xdef MemoEND
        xdef MemoSend
	xdef MemH
	xdef MemL
	xdef nBytes

	xref StackInit
        xref PSHA
        xref PULA
        xref PSHX
        xref PULX

text	section

MemoIni:
	jsr StackInit
        bset MEMO_CS,MEM_CTL1+4
;        bset MEMO_WP,MEM_CTL2+4
        bset MEMO_CS,MEM_CTL1
;        bset MEMO_WP,MEM_CTL2
        lda #32
        sta BtsSent
        rts

;*********************** OPERACIÓN DE ESCRITURA *******************************

        ; En MemH y MemL ha de estar la dirección de comienzo de memoria a
        ; escribir (16 bits).
        ; En X ha de estar la dirección del buffer de RAM, en el cual están
        ; los bytes a escribir.
        ; En nBytes está el número de bytes a escribir.
        ; El buffer ha de ser como máximo de 32 bytes.
        ; La rutina sale con carry si hay error.

MemoWrtBuff:

	lda #$53
	sta SPCR

        lda nBytes
        cmp #32
        bpl WrtError            ; Error, se intena escribir mas de 32 bytes

;**** Calculamos los bytes restantes para acabar la pagina

pgCalc:
        lda MemL                ;Si el byte bajo de la direccón de memoria
        cmp #32                 ;es menor de 32, no se realiza la formula
        blo ya
pglp:
        sub #32
        cmp #32                 ;Restamos del byte bajo 32
        bhi pglp                ;reiteramos hasta que sea menor de 32
ya:
        sta temp_
        lda #32
        sub temp_
        sta BtsSent             ;En BtsSent está el número de bytes restantes
        jsr PSHX
wtbuff:
        jsr GetStatus
        brset 0,status,wtbuff   ;Espera a que acabe de escribir
        jsr MemoWREN            ;Desprotegemos la memoria
wtbf:
        jsr GetStatus
        brclr 1,status,wtbuff   ;Espera a que acabe de escribir
        
        nop
        nop
        jsr MemoWRITE           ;Enviamos comando para escribir
        jsr PULX
buff:
        lda ,x                  ;Cogemos un byte del buffer
        incx
        jsr MemoSend            ;Lo enviamos a la memoria
        dec nBytes
        lda MemL
        add #1
        sta MemL
        clra
        adc MemH
        sta MemH
        lda nBytes
        beq FinWrt
        dec BtsSent
        lda BtsSent
        beq FinPage
        bra buff

FinPage:
        jsr FinWrt
        jmp pgCalc

FinWrt:
        jsr MemoEND
        nop
        nop
        jsr MemoWRDI    ;Protegemos la memoria
        clc
        rts

WrtError:
        sec
        rts

;*********************** OPERACIÓN DE LECTURA *******************************

        ; En MemH y MemL ha de estar la dirección de comienzo de memoria a
        ; leer (16 bits).
        ; En X ha de estar la dirección del buffer de RAM, en el cual se
        ; guardarán los bytes leidos de la memoria.
        ; En nBytes está el número de bytes a leer.

MemoRdBuff:
	
	lda #$53
	sta SPCR

        bclr MEMO_CS,MEM_CTL1
        lda #READ
        jsr SpiOut
        lda MemH                        ;Comienzo de memoria
        jsr SpiOut
        lda MemL
        jsr SpiOut
buc:
        jsr SpiIn
        sta ,x
        incx
        dec nBytes
        bne buc
        bset MEMO_CS,MEM_CTL1

        rts

GetStatus:

        bclr MEMO_CS,MEM_CTL1           ;Seleccionamos la memoria
        lda #RDSR
        jsr SpiOut
        jsr SpiIn
        sta status
        bset MEMO_CS,MEM_CTL1           ;Seleccionamos la memoria
        rts

;------------------------------------------------------------------------------

MemoWREN:
        bclr MEMO_CS,MEM_CTL1           ;Seleccionamos la memoria
;        bclr MEMO_WP,MEM_CTL2
        lda #WREN                       ;Permitimos la escritura
        jsr SpiOut
        bset MEMO_CS,MEM_CTL1
        rts

MemoWRITE:
        bclr MEMO_CS,MEM_CTL1           ; Seleccinamos la memoria
        lda #WRITE                      ;Instrucción para escribir
        jsr SpiOut
        lda MemH                        ;Comienzo de memoria
        jsr SpiOut
        lda MemL
        jsr SpiOut
        rts

MemoEND:
        bset MEMO_CS,MEM_CTL1           ; Deseleccionamos la memoria
;       jsr SpiOut
        rts

MemoSend:
        jsr SpiOut
        rts

MemoWRDI:
        bclr MEMO_CS,MEM_CTL1
        lda #WRDI               ;Protejemos la escritura
        jsr SpiOut
        bset MEMO_CS,MEM_CTL1
;        bset MEMO_WP,MEM_CTL2
        rts

;------------------------------------------------------------------------------

;----------- LEE UN BYTE DEL SPI Y LO PONE EN A ---------------------------
;------------------------------------------------------------------------------

SpiIn:
        lda SPSR
        clra                    ;TRANSMITE 00 PARA QUE GENERE EL CLOCK
        jsr SpiOut              ;Y ASI PERMITIR AL DEVICE QUE TRANSMITA EL BYTE.
        lda SPDR                ;LEE EL BYTE RECIBIDO.
        rts

;----------------- TRANSMITE AL SPI EL CONTENIDO DE A ---------------------

SpiOut:

        sta SPDR                ;Transmite el comando al 802
        brclr 7,SPSR,*          ;espera que transmita el byte
        rts


;---------------------------- inicialización spi -------------------------------
;***************************** IMPORTANTE *************************************
;                                                      __
;para que el micro acepte ser master se ha de poner el ss a positivo (pata 37),
;si no es asi el micro rechaza el bit 4 del SPCR (master),
;
;******************************************************************************

SpiIni:
        lda #$18
        sta PORTD+4
        lda #$53        ;Serial Peripheral Interrupt Disable
        sta SPCR        ;Serial Peripheral System Enable
                        ;Master mode
                        ;When /SS is low, first edge of SCK invokes first data
                        ;sample.
                        ;Internal Processor Clock Divided by 32
        rts

;--------------------------------------------------------------------------
