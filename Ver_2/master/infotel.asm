;******************************************************************************
;*
;* NOMBRE       : InfoTel.asm
;* DESCRIPCION  : AdaptaciÛn INFOTEL para 16 canales
;* LENGUAJE     :
;* FECHA	: 29/01/2003
;* OBSERVACIONES: Se ha cambiado la EEPROM por la memoria del terminal gestax 
;*		  (XICOR 16k x 8 Bit)
;*		  Las funciones para controlar la memoria se han obtenido de
;*		  las librerÌas del terminal gestax y se han adaptado.
;******************************************************************************
;
;
;
; Byte flags:
;
; bit 0 1- Descolgado / 0- Colgado
; bit 1 Overflow en TimerH TimerL
; bit 2 Overflow en Timer2H Timer2L
; bit 3 No ha de cambiar de digito cuando pase un tiempo sin pulsar (edici¢n)
; bit 4
; bit 5
; bit 6
; bit 7
;
; DEFINICION DE LOS PORTS

T_NUMERO        equ  40h
T_SIGUIENTE     equ  0c0h
T_POSICION      equ  80h

; COMANDOS PARA LA EEPROM

READ     equ 03h
EWEN     equ 02h
ERASE    equ 03h
ERAL     equ 02h
WRITE    equ 02h
WRAL     equ 02h
EWEDS    equ 02h

READ1    equ 00h
EWEN1    equ 60h
ERASE1   equ 80h
ERAL1    equ 40h
WRITE1   equ 80h
WRAL1    equ 20h
EWEDS1   equ 00h

BIT_START equ 01h

P_TELEF  equ 2	    ;PUERTO DONDE EST¡N LOS CONTROLES PARA EL TEL…FONO

VELOCIDAD equ 02

CUR_MOV   equ 0


TONOS    equ 3
COLGAR   equ 4
MARCAR   equ 4

;============================= SEGMENTO DE RAM ============================

top section

PORTA   ds.b	1
PORTB   ds.b	1
PORTC   ds.b	1
PORTD   ds.b	1
PCA     ds.b	1
PCB     ds.b	1
PCC     ds.b	1
N_USED1	ds.b	3
SPCR	ds.b	1
SPSR	ds.b	1
SPDR	ds.b	1
BAUD	ds.b	1
SCCR1	ds.b	1
SCCR2	ds.b	1
SCSR	ds.b	1
SCDAT	ds.b	1
TCR	ds.b	1
TSR	ds.b	1
ICRH	ds.b	1
ICRL	ds.b	1
OCRH	ds.b	1
OCRL	ds.b	1
TCRH	ds.b	1
TCRL	ds.b	1
ATRH	ds.b	1
ATRL	ds.b	1
EPR	ds.b	1
CRR	ds.b	1
CCR	ds.b	1
N_USED2 ds.b	1

ram2 section

;================================ RAM ========================================
sava      ds.b 1
savx      ds.b 1
string    ds.b 11
result    ds.b 6
resultRes ds.b 6
llev	  ds.b 1
CntByte   ds.b 1
mltndos   ds.b 5
mltdor    ds.b 1
PntResta  ds.b 1
adrs      ds.b 1

car       ds.b 1
AntCar    ds.b 1

temp      ds.b 1
temp2     ds.b 1
time      ds.b 1
cursor    ds.b 2
CntGuion  ds.b 1
flags     ds.b 1
PosNum    ds.b 1
posicion  ds.b 1
numero    ds.b 1
lopx      ds.b 1
lopa      ds.b 1
TimH      ds.b 1
TimL      ds.b 1
Tim2H     ds.b 1
Tim2L     ds.b 1
cont2     ds.b 1
ErrTel    ds.b 1
CntLlam   ds.b 1
CntNoNum  ds.b 1

;================================= MAIN =======================================
	xdef SPI
	xdef SCI
	xdef TIMER
	xdef IRQ
	xdef SWI
	xdef reset
	xdef getch
	xdef edicion
	xdef spiIN
	xdef llamar

	xref main

	include "memo.inc"
	include "lcd.inc"

text	section

reset:
        clr cursor
        clra
	sta flags
	jmp main

;---------------- Llama a un n£mero de telÇfono ------------------------------

llamar:
	cli
	tax
        lda #$3
        sta CntLlam
        sta CntNoNum

        txa
        inca
        sta posicion
        lda #'1'
        sta numero

        lda #15
	mul
llam:
        sta adrs
        jsr LeeNum      ;El n£mero est† en string
        jsr PantLlamando
        jsr ShowNum     ;Muestra el n£mero

        lda temp        ;Si temp regresa con un 00 quiere decir que
        bne llama

        dec CntNoNum
        lda CntNoNum
        bne SiFin

        lda #$ff
        sta ErrTel
        sec
	sei
        rts
        
SiFin:

        lda #$3
        sta ErrTel
        bra SiErr2

llama:
        lda #$2
        
        jsr wadc        ;Posiciona el cursor

	clra
	sta result
	sta result+1
	sta result+2
	sta result+3
	sta result+4
	lda posicion
	sta result+5
	jsr Bin2Asc

	lda string+8
        jsr wrdat
	lda string+9
        jsr wrdat

        lda #$7
        
        jsr wadc        ;Posiciona el cursor

        lda numero
        jsr wrdat

        lda #$0c        ;clear display        
        jsr wrcon

        jsr LeeNum	;El n˙mero est· en string
        jsr marca       ;llama por telf. a ese n˙mero.
        bcs error       ;Error, no ha podido llamar
        clra
	sta ErrTel
        clc
	sei
        rts

error:
        lda ErrTel
        ldx #$11
        mul
        tax

        clra
        
        jsr wadc        ;Posiciona el cursor

err:
        lda errores,x
        cmp #$0
        beq FinErr

        jsr wrdat
        incx
        bra err


FinErr:
        lda #$5f
FinEr:
        jsr buc
        deca
        bne FinEr

SiErr2:

        inc numero
        lda adrs
        add #$05
        sta adrs
        dec CntLlam      ;Contador de llamadas
        beq salt1
        jmp llam

salt1   clra
	sta ErrTel
	lda #$ff
        sec
	sei
        rts

;======================== EDICION NUMEROS TELêFONO ==========================
edicion:

	clr adrs
        clr MemH        ;Posici¢n 00 en la eeprom
	clr MemL
	lda #$1
        sta posicion
        lda #'1'
        sta numero
edi:
        jsr PantEdicion
        jsr LeeNum      ;Lee el n£mero y lo pone en string

        jsr ShowNum     ;Muestra el n£mero en el display

        lda #$0f        ;Muestra el cursor
        
        jsr wrcon

        lda temp
        add #$43
        sta cursor
        sub #$43
        sta PosNum
        bset 3,flags

edita:
        lda #$50
        sta TimL
        lda #$1
        sta TimH
        bclr 1,flags

edita1:
        lda #$0a
        sta Tim2L
        lda #$1
        sta Tim2H
        bclr 2,flags

edita2:
        brset 1,flags,FinEdicion        ;Pasa un tiempo sin pulsar
        brset 2,flags,jEsSiguiente

        lda cursor
        
        jsr wadc        ;Posiciona el cursor

        jsr getch       ;Espera una pulsaci¢n del teclado
        lda car
        cmp #T_NUMERO
        beq PulsanNumero
        cmp #T_SIGUIENTE
        beq PulsanClr

        cmp #T_POSICION
        beq jPulsanPosicion
        bra edita2

jEsSiguiente:
        jmp EsSiguiente

jPulsanPosicion:
        jmp PulsanPosicion
                  
FinEdicion:

        jsr GuardaNumero
        rts

PulsanNumero:

        bclr 3,flags
        ldx PosNum
        cpx #$0a
        bpl edita

        lda string,x
        cmp #' '
        beq EsGuion
        inca
        cmp #$3a
        bne NoA

        lda #' '
NoA     sta string,x

        jsr ShowNum
        bra edita

EsGuion:
        lda #'0'
        sta string,x
        jsr ShowNum
        bra edita


PulsanClr:

        bset 3,flags
        lda PosNum
        beq edita

        ldx PosNum
        lda string,x
        cmp #' '
        beq opc1
        cmp #$5d
        beq opc1

        lda #' '
        ldx PosNum
        sta string,x
        jsr wrdat
        jmp edita
        
opc1:
        dec PosNum
        dec cursor

        lda cursor
        
        jsr wadc        ;Posiciona el cursor

        lda #' '
        ldx PosNum
        sta string,x
        jsr wrdat

        lda cursor
        
        jsr wadc
jedita  jmp edita
jedita1 jmp edita1

EsSiguiente:

        brset 3,flags,jedita1

        lda cursor
        cmp #$4d
        bpl jedita

        bset 3,flags
        inc PosNum
        inc cursor
        lda cursor
        jmp edita


PulsanPosicion:

        jsr GuardaNumero

        inc numero
        lda numero
        cmp #'4'
        bne FinPos

        lda #'1'
        sta numero
        inc posicion
        lda posicion
        cmp #17
        bne FinPos
        jmp edicion

FinPos:
        lda adrs
        add #$5
        sta adrs
        jmp edi


;=========================== MODULOS PARA EL TELEFONO ========================

marca:
        bclr COLGAR,P_TELEF      ;descuelga
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul

        lda #$05
        sta TimL
        lda #$01
        sta TimH
        bclr 1,flags

marca1:
        brclr TONOS,P_TELEF,tono  ;mira el tono de linea antes de marcar
        brclr 1,flags,marca1   
mar0:
        bset COLGAR,P_TELEF      ;cuelga
        clr ErrTel
        sec
        rts
;
tono:
        lda #$05
        sta TimL
        lda #$01
        sta TimH
        bclr 1,flags
tono1:
        brset TONOS,P_TELEF,mar0                ;No hay tono, error.
        brclr 1,flags,tono1
marca2:
        clrx                    ;Indice para que coja el num. de telÈfono
marca3:
        lda string,x            ;ahora llamara al otro
        cmp #' '                ;Los espacios en blanco los ignora
        beq ignora

        sub #'0'
        beq deu
        sta temp
marca5:
        bset MARCAR,P_TELEF
        jsr bul                 ;bucle  para el pulso a 1 60 Ms
        bclr MARCAR,P_TELEF
        jsr buc                 ;  "     "    "   "   " 0 30 Ms
        dec temp
        bne marca5

        jsr bul
        jsr bul                 ;bucle mas largo entre digitos
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
        jsr bul
ignora:
        incx
        cpx #$0a
        beq fi
        bra marca3
;
deu:
        lda #$0a
        sta temp
        bra marca5

fi:
        brset TONOS,P_TELEF,fi  ;Espera que baje la linea

fi0:
        bclr 4,flags
        lda #$20
        sta TimL
        lda #$1
        sta TimH
        bclr 1,flags
fi1:
        brclr TONOS,P_TELEF,mirton ;va amirar si hay pi-pi-pi-
fi4:
        brclr 1,flags,fi1
        brset 4,flags,FiEr
        clc
        rts
FiEr:
        lda #$1
        sta ErrTel
        bset COLGAR,P_TELEF       ;cuelga
        sec
        rts


fi14:
        bset 4,flags
        bra fi4

mirton:
        lda #$55
        sta cont2
        clra
mir:
        BRSET TONOS,P_TELEF,fi4;mira si hay senal de pi-pi-pi
        deca                   ;es el time out, para saber si el tono es corto
        bne mir
        dec cont2
        bne mir

        lda #$70               ;bucle de 65 Ms.
        sta cont2
        clra
mir1:
        BRSET TONOS,P_TELEF,fi14 ;mira si hay senal de pi-pi-pi
        deca                    ;es el time out, para saber si el tono es corto
        bne mir1
        dec cont2
        bne mir1                ;si termina el bucle es que es un tono largo
mir3:
        brclr TONOS,P_TELEF,mir3      ;espera que se termine el tono
        bra fi0

mir2:
        bset COLGAR,P_TELEF       ;cuelga
        lda #$02
        sta ErrTel
        sec
        rts

;========================= MODULOS PARA EL DISPLAY ==========================

GuardaNumero:
        jsr comprime    ;Convierte el n£mero a BCD

	lda adrs
        sta sava

	clr MemH
	sta MemL
	lda #$5
	sta nBytes
	ldx #result
	jsr MemoWrtBuff

        lda sava
        sta adrs
        rts


comprime:
        clra
	sta temp
        sta temp2
comp:
        ldx temp
        lda string,x
        cmp #' '
        bne No2d

        lda #$0f
        bra No2

No2d    sub #'0'
No2     sta sava

        incx
        inc temp
        lda string,x
        cmp #' '
        bne No2d2

        lda #$0f
        bra No21


No2d2   sub #'0'
No21    clc
        rola
        rola
        rola
        rola
        ora sava

        ldx temp2
        sta result,x

        inc temp
        inc temp2
        lda temp2
        cmp #$5
        bne comp
        rts


LeeNum:
	sei
        lda adrs
        sta sava

	clr MemH
	sta MemL
	lda #$5
	sta nBytes
	ldx #result
	jsr MemoRdBuff
        lda sava
        sta adrs

        clra
	sta temp
        clra
	sta temp2
descom:
        ldx temp
        lda result,x

        and #$0f
        cmp #$0a
        bmi nof
        bra sif

nof     add #'0'
        ldx temp2
        sta string,x
        inc temp2

sif     ldx temp
        lda result,x
        and #$f0
        rora
        rora
        rora
        rora

        cmp #$0a
        bmi nof1
        bra sif1

nof1    add #'0'
        ldx temp2
        sta string,x
        inc temp2
sif1    inc temp
        lda temp
        cmp #$05
        bne descom

        ldx temp2
fill:
        cpx #$0a
        beq FinFill

        lda #$20
        sta string,x
        incx
        bra fill

FinFill:
	cli
        rts

ShowNum:
        lda #$42
        
        jsr wadc

        lda #$5b
        jsr wrdat

        clrx
        clra
	sta temp
OutNum:
        lda string,x
        cmp #$20
        beq es20
        inc temp
es20:
        jsr wrdat
        incx
        cpx #$0a
        bne OutNum

        lda #$4d
        
        jsr wadc

        lda #$5d
        jsr wrdat

        rts




MuestraGuion:

        brset CUR_MOV,flags,No8  ;Si est† a 1 no refds.bca el guion

        dec CntGuion
        bne No8

        lda #VELOCIDAD
        sta CntGuion

        lda cursor+1

        
        jsr wadc        ;Posiciona el cursor para ' '

        lda #' '
        jsr wrdat

        lda cursor
        
        jsr wadc        ;Posiciona el cursor para ' '

        lda #' '
        jsr wrdat

        lda cursor
        sta cursor+1

        inc cursor
        lda cursor
        cmp #$8
        bne No8
        clra
	sta cursor
No8:
        rts


PantEdicion:

        lda #$01        ;//clear display
        
        jsr wrcon

        lda #$0
        
        jsr wadc        ;//Posiciona el cursor
        clrx
PantEd:
        lda edic,x
        
        jsr wrdat
        incx
        cpx #$10
        bne PantEd

        lda #$2
        
        jsr wadc        ;//Posiciona el cursor

	clra
	sta result
	sta result+1
	sta result+2
	sta result+3
	sta result+4
	lda posicion
	sta result+5
	jsr Bin2Asc

	lda string+8
        
        jsr wrdat
	lda string+9
        
        jsr wrdat

        lda #$7
        
        jsr wadc

        lda numero
        
        jsr wrdat
        rts


PantLlamando:

        lda #$01        ;//clear display
        
        jsr wrcon

        lda #$0
        
        jsr wadc        ;//Posiciona el cursor
        clrx
Pantll:
        lda llamando,x
        
        jsr wrdat
        incx
        cpx #$f
        bne Pantll
        rts

;======================= MODULOS PARA EL TECLADO =============================


;---------------------------------- GETCH --------------------------------------
;Obtiene una tecla del teclado, el teclado se compone de todos los pulsadods.b
;del panel frontal.
;Mientras se hacen pulsaciones cortas en cualquier tecla, la rutina GETCH,
;devuelve el byte 'car' el caracter pulsado, si no se pulsa ninguna tecla
;devuelve un 00.
;
;Si el caracter se mantiene pulsado, hace un bucle hasta que se suelta
;la tecla, si no se suelta ira haciendo bucles mas cortos.
;entre bucle y bucle va devolviendo la tecla pulsada.
;
;Para saber si la pulsaciÛn de la tecla es la primera, hace una comparaciÛn
;del byte 'car' con el byte 'AntCar', el byte AntCar contiene la £ltima tecla
;pulsada.
;Si son diferentes, no har† ning£n bucle, pero si son iguales hara el bucle.
;una vez acabado el bucle, cambia el byte time, que inicialmente esta cargado
;con #$f0, a #$30, para que el pr¢ximo bucle sea m†s corto, ya que el byte
;time indica la duraci¢n del bucle.
;
;El conmutador es independiente del teclado, en la variable 'AntConmut', se guar
;la posici¢n del conmutador, mientras sea igual la rutina getch lo ignora hasta
;que haya alg£n cambio en el conmutador.
;
getch:
        jsr MiraTeclas
        beq FinGetc3            ;// Si no es as°, regds.ba con un 00.

        sta car
        jsr AntiReb             ;// Bucle antirrebotes
        jsr MiraTeclas
        cmp car                 ;// Mira si la tecla pulsada es la misma que
        bne FinGetc3            ;// antes. Si no es as°, regds.ba con un 00.

        cmp AntCar              ;// Mira si la tecla de antes a£n sigue pulsada.
        bne FinGetc2            ;// si no es as°, regds.ba con la tecla recien
                                ;// pulsada.
GetBu:
        ldx time                ;// Inicia el bucle con la duraciÛn indicada
                                ;// en time.
GetBuc:
        jsr AntiReb             ;// Bucle antirrebotes
        jsr MiraTeclas
        cmp car                 ;// Mira si a£n sigue la tecla pulsada.
        bne FinGetc3            ;// Han soltado la tecla, regds.ba con un 00.
        decx
        cpx #$00                ;// Fin bucle?
        bne GetBuc              ;// No, continua ...

        lda #$40                ;// Como ya ha hecho un bucle largo, los (80)
        sta time                ;// siguientes han de ser cortos.

FinGetc2:
        lda car                 ;// Memoriza LA TECLA RECIEN PULSADA.
        sta AntCar
        RTS

FinGetc3:
        lda #$80                ;// El siguiente bucle tendra que ser largo.
        sta time
        clra
	sta car                 ;// Regds.ba con un 00.
        clra
	sta AntCar              ;// Borra la tecla memorizada.
        RTS



MiraTeclas:

        lda PORTD               ;// Mira si la tecla est· realmente pulsada.
        and #$80
        sta temp

        lda PORTC
        and #$40
        ora temp
        coma
        and #$c0
        rts
;//--------------------------------------------------------------------------


AntiReb:
        sta sava
        stx savx
        lda #$05
anti2:
        ldx #$f0
anti3:
        decx
        bne anti3
        deca
        bne anti2
        ldx savx
        lda sava
        rts

wait:
        ldx #$03
wai:
        decx
        bne wai
        rts

AntiRe2:
        stx savx
        ldx #$5
AntiRe3:
        decx
        cpx #$00
        bne AntiRe3
        ldx savx
        rts

buc:
        stx savx     ;BUCLE CORTO DEL TIEMPO DE ENTRE PULSOS DE UN DIGITO
        sta sava

        lda #$ff
buc2:
        ldx #$2a
buc1:
        decx
        bne buc1
        deca
        bne buc2

        ldx savx
        lda sava
        RTS
bul:
                   ;BUCLE MAS LARGO DE ENTRE PULSOS A UNO DEL MARCADO
        JSR buc
        JSR buc
        RTS


;//-------------- Convierte un n£mero binario a ascii decimal -----------------
;// Convierte un n£mero binario a una cadena de car†cteres ascii
;// El n£mero ha de estar en result
;// La cadena la pone en string


Bin2Asc:
        clr sava
        clr savx
        clr PntResta
BucHex
        jsr resta
        bcs HayCarry

        lda resultRes
        sta result
        lda resultRes+1
        sta result+1
        lda resultRes+2
        sta result+2
        lda resultRes+3
        sta result+3
        lda resultRes+4
        sta result+4
        lda resultRes+5
        sta result+5
        inc sava

BucH:
        lda PntResta
        cmp #$32
        bne BucHex
        rts


HayCarry:

        ldx savx
        lda sava
        add #'0'
        sta string,x
        inc savx
        clr sava
        lda PntResta
        add #$5
        sta PntResta
        bra BucH
;----------------------------------- RESTA -----------------------------------
resta:

	clr car
        lda #$5
        sta CntByte
        lda PntResta
        add #$4
        sta PntResta
        tax

restB:
        ldx PntResta
        dec PntResta
        lda const,x
        add car
        sta temp
        clr car


        ldx CntByte
        lda result,x
        sub temp
        bcc NoCarry

        inc car

NoCarry:
        ldx CntByte
        sta resultRes,x
        dec CntByte
        lda CntByte
        bne restB
        inc PntResta
        clc
        lda car
        beq FinRes
        sec
FinRes:
        rts

;------------------------------------------ multi-------------------------------
; MULTIPLICA UN NUMERO INDETERMINADO DE BYTES POR 1 BYTE
; EL NUMERO A MULTIPLICAR HA DE VENIR EN EL BUFFER MLTNDOS
; EL MULTIPLICADOR HA DE VENIR EN MLTDOR
; EN CntByte HA DE ESTAR EL NUMERO DE BYTES TOTAL A MULTIPLICAR
; EL resultADO QUEDA EN EL BUFFER result.
;
; EJEMPLO:
;               3D0900h x 22h = 81B3200
;
; EN MLTNDOS PONEMOS EL NUMERO A MULTIPLICAR DE LA SIGUIENTE FORMA:
;
;  BYTES      0    1    2
;            3D    09  00
;
; EN MLTDOR PONEMOS EL MULTIPLICADOR QUE ES UN 22.
;
; EN NUMBYTE PONEMOS UN 2 QUE ES EL NUMERO TOTAL DE BYTES (CONTANDO EL 0)

; EL resultADO QUEDA EN result DE LA SIGUIENTE FORMA:
;
; BYTES      0     1    2    3
;            08   1B   32    00
;

multi:
        clr car
        clr llev
        clrx
mult:
        ldx CntByte

        lda mltndos,x
        ldx mltdor

        clc
        fcb 42h         ;mul
        add car
        add llev

        clr car
        bcc noc
        inc car
noc:
        stx llev

        ldx CntByte
        incx
        sta result,x
        dec CntByte
        lda CntByte
        cmp #$ff
        bne mult

        lda llev
        add car
        sta result
        rts


;====================== MODULOS CONFIGUACION CPU =============================

pretim:

        lda #$ff
        sta TCRH
        lda #$0f
        sta TCRL
        rts

;----------- LEE UN BITE DEL SPI Y LO PONE EN A ---------------------------

spiIN:
        CLRA                    ;TRANSMITE 00 PARA QUE GENERE EL CLOCK
	sta SPDR
        brclr 7,SPSR,*
        LDA SPDR                ;LEE EL BYTE RECIBIDO.
        RTS

;----------------- TRANSMITE AL SPI EL CONTENIDO DE A ---------------------


;---------------------------- inicializaciÛn spi -------------------------------
;***************************** importante *************************************
;                                                      __
;para que el micro acepte ser master se ha de poner el ss a positivo (pata 37),
;si no es asi el micro rechaza el bit 4 del spcr (master),
;
;******************************************************************************

inispi:
        lda #$53        ;//Serial Peripheral Interrupt Disable
        sta SPCR        ;//Serial Peripheral System Enable
                        ;//Master mode
                        ;//SCK line idles in low state
                        ;//     __
                        ;//When SS is low, first edge of SCK invokes first data
                        ;//sample.
                        ;//Internal Processor Clock Divided by 32
        rts

;--------------------------------------------------------------------------

;================================= R O M  D A T A ============================

llamando:
        dc.b 'R    N   Llamand'
edic:
        dc.b 'R    N   Edicion'

reproduc:
        dc.b 'REPROD. MENSAJE '


errores:
        dc.b 'ERROR: SIN TONO ',0
        dc.b 'ERROR: SIN RESP.',0
        dc.b 'ERROR:LINEA DEF.',0
        dc.b 'ERROR:SIN NUMERO',0


;================================= R O M  D A T A ============================

const:

         fcb 0,3bh,9ah,0cah,0
         fcb 0,5h,0f5h,0e1h,0
         fcb 0,0,98h,96h,80h
         fcb 0,0,0fh,42h,40h
         fcb 0,0,1,86h,0a0h
         fcb 0,0,00h,27h,10h
         fcb 0,0,00h,3h,0e8h
         fcb 0,0,00h,00h,64h
         fcb 0,0,00h,00h,0ah
         fcb 0,0,00h,00h,01h



;============================ RUTINAS INTERRUPION ===========================


TIMER:
        dec TimL
        bne FinCnt1

        dec TimH
        bne FinCnt1

dTimH:
        bset 1,flags    ;Indica overflow en TimerH TimerL

FinCnt1:

        dec Tim2L
        bne FinTimer

        dec Tim2H
        bne FinTimer

        bset 2,flags    ;Indica overflow en Timer2H Timer2L


FinTimer:

        ldx PCB
        lda #$ff
        sta PCB

        lda #$1
        sta PORTB
        clra
        sta PORTB         ;Refds.bco del Watch Dog

        stx PCB

NoRefds.bco:

        bclr 5,TSR
        jsr pretim
        rti


IRQ:
SPI:
SCI:
SWI:

        RTI
;==============================================================================
 
        END
