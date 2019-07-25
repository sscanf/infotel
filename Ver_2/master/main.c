
#pragma CREATE_ASM_LISTING ON
/* terminal.wnd */
#define SCI_ADDR 0x0D
#define NOCHAR  0
#define  SCI (*((SCIStruct* far)(SCI_ADDR)))
#define BUFFER_SIZE 6

#include "infotel.h"
#include "lcd.h"
#include "memo.h"

#include <stdlib.h>
#include <hidef.h>
#include <ctype.h>


#define lda 0xD6        /* indexed long */
#define sta 0xD7        /* indexed long */
#define jmp 0xCC        /* ext */
#define rts 0x81

#define STROBE	0x80
#define TELEFONO 0x10

#define PORTA_DATA (*((unsigned char *)(0x0)))
#define PORTB_DATA (*((unsigned char *)(0x1)))
#define PORTC_DATA (*((unsigned char *)(0x2)))
#define PORTD_DATA (*((unsigned char *)(0x3)))

#define PORTA_CTRL		(*((unsigned char *)0x4))
#define PORTB_CTRL		(*((unsigned char *)0x5))
#define PORTC_CTRL		(*((unsigned char *)0x6))

#define SPCR (*((unsigned char *)0x0A))
#define SPSR (*((unsigned char *)0x0B))
#define SPDR (*((unsigned char *)0x0C))
#define TCR (*((unsigned char*)(0x12)))

#define CCR (*((unsigned char*)(0x1fdf)))

 extern char _SEX[4], _LEX[4], _JSR[3];


const char far MainScrn1[17]={"  Electronica   \0"};
const char far MainScrn2[17]={" Barcelona S.L. \0"};
const char far repro1[17]={"- - - - - - - - \0"};
const char far repro2[17]={" - - - - - - - -\0"};
const char far reproduciendo[17]={"REPROD. MENSAJE \0"};

/*
const char Far errores[4][17]={"ERROR:SIN TONO  \0",
			 			       "ERROR:SIN RESP  \0",
							   "ERROR:LINEA     \0",
							   "ERROR:SIN NUMERO\0"};*/

void delay (void)
{
	int n,i;
	for (n=0;n<2 ;n++ )
		for (i=0;i<0x3fff ;i++ );

}

void delay2 (void)
{
	int n;
	for (n=0;n<10;n++ );
}

void OutSPI (unsigned char byte)
{
	SPCR = 0x53;
	SPDR = byte;
	while (!(SPSR&0x80));
}

unsigned char GetSPI (void)
{
	unsigned char byte;

	SPCR = 0x57;
	SPDR = 0x00;
	while (!(SPSR&0x80));
	byte = SPDR;
	return byte;
}

int contacto()
{
	//Esta función obtiene el estado de los contactos (8 bits)
	//y hace un OR con el estado de los contactos de la otra placa. (8 bits)
	//Devuelve un entero (16 bits).
	//La otra placa nos entrega el estado de sus 8 contactos mediante el SPI.

	int val;

	PORTB_DATA|=0xc0;	//Activamos el chip select de la placa esclavo
	val=MKWORD (GetSPI(),PORTA_DATA);	//Formamos la palabra con los dos bytes.
	PORTB_DATA&=0x7f;	//Desactivamos el chip select de la placa esclavo
	delay2();
	return val;
}

void PrintScrn (char pos, char *msg)
{
	//Escribimos una cadena ASCII en el display
	//En pos es donde queremos posicionar el cursor.

	wadc (pos);	//Posicionamos el cursor

	for (;*msg != 0;msg++)
		wrdat (*msg);
}

void MainScrn(void)
{
	PrintScrn (0,(const char far*)MainScrn1);
	PrintScrn (64,(const char far*)MainScrn2);
}

void main()
{
	unsigned char n,q;
	int mask,temp,word,AntWord;
	//Esto está extraido del módulo que STARTUPX.C que viene con el compilador
	//Inicializa el entorno para que el C funcione correctamente.
	 _LEX[0]= lda; _LEX[3]= rts; _SEX[0]= sta; _SEX[3]= rts;
	 _JSR[0]= jmp;  


	word=0;
	AntWord=0;

	CCR = (unsigned char)0xc2;
	PORTC_CTRL = 0xb7;
	PORTA_CTRL = 0x00;
	PORTC_DATA&=~STROBE;

	TCR |= 0x20;		//PONEMOS EN MARCHA EL TIMER
	SPCR = (unsigned char)0x57;		//Configuramos el SPI como master

	OutSPI (0xff);
	OutSPI (0xff);
	PORTC_DATA|=STROBE;
	PORTC_DATA&=~STROBE;

	IniDis();
	MemoIni();

	PORTC_DATA|=TELEFONO;	//Colgamos el teléfono

	for (; ; )
	{
		ClrDsp();
		MainScrn();

		while (!getch()) //Mientras no pulsan una tecla
		{
			//Miramos si han accionado algún contacto.
			word = contacto();

			if (word!=AntWord)	//Ha habido un cambio en los contactos.
			{
				temp = word ^AntWord; //Hacemos un or exclusivo para ver que bits han cambiado
				temp&=contacto();
				AntWord=word;
				if (temp&word)		 //Si el contacto está a 0 no hacemos nada.
				{
					for (mask=0x01,n=0;n<16 ;n++,mask<<=1)
					{
						if (temp&mask)
						{
							//Lamamos al número correspondiente.
							//La función llamar hace los intentos con los 3 números de la entrada accionada 
							//e informa en el display del progreso, incluidos los errores.

							if (llamar (n)!=0xff) //Si llamar no regresa con 0xFF, es que no ha habido error.
							{
								//Activamos la placa que contiene el mensaje
								OutSPI (HIBYTE (~mask));
								OutSPI (LOBYTE (~mask));
								PORTC_DATA|=STROBE;
								PORTC_DATA&=~STROBE;
								delay2();
								OutSPI (0xff);
								OutSPI (0xff);
								PORTC_DATA|=STROBE;
								PORTC_DATA&=~STROBE;

								ClrDsp();
								PrintScrn (0,reproduciendo);

								for (q=0;q<0x7;q++ )
								{
									delay();
									PrintScrn(64,(const char far*)repro1);
									delay();
									PrintScrn(64,(const char far*)repro2);
								}
							}
							PORTC_DATA|=TELEFONO;	//Colgamos el teléfono
							delay();
							delay();				//Tiempo para colgado
							ClrDsp();
							MainScrn();
						}
					}
				}
			}
		}
		edicion(); //Han puslado una tecla, entra en modo edición.
	}
}
