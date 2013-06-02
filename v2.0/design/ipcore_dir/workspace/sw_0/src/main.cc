/*
 * Empty C++ Application
 */

#include <stdint.h>

#define UART_RX     *((uint32_t volatile *)0x80000000)
#define UART_TX     *((uint32_t volatile *)0x80000004)
#define UART_STATUS *((uint32_t volatile *)0x80000008)
#define UART_TX_USED_bm  (1<<3)
#define UART_RX_VALID_bm (1<<0)

static void sendch(char ch)
{
	while (UART_STATUS & UART_TX_USED_bm)
	{
	}

	UART_TX = ch;
}

static void send(char const * s)
{
	while (*s)
		sendch(*s++);
}

int main()
{
	for (;;)
	{
		if (UART_STATUS & UART_RX_VALID_bm)
		{
			char ch = UART_RX;
			switch (ch)
			{
			case '?':
				send("hello!\n");
				break;
			default:
				sendch(ch+1);
			}
		}
	}
	return 0;
}
