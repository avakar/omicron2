/*
 * Empty C++ Application
 */

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define PROGMEM
#include "descs.h"

#define UART_RX     *((uint32_t volatile *)0x80000000)
#define UART_TX     *((uint32_t volatile *)0x80000004)
#define UART_STATUS *((uint32_t volatile *)0x80000008)
#define UART_TX_USED_bm  (1<<3)
#define UART_RX_VALID_bm (1<<0)

#define USB_CTRL    *((uint32_t volatile *)0xC0000000)
#define USB_ATTACH    (1<<0)
#define USB_RESET_IF  (1<<1)
#define USB_RESET_CLR (1<<2)
#define USB_ADDRESS *((uint32_t volatile *)0xC0000004)

#define USB_EP0_OUT_CTRL *((uint32_t volatile *)0xC0000100)
#define USB_EP0_IN_CTRL  *((uint32_t volatile *)0xC0000104)

#define USB_EP1_OUT_CTRL *((uint32_t volatile *)0xC0000110)
#define USB_EP1_IN_CTRL  *((uint32_t volatile *)0xC0000114)

#define USB_EP_OUT_CNT(x) ((uint8_t)(((x) >> 8) & 0x3f))
#define USB_EP_IN_CNT(x)  ((uint8_t)(x) << 8)

#define USB_EP_TOGGLE     (1<<5)
#define USB_EP_TOGGLE_SET (1<<6)
#define USB_EP_TOGGLE_CLR (1<<7)
#define USB_EP_STALL      (1<<4)
#define USB_EP_SETUP_CLR  (1<<3)
#define USB_EP_SETUP      (1<<2)
#define USB_EP_FULL_CLR   (1<<1)
#define USB_EP_FULL       (1<<0)

#define USB_EP0_OUT ((uint8_t volatile *)0xC1000000)
#define USB_EP0_IN  ((uint8_t volatile *)0xC1000080)
#define USB_EP1_OUT ((uint8_t volatile *)0xC1000100)
#define USB_EP1_IN  ((uint8_t volatile *)0xC1000180)
#define USB_EP2_OUT ((uint8_t volatile *)0xC1000200)
#define USB_EP2_IN  ((uint8_t volatile *)0xC1000280)
#define USB_EP3_OUT ((uint8_t volatile *)0xC1000300)
#define USB_EP3_IN  ((uint8_t volatile *)0xC1000380)

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

static void sendh(uint8_t s)
{
	static char const digits[] = "0123456789abcdef";
	sendch(digits[s >> 4]);
	sendch(digits[s & 0xf]);
}

static void sendh(uint16_t s)
{
	sendh((uint8_t)(s >> 8));
	sendh((uint8_t)s);
}

/*static void sendh(uint32_t s)
{
	sendh((uint16_t)(s >> 16));
	sendh((uint16_t)s);
}*/

int main()
{
	enum { ia_none, ia_set_address } action = ia_none;
	uint8_t new_address = 0;
	uint8_t config = 0;
	for (;;)
	{
		if (USB_CTRL & USB_RESET_IF)
		{
			send("RESET\n");
			USB_ADDRESS = 0;
			USB_CTRL |= USB_RESET_CLR;
			USB_EP0_IN_CTRL = USB_EP_STALL | USB_EP_FULL_CLR;
			USB_EP0_OUT_CTRL = USB_EP_STALL | USB_EP_FULL | USB_EP_SETUP_CLR;
			USB_EP1_IN_CTRL = USB_EP_STALL | USB_EP_FULL_CLR;
			USB_EP1_OUT_CTRL = USB_EP_STALL | USB_EP_FULL_CLR | USB_EP_SETUP_CLR;
			action = ia_none;
			config = 0;
		}

		if ((USB_EP0_IN_CTRL & USB_EP_FULL) == 0)
		{
			switch (action)
			{
			case ia_none:
				break;
			case ia_set_address:
				send("SET_ADDRESS ");
				sendh(new_address);
				sendch('\n');
				USB_ADDRESS = new_address;
				action = ia_none;
				break;
			}
		}

		if (USB_EP1_OUT_CTRL & USB_EP_FULL)
		{
			uint8_t cnt = USB_EP_OUT_CNT(USB_EP1_OUT_CTRL);
			for (uint8_t i = 0; i < cnt; ++i)
				sendch(USB_EP1_OUT[i]);
			USB_EP1_OUT_CTRL = USB_EP_FULL_CLR;
		}

		if (USB_EP0_OUT_CTRL & USB_EP_SETUP)
		{
			USB_EP0_IN_CTRL = USB_EP_TOGGLE_SET | USB_EP_FULL_CLR;
			USB_EP0_OUT_CTRL = USB_EP_TOGGLE_SET | USB_EP_SETUP_CLR | USB_EP_FULL;
			action = ia_none;

			uint16_t cmd = (USB_EP0_OUT[0] << 8) | USB_EP0_OUT[1];
			uint16_t wValue = (USB_EP0_OUT[3] << 8) | USB_EP0_OUT[2];
			uint16_t wIndex = (USB_EP0_OUT[5] << 8) | USB_EP0_OUT[4];
			uint16_t wLength = (USB_EP0_OUT[7] << 8) | USB_EP0_OUT[6];

			send("SETUP ");
			sendh(cmd);
			sendch(':');
			sendh(wValue);
			sendch(':');
			sendh(wIndex);
			sendch(':');
			sendh(wLength);
			sendch('\n');

			switch (cmd)
			{
			case 0x8006: // get_descriptor
				{
					usb_descriptor_entry_t const * selected = 0;
					for (size_t i = 0; !selected && i < sizeof usb_descriptor_map / sizeof usb_descriptor_map[0]; ++i)
					{
						if (usb_descriptor_map[i].index == wValue)
							selected = &usb_descriptor_map[i];
					}

					if (!selected)
					{
						USB_EP0_IN_CTRL = USB_EP_STALL;
						USB_EP0_OUT_CTRL = USB_EP_STALL;
					}
					else
					{
						uint16_t size = selected->size;
						if (size > wLength)
							size = wLength;

						memcpy((void *)USB_EP0_IN, usb_descriptors + selected->offset, size);
						USB_EP0_IN_CTRL = USB_EP_IN_CNT(size) | USB_EP_FULL;
						USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
					}
				}
				break;
			case 0x0005: // set_address
				new_address = wValue;
				action = ia_set_address;
				USB_EP0_OUT_CTRL = USB_EP_STALL;
				USB_EP0_IN_CTRL = USB_EP_IN_CNT(0) | USB_EP_FULL;
				break;
			case 0x8008: // get_config
				USB_EP0_IN[0] = config;
				USB_EP0_IN_CTRL = USB_EP_IN_CNT(1) | USB_EP_FULL;
				USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
				break;
			case 0x0009: // set_config
				if (wValue > 1)
				{
					USB_EP0_OUT_CTRL = USB_EP_STALL;
					USB_EP0_IN_CTRL = USB_EP_STALL;
				}
				else
				{
					send("SET_CONFIG ");
					sendh((uint8_t)wValue);
					sendch('\n');
					config = (uint8_t)wValue;

					if (config)
					{
						USB_EP1_IN_CTRL = USB_EP_TOGGLE_CLR | USB_EP_FULL_CLR;
						USB_EP1_OUT_CTRL =  USB_EP_TOGGLE_CLR | USB_EP_FULL_CLR | USB_EP_SETUP_CLR;
					}
					else
					{
						USB_EP1_IN_CTRL = USB_EP_STALL;
						USB_EP1_OUT_CTRL = USB_EP_STALL | USB_EP_SETUP_CLR;
					}

					USB_EP0_OUT_CTRL = USB_EP_STALL;
					USB_EP0_IN_CTRL = USB_EP_IN_CNT(0) | USB_EP_FULL;
				}
				break;
			default:
				USB_EP0_OUT_CTRL = USB_EP_STALL;
				USB_EP0_IN_CTRL = USB_EP_STALL;
			}
		}

		if (UART_STATUS & UART_RX_VALID_bm)
		{
			char ch = UART_RX;
			switch (ch)
			{
			case '?':
				sendh((uint16_t)USB_CTRL);
				sendch(':');
				sendh((uint16_t)USB_EP0_IN_CTRL);
				sendch(':');
				sendh((uint16_t)USB_EP0_OUT_CTRL);
				sendch(':');
				sendh((uint16_t)USB_EP1_IN_CTRL);
				sendch(':');
				sendh((uint16_t)USB_EP1_OUT_CTRL);
				sendch('\n');
				break;
			case 'q':
				USB_EP1_OUT_CTRL = USB_EP_TOGGLE_SET;
				break;
			case 'Q':
				USB_EP1_OUT_CTRL = USB_EP_TOGGLE_CLR;
				break;
			case 'm':
				USB_EP1_IN[0] = 'e';
				USB_EP1_IN_CTRL = USB_EP_IN_CNT(1) | USB_EP_FULL;
				break;
			case 'u':
				USB_CTRL = USB_ATTACH;
				break;
			case 'U':
				USB_CTRL = 0;
				break;
			case 't':
				for (int i = 0; i < 64; ++i)
					sendh(USB_EP0_OUT[i]);
				sendch('\n');
				break;
			case 'T':
				for (int i = 0; i < 64; ++i)
					USB_EP0_OUT[i] += i;
				sendch('\n');
				break;
			default:
				send("unknown command\n");
			}
		}
	}
	return 0;
}
