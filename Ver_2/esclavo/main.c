
#pragma CREATE_ASM_LISTING ON
/* terminal.wnd */

#include <stdlib.h>
#include <hidef.h>
#include <ctype.h>


#define lda 0xD6        /* indexed long */
#define sta 0xD7        /* indexed long */
#define jmp 0xCC        /* ext */
#define rts 0x81

#define PORTA_DATA (*((unsigned char *)(0x0)))
#define PORTB_DATA (*((unsigned char *)(0x1)))
#define PORTC_DATA (*((unsigned char *)(0x2)))

#define PORTA_CTRL		(*((char *)0x4))
#define PORTB_CTRL		(*((char *)0x5))
#define PORTC_CTRL		(*((char *)0x6))
#define PORTD_CTRL		(*((char *)0x7))

#define SPCR (*((unsigned char *)(0x0A)))
#define SPSR (*((unsigned char *)(0x0B)))
#define SPDR (*((unsigned char *)(0x0C)))

#define CCR (*((unsigned char*)(0x1fdf)))

#define WCOL 0x1

void main()
{
	//El PORTB lo utilizaremos para señalizar errores.
	//Bit0 = Error en configuración de SPI, 

	unsigned char status;
	CCR = (unsigned char)0xc2;
	PORTA_CTRL = 0x00;	//PORTA como entradas.
	PORTB_CTRL = 0xff;	//PORTB como entradas;

	SPCR = (unsigned char)0x47;		//Configuramos el SPI como esclavo

	for (;;)
	{
		status= SPDR;
		SPDR=PORTA_DATA;
		if (SPSR&0x40)
			PORTB_DATA|=WCOL;
		else
			PORTB_DATA&=~WCOL;

		while (!(SPSR&0x80));
	}
}

extern interrupt void SPI()
{
}

extern interrupt void TIMER()
{
}

extern interrupt void IRQ()
{
}

extern interrupt  void SWI()
{
}

extern interrupt void SCI()
{
}
