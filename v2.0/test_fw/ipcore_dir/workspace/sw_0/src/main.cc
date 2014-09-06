#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <assert.h>
#include "descs.h"

#define LEDBITS *((uint32_t volatile *)0xC0000000)
#define TMR *((uint32_t volatile *)0xC0000004)

#define USB_CTRL *((uint8_t volatile *)0xC0000008)
#define USB_CTRL_ATTACH (1<<0)
#define USB_CTRL_RST (1<<1)
#define USB_CTRL_RST_CLR (1<<2)

#define USB_ADDRESS *((uint8_t volatile *)0xC000000C)

#define USB_EP0_OUT_CTRL *((uint8_t volatile *)0xC0000010)
#define USB_EP0_OUT_CNT *((uint8_t volatile *)0xC0000011)

#define USB_EP0_IN_CTRL *((uint8_t volatile *)0xC0000014)
#define USB_EP0_IN_CNT *((uint8_t volatile *)0xC0000015)

#define USB_EP_TOGGLE_CLR (1<<7)
#define USB_EP_TOGGLE_SET (1<<6)
#define USB_EP_TOGGLE     (1<<5)
#define USB_EP_STALL      (1<<4)
#define USB_EP_SETUP_CLR  (1<<3)
#define USB_EP_SETUP      (1<<2)
#define USB_EP_FULL_CLR   (1<<1)
#define USB_EP_FULL_SET   (1<<0)
#define USB_EP_FULL       (1<<0)

#define SPI_CTRL *((uint8_t volatile *)0xC0000020)
#define SPI_DATA *((uint8_t volatile *)0xC0000024)

#define ICAP_CTRL *((uint32_t volatile *)0xC0000028)
#define ICAP_CS_bm (1<<0)
#define ICAP_BUSY_bm (1<<1)
#define ICAP_RUN_bm (1<<2)
#define ICAP_DATA *((uint32_t volatile *)0xC000002C)

#define DNA *((uint64_t volatile *)0xC0000030)
#define DNA_READY_bm (1ull<<63)

#define USB_EP0_OUT ((uint8_t volatile *)0xC0001000)
#define USB_EP0_IN ((uint8_t volatile *)0xC0001080)

//#define ENABLE_DEBUG

#ifdef ENABLE_DEBUG

#define UART_RX *((uint8_t const volatile *)0x80000000)
#define UART_TX *((uint8_t volatile *)0x80000004)
#define UART_STATUS *((uint8_t const volatile *)0x80000008)
#define UART_STATUS_RX_VALID_bm (1<<0)
#define UART_STATUS_TX_USED_bm (1<<3)

bool rxready()
{
	return UART_STATUS & UART_STATUS_RX_VALID_bm;
}

uint8_t recv()
{
	while (!rxready())
	{
	}

	return UART_RX;
}

void sendch(char ch)
{
	while (UART_STATUS & UART_STATUS_TX_USED_bm)
	{
	}

	UART_TX = ch;
}

void send(char const * str)
{
	while (*str != 0)
		sendch(*str++);
}

template <typename T>
void sendhex(T n)
{
	uint8_t const * p = (uint8_t const *)&n;
	uint8_t const * pend = (uint8_t const *)&n + sizeof n;
	while (p != pend)
	{
		--pend;

		static char const digits[] = "0123456789abcdef";
		sendch(digits[*pend >> 4]);
		sendch(digits[*pend & 0xf]);
	}
}

#endif

static void spi_begin()
{
	SPI_CTRL = 0;
}

static void spi_end()
{
	SPI_CTRL = (1<<0);
}

static uint8_t spi(uint8_t v = 0)
{
	SPI_DATA = v;
	while (SPI_CTRL & (1<<1))
	{
	}
	return SPI_DATA;
}

struct usb_ctrl_req_t
{
	uint8_t bmRequestType;
	uint8_t bRequest;
	uint16_t wValue;
	uint16_t wIndex;
	uint16_t wLength;

	char ctx_buf[8];

	template <typename T>
	T & ctx()
	{
		return *reinterpret_cast<T *>(ctx_buf);
	}

	uint16_t cmd() const
	{
		return (bmRequestType << 8) | bRequest;
	}

	bool is_write() const
	{
		return (bmRequestType & 0x80) == 0;
	}

	bool is_read() const
	{
		return (bmRequestType & 0x80) != 0;
	}
};

class usb_writer_t
{
public:
	usb_writer_t()
	{
	}

	uint8_t * alloc_packet();
	void commit_packet(uint8_t size);
};

class usb_control_handler
{
public:
	virtual void on_data_out(usb_ctrl_req_t & req, uint8_t const * p, uint8_t len) = 0;
	virtual uint8_t on_data_in(usb_ctrl_req_t & req, uint8_t * p) = 0;
	virtual void commit_write(usb_ctrl_req_t & req) = 0;
};

class dfu_handler
	: public usb_control_handler
{
public:
	dfu_handler()
		: m_state(app_idle), m_status(err_ok), m_detach_time_base(0), m_detach_time_size(0), m_dnload_complete_time(0)
	{
		m_flash_pos = 0;

		spi_begin();
		spi(0x9F);
		spi(0x00);
		spi(0x00);
		m_flash_size = spi(0x00);
		spi_end();

		if (m_flash_size < 31)
			m_flash_size = (1<<m_flash_size);
	}

	void on_usb_reset()
	{
		if (TMR - m_detach_time_base <= m_detach_time_size)
		{
			m_state = dfu_idle;
		}
		else
		{
			if (m_needs_manifest)
				reconfigure();

			m_state = app_idle;
		}
		m_status = err_ok;
	}

	void commit_write(usb_ctrl_req_t & req)
	{
	}

	void process()
	{
		if (m_state == dfu_dnbusy)
		{
			spi_begin();
			spi(0x05);
			uint8_t status = spi(0x00);
			spi_end();

			if ((status & 1) == 0)
			{
				if (m_write_buf_size)
				{
					uint32_t next_page_boundary = (m_flash_pos + 0x100) & ~(uint32_t)0xff;
					if (next_page_boundary - m_flash_pos < m_write_buf_size)
					{
						uint16_t part = next_page_boundary - m_flash_pos;
						this->flash_write(m_flash_pos, m_write_buf + m_write_buf_offs, part);
						m_flash_pos += part;
						m_write_buf_size -= part;
						m_write_buf_offs = part;
					}
					else
					{
						this->flash_write(m_flash_pos, m_write_buf + m_write_buf_offs, m_write_buf_size);
						m_flash_pos += m_write_buf_size;
						m_write_buf_size = 0;
					}
				}
				else
				{
					m_state = dfu_dnload_idle;
				}
			}
		}
	}

	bool on_control_transfer(usb_ctrl_req_t & req)
	{
		switch (req.cmd())
		{
		case cmd_getstate:
			if (this->is_dfu_mode())
				return true;
			break;
		case cmd_upload:
			if (m_state == dfu_idle || m_state == dfu_upload_idle)
			{
				if (m_state == dfu_idle)
				{
					m_flash_pos = 0;
					m_state = dfu_upload_idle;
				}
				return true;
			}
			break;
		case cmd_detach:
			if (req.wLength == 0 && m_state == app_idle)
			{
				m_detach_time_base = TMR;
				m_detach_time_size = req.wValue * 1000;
				return true;
			}
			break;
		case cmd_dnload:
			if (req.wLength <= 256
				&& (m_state == dfu_idle || m_state == dfu_dnload_idle))
			{
				if (m_state == dfu_idle)
					m_flash_pos = 0;

				if (req.wLength)
				{
					m_write_buf_size = 0;
					m_state = dfu_dnload_sync;
				}
				else
				{
					m_state = dfu_idle;
					m_needs_manifest = true;
				}

				return true;
			}
			break;
		case cmd_clrstatus:
			if (this->is_dfu_mode() && req.wLength == 0 && m_state == dfu_error)
			{
				m_status = err_ok;
				m_state = dfu_idle;
				return true;
			}
			break;
		case cmd_abort:
			if (req.wLength == 0
				&& (m_state == dfu_idle || m_state == dfu_dnload_sync || m_state == dfu_dnload_idle || m_state == dfu_manifest_sync || m_state == dfu_upload_idle))
			{
				m_status = err_ok;
				m_state = dfu_idle;
				return true;
			}
			break;
		case cmd_getstatus:
			if (this->is_dfu_mode() && req.wLength >= 6)
				return true;
			break;
		}

		if (m_state >= dfu_idle)
			m_state = dfu_error;
		m_status = err_stalledpkt;
		return false;
	}

	void on_data_out(usb_ctrl_req_t & req, uint8_t const * p, uint8_t len)
	{
		switch (req.cmd())
		{
		case cmd_dnload:
			if (m_state == dfu_dnload_sync)
			{
				if (len == 0)
				{
					uint32_t next_boundary = (m_flash_pos + 0xffff) & ~(uint32_t)0xffff;
					if (next_boundary - m_flash_pos < m_write_buf_size)
					{
						this->flash_write_enable();

						spi_begin();
						spi(0xD8);
						spi(next_boundary >> 16);
						spi(next_boundary >> 8);
						spi(next_boundary);
						spi_end();

						m_dnload_complete_time = TMR + 600;
					}
					else
					{
						m_dnload_complete_time = TMR;
					}

					m_write_buf_offs = 0;
					m_state = dfu_dnbusy;
				}
				else
				{
					memcpy(m_write_buf + m_write_buf_size, p, len);
					m_write_buf_size += len;
				}
			}
			break;
		}
	}

	uint8_t on_data_in(usb_ctrl_req_t & req, uint8_t * p)
	{
		switch (req.cmd())
		{
		case cmd_getstate:
			p[0] = m_state;
			return 1;
		case cmd_getstatus:
		{
			p[0] = m_status;
			uint32_t tmr = TMR;
			if (m_dnload_complete_time < tmr)
			{
				p[1] = 0;
				p[2] = 0;
				p[3] = 0;
			}
			else
			{
				tmr = m_dnload_complete_time - tmr;
				p[1] = (uint8_t)tmr;
				p[2] = (uint8_t)(tmr >> 8);
				p[3] = (uint8_t)(tmr >> 16);
			}
			p[4] = m_state;
			p[5] = 0;
			return 6;
		}
		case cmd_upload:
			{
				uint8_t chunk = req.wLength > 64? 64: req.wLength;

				uint32_t rem = m_flash_size - m_flash_pos;
				if (chunk > rem)
					chunk = rem;

				spi_begin();
				spi(0x0B);
				spi(m_flash_pos >> 16);
				spi(m_flash_pos >> 8);
				spi(m_flash_pos);
				spi(0x00);
				for (uint32_t i = 0; i < chunk; ++i)
					*p++ = spi(0x00);
				spi_end();

				m_flash_pos += chunk;
				if (chunk < 64)
					m_state = dfu_idle;
				return chunk;
			}
		}

		return 0;
	}

	bool is_dfu_mode() const
	{
		return m_state >= dfu_idle;
	}

	void reconfigure()
	{
		static uint16_t const reset_seq[] = {
			0xFFFF, 0xAA99, 0x5566,
			0x3261, 0x0000,
			0x3281, 0x0000,
			0x32A1, 0x0000,
			0x32C1, 0x0000,
			0x30A1, 0x000E,
			0x2000,
		};

		ICAP_CTRL = ICAP_CS_bm;
		for (size_t i = 0; i < sizeof reset_seq / sizeof reset_seq[0]; ++i)
		{
			ICAP_DATA = reset_seq[i];
			while (ICAP_DATA & ICAP_BUSY_bm)
			{
			}
		}
		ICAP_CTRL = ICAP_RUN_bm;
	}

private:
	void flash_write_enable()
	{
		spi_begin();
		spi(0x06);
		spi_end();
	}

	void flash_write(uint32_t addr, uint8_t const * p, uint16_t len)
	{
		this->flash_write_enable();

		spi_begin();
		spi(0x02);
		spi(addr >> 16);
		spi(addr >> 8);
		spi(addr);
		for (; len > 0; --len)
			spi(*p++);
		spi_end();

	}

	enum
	{
		cmd_detach = 0x2100,
		cmd_dnload = 0x2101,
		cmd_upload = 0xa102,
		cmd_getstatus = 0xa103,
		cmd_clrstatus = 0x2104,
		cmd_getstate = 0xa105,
		cmd_abort = 0x2106,
	};

	enum state_t
	{
		app_idle,
		//app_detach,
		dfu_idle = 2,
		dfu_dnload_sync,
		dfu_dnbusy,
		dfu_dnload_idle,
		dfu_manifest_sync,
		dfu_manifest,
		dfu_manifest_wait_reset,
		dfu_upload_idle,
		dfu_error
	};

	enum status_t
	{
		err_ok = 0x00,
		err_target = 0x01,
		err_file = 0x02,
		err_write = 0x03,
		err_erase = 0x04,
		err_check_erased = 0x05,
		err_prog = 0x06,
		err_verify = 0x07,
		err_address = 0x08,
		err_notdone = 0x09,
		err_firmware = 0x0a,
		err_vendor = 0x0b,
		err_usbr = 0x0c,
		err_por = 0x0d,
		err_unknown = 0x0e,
		err_stalledpkt = 0x0f,
	};

	state_t m_state;
	status_t m_status;
	bool m_needs_manifest;
	uint32_t m_detach_time_base;
	uint32_t m_detach_time_size;
	uint32_t m_dnload_complete_time;

	uint32_t m_flash_pos;
	uint32_t m_flash_size;

	uint16_t m_write_buf_offs;
	uint16_t m_write_buf_size;
	uint8_t m_write_buf[256];
};

class usb_core_handler
	: public usb_control_handler
{
public:
	usb_core_handler()
		: m_config(0), m_descriptor_set(0)
	{
		while ((DNA & DNA_READY_bm) == 0)
		{
		}

		uint64_t dna = DNA;
		uint8_t const * p = (uint8_t const *)&dna;

		uint8_t * sn = m_sn;
		*sn++ = 30;
		*sn++ = 3;

		for (uint8_t i = 7; i != 0; --i)
		{
			static char const digits[] = "0123456789abcdef";
			uint8_t d = p[i-1];
			*sn++ = digits[d >> 4];
			*sn++ = 0;
			*sn++ = digits[d & 0xf];
			*sn++ = 0;
		}
	}

	void on_usb_reset()
	{
		m_config = 0;
	}

	void commit_write(usb_ctrl_req_t & req)
	{
		switch (req.cmd())
		{
		case cmd_set_address:
			USB_ADDRESS = req.wValue;
			break;
		}
	}

	bool on_control_transfer(usb_ctrl_req_t & req)
	{
		switch (req.cmd())
		{
		case cmd_get_descriptor: // get_descriptor
			if (req.wValue != 0x302)
			{
				uint8_t entry_first = usb_descriptor_set[m_descriptor_set].first;
				uint8_t entry_last = usb_descriptor_set[m_descriptor_set].last;

				usb_descriptor_entry_t const * selected = 0;
				for (size_t i = entry_first; !selected && i < entry_last; ++i)
				{
					if (usb_descriptor_map[i].index == req.wValue)
						selected = &usb_descriptor_map[i];
				}

				if (!selected)
					return false;

				uint16_t size = selected->size;
				if (size > req.wLength)
					size = req.wLength;

				get_desc_ctx_t & ctx = req.ctx<get_desc_ctx_t>();
				ctx.first = usb_descriptor_data + selected->offset;
				ctx.last = ctx.first + size;
			}
			else
			{
				uint16_t size = sizeof m_sn;
				if (size > req.wLength)
					size = req.wLength;

				get_desc_ctx_t & ctx = req.ctx<get_desc_ctx_t>();
				ctx.first = m_sn;
				ctx.last = m_sn + size;
			}
			return true;
		case cmd_set_address:
			return true;
		case cmd_get_config:
			return true;
		case cmd_set_config:
			if (req.wValue < 2)
			{
				m_config = (uint8_t)req.wValue;
				return true;
			}
			break;
		}

		return false;
	}

	void on_data_out(usb_ctrl_req_t & req, uint8_t const * p, uint8_t len)
	{

	}

	uint8_t on_data_in(usb_ctrl_req_t & req, uint8_t * p)
	{
		switch (req.cmd())
		{
		case cmd_get_descriptor:
			{
				get_desc_ctx_t & ctx = req.ctx<get_desc_ctx_t>();
				uint16_t chunk = ctx.last - ctx.first;
				if (chunk > 64)
					chunk = 64;
				memcpy(p, ctx.first, chunk);
				ctx.first += chunk;
				return chunk;
			}

		case cmd_get_config:
			p[0] = m_config;
			return 1;
		}

		return 0;
	}

	void set_desc_set(uint8_t ds)
	{
		m_descriptor_set = ds;
	}

private:
	enum
	{
		cmd_set_address = 0x0005,
		cmd_get_descriptor = 0x8006,
		cmd_get_config = 0x8008,
		cmd_set_config = 0x0009,
	};

	struct get_desc_ctx_t
	{
		uint8_t const * first;
		uint8_t const * last;
	};

	uint8_t m_config;
	uint8_t m_descriptor_set;
	uint8_t m_sn[30];
};

int main()
{
	USB_CTRL = USB_CTRL_ATTACH;

	dfu_handler dh;
	usb_core_handler uc;
	usb_control_handler * usb_handler = 0;
	usb_ctrl_req_t usb_req;

	bool last_reset_state = false;

	for (;;)
	{
#ifdef ENABLE_DEBUG
		if (rxready())
		{
			switch (recv())
			{
			case 'r':
				spi_begin();
				sendhex(spi(0x9E));
				for (uint8_t i = 0; i < 20; ++i)
					sendhex(spi(0));
				sendch('\n');
				spi_end();
				break;
			case 'R':
				spi_begin();
				sendhex(spi(0x0B));
				sendhex(spi(0x00));
				sendhex(spi(0x00));
				sendhex(spi(0x00));
				sendhex(spi(0x00));
				for (uint8_t i = 0; i < 20; ++i)
					sendhex(spi(0));
				sendch('\n');
				spi_end();
				break;
			case 's':
				spi_begin();
				sendhex(spi(0x05));
				for (uint8_t i = 0; i < 20; ++i)
					sendhex(spi(0));
				sendch('\n');
				spi_end();
				break;
			case 'W':
				spi_begin();
				sendhex(spi(0x06));
				sendch('\n');
				spi_end();
				break;
			case 'w':
				spi_begin();
				sendhex(spi(0x04));
				sendch('\n');
				spi_end();
				break;
			case 'K':
				spi_begin();
				sendhex(spi(0xC7));
				sendch('\n');
				spi_end();
				break;
			case 'T':
				spi_begin();
				sendhex(spi(0x02));
				sendhex(spi(0x00));
				sendhex(spi(0x00));
				sendhex(spi(0x00));
				for (uint8_t i = 0; i < 20; ++i)
					sendhex(spi(i + 0x10));
				sendch('\n');
				spi_end();
				break;
			case 'L':
				dh.reconfigure();
				break;
			}
		}
#endif

		dh.process();

		if (USB_CTRL & USB_CTRL_RST)
		{
			USB_ADDRESS = 0;
			USB_CTRL |= USB_CTRL_RST_CLR;
			USB_EP0_OUT_CTRL = USB_EP_STALL | USB_EP_FULL_CLR;
			USB_EP0_IN_CTRL = USB_EP_STALL | USB_EP_FULL_CLR | USB_EP_SETUP_CLR;

			if (!last_reset_state)
			{
				uc.on_usb_reset();
				dh.on_usb_reset();
				usb_handler = 0;

				uint8_t ds = dh.is_dfu_mode()? 1: 0;
				uc.set_desc_set(ds);
#ifdef ENABLE_DEBUG
				send("RESET ");
				sendhex(ds);
				sendch('\n');
#endif
				last_reset_state = true;
			}

			LEDBITS |= 2;
		}
		else
		{
			last_reset_state = false;
			LEDBITS &= ~2;
		}

		if (usb_handler && (USB_EP0_IN_CTRL & USB_EP_FULL) == 0)
		{
			if (usb_req.is_write())
			{
				if (!usb_req.wLength)
				{
					usb_handler->commit_write(usb_req);
					usb_handler = 0;
				}
			}
			else if (usb_req.wLength)
			{
				uint8_t len = usb_handler->on_data_in(usb_req, (uint8_t *)USB_EP0_IN);
				USB_EP0_IN_CNT = len;
				USB_EP0_IN_CTRL = USB_EP_FULL_SET;
				usb_req.wLength -= len;
			}
		}

		if (usb_handler && usb_req.is_write() && (USB_EP0_OUT_CTRL & USB_EP_FULL) != 0)
		{
			uint8_t cnt = USB_EP0_OUT_CNT;
			if (cnt > usb_req.wLength)
			{
				USB_EP0_OUT_CTRL = USB_EP_STALL | USB_EP_FULL_CLR;
				USB_EP0_IN_CTRL = USB_EP_STALL;
			}
			else
			{
				assert(usb_req.wLength);
				usb_handler->on_data_out(usb_req, (uint8_t const *)USB_EP0_OUT, cnt);

				if ((usb_req.wLength -= cnt) != 0)
				{
					USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
				}
				else
				{
					usb_handler->on_data_out(usb_req, 0, 0);
					USB_EP0_OUT_CTRL = USB_EP_FULL_CLR | USB_EP_STALL;
					USB_EP0_IN_CTRL = USB_EP_FULL_SET;
				}
			}
		}

		if (USB_EP0_OUT_CTRL & USB_EP_SETUP)
		{
			USB_EP0_IN_CTRL = USB_EP_TOGGLE_SET | USB_EP_FULL_CLR;
			USB_EP0_OUT_CTRL = USB_EP_TOGGLE_SET | USB_EP_SETUP_CLR | USB_EP_FULL;

			if (usb_handler && usb_req.is_write())
				usb_handler->commit_write(usb_req);
			usb_handler = 0;

			memcpy(&usb_req, (void const *)USB_EP0_OUT, 8);

#ifdef ENABLE_DEBUG
			sendch('S');
			sendhex(usb_req.bmRequestType);
			sendhex(usb_req.bRequest);
			sendch(' ');
			sendhex(usb_req.wValue);
			sendch(' ');
			sendhex(usb_req.wIndex);
			sendch(' ');
			sendhex(usb_req.wLength);
			sendch('\n');
#endif

			if ((usb_req.bmRequestType & 0x1f) == 0)
			{
				if (uc.on_control_transfer(usb_req))
					usb_handler = &uc;
			}
			else if ((usb_req.bmRequestType & 0x1f) == 1 && usb_req.wIndex == 0)
			{
				if (dh.on_control_transfer(usb_req))
					usb_handler = &dh;
			}

			if (!usb_handler)
			{
#ifdef ENABLE_DEBUG
				send("STALL\n");
#endif
				USB_EP0_OUT_CTRL = USB_EP_STALL;
				USB_EP0_IN_CTRL = USB_EP_STALL;
			}
			else if (usb_req.is_write())
			{
				USB_EP0_IN_CNT = 0;
				if (usb_req.wLength)
				{
					USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
				}
				else
				{
					USB_EP0_OUT_CTRL = USB_EP_FULL_CLR | USB_EP_STALL;
					USB_EP0_IN_CTRL = USB_EP_FULL_SET;
				}
			}
			else
			{
				assert(usb_req.is_read());
				USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
			}
		}
	}

	return 0;
}
