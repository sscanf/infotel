;
;
;
;
; STACK.ASM   Program to provide PSHA, PULA, PSHX,
;             and PULX functions to the MC68HC05
;             family of microprocessors.
;
;  By Raymond J. Bell   07Apr92
;
;  Description:  This set of subroutines uses 3
;                bytes of page zero RAM located
;                at 'STACK' to mimic the operation
;                of a stack.  By fiddling with the
;                opcode bits a LDA direct instruc-
;                tion can be transformed into STA,
;                LDX or STX. These routines have
;                the advantage that no hardware
;                registers are used. In this ex-
;                ample, the stack is presumed to
;                start at $00BF and grow downward.
;                The modifiable code fragment is
;                assembled at $0030. Other loca-
;                tions can be used by altering
;                labels 'PSTCK' and 'SPINIT'
;                respectively.
;

                 xdef   PSHA
                 xdef   PULA
                 xdef   PSHX
                 xdef   PULX
                 xdef   StackInit

ram2	section

_tmp     ds.b 1

text	section
;---- Define memory locations ----;
;
SPINIT  equ     $bc     ;initial location of stack
PSTCK   equ     $bd     ;location of RAM code
SPTR    equ     PSTCK+1 ;location of stack pointer
;
;---- Push A ----;
;
PSHA    dec     SPTR      ;make room on stack
        bclr    3,PSTCK ;change opcode into
        bset    0,PSTCK ; sta direct
        jsr     PSTCK   ;execute
        rts             ;
;
;---- Pull A ----;
;
PULA    bclr    3,PSTCK ;change opcode into
        bclr    0,PSTCK ; lda direct
        jsr     PSTCK   ;execute
        inc     SPTR      ;pop stack pointer
        rts             ;
;
;---- Push X ----;
;
PSHX    dec     SPTR      ;make room on stack
        bset    3,PSTCK ;change opcode into
        bset    0,PSTCK ; stx direct
        jsr     PSTCK   ;execute
        rts             ;
;
;---- Pull X ----;
;
PULX    bset    3,PSTCK ;change opcode into
        bclr    0,PSTCK ; ldx direct
        jsr     PSTCK   ;execute
        inc     SPTR      ;pop stack
        rts             ;
;
;---- Initialize RAM code ----;
;
StackInit:

        lda     #$b6       ;lda direct
        sta     PSTCK
        lda     #SPINIT+1  ;stack pointer
;                          (will be decremented
;                           before first use)
        sta     SPTR
        lda     #$81    ; rts
        sta     SPTR+1
        rts
;
; To invoke these routines, just do a JSR PSHA,
; PULA, PSHX or PULX.
;
; N.B. If you want to use these routines in
; interrupt service routines, it is
; IMPERATIVE that you bracket each of them with a
; SEI, CLI pair.
;
       end
