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
#define USB_EP0_OUT_STATUS *((uint8_t const volatile *)0xC0000010)
#define USB_EP0_OUT_CNT *((uint8_t volatile *)0xC0000011)
#define USB_EP0_IN_CTRL *((uint8_t volatile *)0xC0000014)
#define USB_EP0_IN_STATUS *((uint8_t const volatile *)0xC0000014)
#define USB_EP0_IN_CNT *((uint8_t volatile *)0xC0000015)
#define USB_EP0_OUT ((uint8_t volatile *)0xC0001000)
#define USB_EP0_IN ((uint8_t volatile *)0xC0001040)

#define USB_EP1_OUT_CTRL *((uint8_t volatile *)0xC0000018)
#define USB_EP1_OUT_STATUS *((uint8_t const volatile *)0xC0000018)
#define USB_EP1_OUT_CNT *((uint8_t volatile *)0xC0000019)
#define USB_EP1_IN_CTRL *((uint8_t volatile *)0xC000001C)
#define USB_EP1_IN_STATUS *((uint8_t const volatile *)0xC000001C)
#define USB_EP1_IN_CNT (*((uint8_t volatile *)0xC000001D))
#define USB_EP1_OUT ((uint8_t volatile *)0xC0001080)
#define USB_EP1_IN ((uint8_t volatile *)0xC00010C0)


#define USB_EP2_OUT_CTRL *((uint8_t volatile *)0xC0000040)
#define USB_EP2_OUT_STATUS *((uint8_t const volatile *)0xC0000040)
#define USB_EP2_IN_CTRL *((uint8_t volatile *)0xC0000044)
#define USB_EP2_IN_STATUS *((uint8_t const volatile *)0xC0000044)

#define USB_EP_PAUSE_CLR (1<<7)
#define USB_EP_PAUSE_SET (1<<6)
#define USB_EP_TOGGLE_CLR (1<<5)
#define USB_EP_TOGGLE_SET (1<<4)
#define USB_EP_STALL_SET  (1<<3)
#define USB_EP_SETUP_CLR  (1<<2)
#define USB_EP_PULL       (1<<1)
#define USB_EP_PUSH       (1<<0)

#define USB_EP_PAUSE_bm   (1<<7)
#define USB_EP_TRANSIT_bm (1<<6)
#define USB_EP_TOGGLE     (1<<4)
#define USB_EP_STALL      (1<<3)
#define USB_EP_SETUP      (1<<2)
#define USB_EP_EMPTY      (1<<1)
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

#define TEST100 *((uint32_t volatile *)0xD0000000)
#define SDRAM_CTRL *((uint32_t volatile *)0xD0000010)
#define SDRAM_ENABLE_bm (1<<0)

#define SDRAM_DMA_RDADDR *((uint32_t volatile *)0xD0000020)
#define SDRAM_DMA_RDSTATUS *((uint32_t volatile *)0xD0000024)
#define SDRAM_DMA_WRADDR *((uint32_t volatile *)0xD0000028)
#define SDRAM_DMA_WRSTATUS *((uint32_t volatile *)0xD000002C)
#define SDRAM_DMA_ENABLED_bm (1<<0)
#define SDRAM_DMA_BUF_EMPTY_bm (1<<1)
#define SDRAM_DMA_BUF_BUSY_bm (1<<2)

#define SDRAM ((uint32_t volatile *)0xD1000000)

bool usb_dbg_enabled = false;

static bool rxready()
{
	return usb_dbg_enabled && (USB_EP1_OUT_STATUS & USB_EP_EMPTY) == 0;
}

uint8_t usb_dbg_pos = 0;

static uint8_t recv()
{
	while (!rxready())
	{
	}

	uint8_t ch = USB_EP1_OUT[usb_dbg_pos++];
	if (usb_dbg_pos == USB_EP1_OUT_CNT)
	{
		USB_EP1_OUT_CTRL = USB_EP_PULL | USB_EP_PUSH;
		usb_dbg_pos = 0;
	}

	return ch;
}

uint8_t usb_dbg_tx_pos = 0;

static void send_range(char const * first, char const * last)
{
	if (!usb_dbg_enabled)
		return;

	while (first != last)
	{
		while (USB_EP1_IN_STATUS & USB_EP_FULL)
		{
		}

		while (first != last && usb_dbg_tx_pos < 64)
			USB_EP1_IN[usb_dbg_tx_pos++] = *first++;

		if ((USB_EP1_IN_STATUS & USB_EP_EMPTY) || usb_dbg_tx_pos == 64)
		{
			USB_EP1_IN_CNT = usb_dbg_tx_pos;
			USB_EP1_IN_CTRL = USB_EP_PUSH;
			usb_dbg_tx_pos = 0;
		}
	}
}

static void sendch(char ch)
{
	send_range(&ch, &ch + 1);
}

static void send(char const * str)
{
	char const * end = str;
	while (*end != 0)
		++end;
	send_range(str, end);
}

template <typename T>
static void sendhex(T n)
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

template <typename T>
static void sendhex(char *& res, T n)
{
	uint8_t const * p = (uint8_t const *)&n;
	uint8_t const * pend = (uint8_t const *)&n + sizeof n;
	while (p != pend)
	{
		--pend;

		static char const digits[] = "0123456789abcdef";
		*res++ = digits[*pend >> 4];
		*res++ = digits[*pend & 0xf];
	}
}

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
		usb_dbg_enabled = false;
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
				usb_dbg_enabled = (m_config == 1);
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

template <typename T>
T load_le(uint8_t const * p, uint8_t size = sizeof(T))
{
	T res = 0;
	p += size;
	while (size--)
		res = (res << 8) | *--p;
	return res;
}

class usb_omicron_handler
	: public usb_control_handler
{
public:
	void on_usb_reset()
	{
	}

	void commit_write(usb_ctrl_req_t & req)
	{
	}

	bool on_control_transfer(usb_ctrl_req_t & req)
	{
		switch (req.cmd())
		{
		case cmd_set_wraddr:
		case cmd_set_rdaddr:
			if (req.wLength == 4)
				return true;
			break;
		}

		return false;
	}

	void on_data_out(usb_ctrl_req_t & req, uint8_t const * p, uint8_t len)
	{
		switch (req.cmd())
		{
		case cmd_set_wraddr:
			if (len == 4)
			{
				USB_EP2_OUT_CTRL = USB_EP_PAUSE_SET;

				while (!(SDRAM_DMA_WRSTATUS & SDRAM_DMA_BUF_EMPTY_bm))
				{
				}

				SDRAM_DMA_WRADDR = load_le<uint32_t>(p);
				USB_EP2_OUT_CTRL = USB_EP_PAUSE_CLR;
			}
			break;
		case cmd_set_rdaddr:
			if (len == 4)
			{
				USB_EP2_IN_CTRL = USB_EP_PAUSE_SET;
				SDRAM_DMA_RDSTATUS = 0;

				while (USB_EP2_IN_STATUS & USB_EP_TRANSIT_bm)
				{
				}

				while (SDRAM_DMA_RDSTATUS & SDRAM_DMA_BUF_BUSY_bm)
				{
				}

				while (!(USB_EP2_IN_STATUS & USB_EP_EMPTY))
				{
					USB_EP2_IN_CTRL = USB_EP_PULL;
				}

				SDRAM_DMA_RDADDR = load_le<uint32_t>(p);

				SDRAM_DMA_RDSTATUS = SDRAM_DMA_ENABLED_bm;
				USB_EP2_IN_CTRL = USB_EP_PAUSE_CLR;
			}
			break;
		}
	}

	uint8_t on_data_in(usb_ctrl_req_t & req, uint8_t * p)
	{
		return 0;
	}

private:
	enum
	{
		cmd_set_wraddr = 0x2101,
		cmd_set_rdaddr = 0x2102,
	};
};


int main()
{
	USB_CTRL = USB_CTRL_ATTACH;
	SDRAM_CTRL = SDRAM_ENABLE_bm;
	LEDBITS = 0;

	dfu_handler dh;
	usb_core_handler uc;
	usb_omicron_handler oh;
	usb_control_handler * usb_handler = 0;
	usb_ctrl_req_t usb_req;

	bool last_reset_state = false;

	bool enable_setup_print = false;

	for (;;)
	{
		if (rxready())
		{
			switch (recv())
			{
			case 'b':
				LEDBITS ^= 1;
				break;
			case 'w':
				TEST100 = 0x12345678;
			case 'r':
				sendch('r');
				sendhex(TEST100);
				sendch('\n');
				break;
			case 'P':
				SDRAM_CTRL = SDRAM_ENABLE_bm;
				break;
			case 'p':
				SDRAM_CTRL = 0;
				break;
			case 'x':
				SDRAM_DMA_RDADDR = 0;
				break;
			case 'L':
				dh.reconfigure();
				break;
			case 'h':
				SDRAM_DMA_RDADDR = 0x142536;
				SDRAM_DMA_WRADDR = 0x415263;
				break;
			case 'D':
				enable_setup_print = !enable_setup_print;
				break;
			default:
				send("omicron analyzer -- DFU loader");
				send("\nSDRAM_CTRL: ");
				sendhex(SDRAM_CTRL);
				send("\nEP2: ");
				sendhex(USB_EP2_IN_STATUS);
				sendch(' ');
				sendhex(USB_EP2_OUT_STATUS);
				send("\nSDRAM_DMA_RDADDR: ");
				sendhex(SDRAM_DMA_RDADDR);
				send("\nSDRAM_DMA_RDSTATUS: ");
				sendhex(SDRAM_DMA_RDSTATUS);
				send("\nSDRAM_DMA_WRADDR: ");
				sendhex(SDRAM_DMA_WRADDR);
				send("\nSDRAM_DMA_WRSTATUS: ");
				sendhex(SDRAM_DMA_WRSTATUS);
				send("\nbL?\n");
			}
		}

		dh.process();

		if (USB_CTRL & USB_CTRL_RST)
		{
			USB_ADDRESS = 0;
			USB_CTRL |= USB_CTRL_RST_CLR;
			USB_EP0_OUT_CTRL = USB_EP_STALL_SET;
			USB_EP0_IN_CTRL = USB_EP_STALL_SET | USB_EP_SETUP_CLR;
			USB_EP1_IN_CTRL = USB_EP_TOGGLE_CLR;
			USB_EP1_OUT_CTRL = USB_EP_TOGGLE_CLR | USB_EP_SETUP_CLR | USB_EP_PUSH;
			USB_EP1_IN_CNT = 0;
			USB_EP2_IN_CTRL = USB_EP_TOGGLE_CLR;
			USB_EP2_OUT_CTRL = USB_EP_TOGGLE_CLR;

			if (!last_reset_state)
			{
				uc.on_usb_reset();
				dh.on_usb_reset();
				oh.on_usb_reset();
				usb_handler = 0;

				uint8_t ds = dh.is_dfu_mode()? 1: 0;
				uc.set_desc_set(ds);
				last_reset_state = true;
			}

			LEDBITS |= 2;
		}
		else
		{
			last_reset_state = false;
			LEDBITS &= ~2;
		}

		if ((USB_EP1_IN_STATUS & USB_EP_EMPTY) && usb_dbg_tx_pos)
		{
			USB_EP1_IN_CNT = usb_dbg_tx_pos;
			USB_EP1_IN_CTRL = USB_EP_PUSH;
			usb_dbg_tx_pos = 0;
		}

		if (usb_handler && (USB_EP0_IN_STATUS & USB_EP_EMPTY) != 0)
		{
			if (usb_req.is_write() && !usb_req.wLength)
			{
				usb_handler->commit_write(usb_req);
				usb_handler = 0;
			}
		}

		if (usb_handler && (USB_EP0_IN_STATUS & USB_EP_FULL) == 0)
		{
			if (usb_req.is_read() && usb_req.wLength)
			{
				uint8_t len = usb_handler->on_data_in(usb_req, (uint8_t *)USB_EP0_IN);
				USB_EP0_IN_CNT = len;
				USB_EP0_IN_CTRL = USB_EP_PUSH;
				usb_req.wLength -= len;
			}
		}

		if (usb_handler && usb_req.is_write() && (USB_EP0_OUT_CTRL & USB_EP_EMPTY) == 0)
		{
			uint8_t cnt = USB_EP0_OUT_CNT;
			if (cnt > usb_req.wLength)
			{
				USB_EP0_OUT_CTRL = USB_EP_STALL_SET;
				USB_EP0_IN_CTRL = USB_EP_STALL_SET;
			}
			else
			{
				assert(usb_req.wLength);
				usb_handler->on_data_out(usb_req, (uint8_t const *)USB_EP0_OUT, cnt);

				if ((usb_req.wLength -= cnt) != 0)
				{
					USB_EP0_OUT_CTRL = USB_EP_PULL | USB_EP_PUSH;
				}
				else
				{
					usb_handler->on_data_out(usb_req, 0, 0);
					USB_EP0_OUT_CTRL = USB_EP_STALL_SET;
					USB_EP0_IN_CTRL = USB_EP_PUSH;
				}
			}
		}

		if (USB_EP0_OUT_CTRL & USB_EP_SETUP)
		{
			if (usb_handler && usb_req.is_write())
				usb_handler->commit_write(usb_req);
			usb_handler = 0;

			memcpy(&usb_req, (void const *)USB_EP0_OUT, 8);

			USB_EP0_IN_CTRL = USB_EP_TOGGLE_SET;
			USB_EP0_OUT_CTRL = USB_EP_TOGGLE_SET | USB_EP_SETUP_CLR;

			if (enable_setup_print)
			{
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
			}

			if ((usb_req.bmRequestType & 0x1f) == 0)
			{
				if (uc.on_control_transfer(usb_req))
					usb_handler = &uc;
			}
			else if ((usb_req.bmRequestType & 0x1f) == 1 && usb_req.wIndex == 2)
			{
				if (oh.on_control_transfer(usb_req))
					usb_handler = &oh;
			}
			else if ((usb_req.bmRequestType & 0x1f) == 1 && usb_req.wIndex == 0)
			{
				if (dh.on_control_transfer(usb_req))
					usb_handler = &dh;
			}

			if (!usb_handler)
			{
				USB_EP0_OUT_CTRL = USB_EP_STALL_SET;
				USB_EP0_IN_CTRL = USB_EP_STALL_SET;
			}
			else if (usb_req.is_write())
			{
				USB_EP0_IN_CNT = 0;
				if (usb_req.wLength)
				{
					USB_EP0_OUT_CTRL = USB_EP_PUSH;
				}
				else
				{
					USB_EP0_OUT_CTRL = USB_EP_STALL_SET;
					USB_EP0_IN_CTRL = USB_EP_PUSH;
				}
			}
			else
			{
				assert(usb_req.is_read());
				USB_EP0_OUT_CTRL = USB_EP_PUSH;
			}
		}
	}

	return 0;
}
