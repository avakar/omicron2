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

#define USB_EP2_OUT_CTRL *((uint8_t volatile *)0xC0000048)
#define USB_EP2_OUT_STATUS *((uint8_t const volatile *)0xC0000048)
#define USB_EP2_OUT_CNT *((uint8_t volatile *)0xC0000049)
#define USB_EP2_IN_CTRL *((uint8_t volatile *)0xC000004C)
#define USB_EP2_IN_STATUS *((uint8_t const volatile *)0xC000004C)
#define USB_EP2_IN_CNT (*((uint8_t volatile *)0xC000004D))
#define USB_EP2_OUT ((uint8_t volatile *)0xC0001100)
#define USB_EP2_IN ((uint8_t volatile *)0xC0001140)

#define USB_EP3_OUT_CTRL *((uint8_t volatile *)0xC0000040)
#define USB_EP3_OUT_STATUS *((uint8_t const volatile *)0xC0000040)
#define USB_EP3_IN_CTRL *((uint8_t volatile *)0xC0000044)
#define USB_EP3_IN_STATUS *((uint8_t const volatile *)0xC0000044)

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

#define SDRAM_DMA_CTRL *((uint32_t volatile *)0xD0000014)
#define SDRAM_DMA_CHOKED_bm (1<<1)
#define SDRAM_DMA_CHOKE_ENABLE_bm (1<<2)
#define SDRAM_DMA_UNCHOKE_bm (1<<3)
#define SDRAM_DMA_CHOKE_bm (1<<4)
#define SDRAM_DMA_CLEAR_MARKER_STATE_bm (1<<5)
#define SDRAM_DMA_CHOKE_ADDR_bm 0xff00
#define SDRAM_DMA_CHOKE_ADDR_gp 8

#define SDRAM_DMA_RDADDR *((uint32_t volatile *)0xD0000020)
#define SDRAM_DMA_RDSTATUS *((uint32_t volatile *)0xD0000024)
#define SDRAM_DMA_WRADDR *((uint32_t volatile *)0xD0000028)
#define SDRAM_DMA_WRSTATUS *((uint32_t volatile *)0xD000002C)
#define SDRAM_DMA_SFADDR *((uint32_t volatile *)0xD0000030)
#define SDRAM_DMA_CURRENT_MARKER *((uint64_t volatile *)0xD0000038)
#define SDRAM_DMA_START_MARKER *((uint64_t volatile *)0xD0000040)
#define SDRAM_DMA_STOP_MARKER *((uint64_t volatile *)0xD0000048)
#define SDRAM_DMA_MARKER_IDX_bm 0x3FFFFFFFFFFF

#define SDRAM_DMA_ENABLED_bm (1<<0)
#define SDRAM_DMA_BUF_EMPTY_bm (1<<1)
#define SDRAM_DMA_BUF_BUSY_bm (1<<2)

#define SDRAM_DMA_SFADDR_PTR_bm 0xffffff
#define SDRAM_DMA_SFADDR_BUSY_bm (1<<24)

#define SDRAM ((uint32_t volatile *)0xD1000000)

#define SAMPLER_CTRL *((uint32_t volatile *)0xE0000000)
#define SAMPLER_STATUS *((uint32_t const volatile *)0xE0000000)
#define SAMPLER_TMR_PER *((uint32_t volatile *)0xE0000004)
#define SAMPLER_MUX1 *((uint32_t volatile *)0xE0000010)
#define SAMPLER_MUX2 *((uint32_t volatile *)0xE0000014)
#define SAMPLER_MUX3 *((uint32_t volatile *)0xE0000018)
#define SAMPLER_COMPRESSOR_STATE *((uint32_t volatile *)0xE0000020)
#define SAMPLER_SERIALIZER_STATE *((uint32_t volatile *)0xE0000024)
#define SAMPLER_SRC_SAMPLE_INDEX_LO *((uint32_t volatile *)0xE0000028)
#define SAMPLER_SRC_SAMPLE_INDEX_HI *((uint32_t volatile *)0xE000002C)

#define SAMPLER_ENABLE_bm (1<<0)
#define SAMPLER_CLEAR_PIPELINE_bm (1<<1)
#define SAMPLER_SET_MONITOR_bm (1<<2)
#define SAMPLER_COMPRESSOR_MONITOR_bm (1<<3)
#define SAMPLER_OVERFLOW_bm (1<<4)
#define SAMPLER_PIPELINE_BUSY_bm (1<<5)
#define SAMPLER_LOG_CHANNELS_gp 8
#define SAMPLER_LOG_CHANNELS_bm (0x700)
#define SAMPLER_EDGE_CTRL_gp 16
#define SAMPLER_EDGE_CTRL_gm 0x30000
#define SAMPLER_RISING_EDGE_bm (1<<16)
#define SAMPLER_FALLING_EDGE_bm (1<<17)


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
	virtual bool on_data_out(usb_ctrl_req_t & req, uint8_t const * p, uint8_t len) = 0;
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

	bool on_data_out(usb_ctrl_req_t & req, uint8_t const * p, uint8_t len)
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

		return true;
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

	bool on_data_out(usb_ctrl_req_t & req, uint8_t const * p, uint8_t len)
	{
		return false;
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

template <typename T>
uint8_t * store_le(uint8_t * p, T v, uint8_t size = sizeof(T))
{
	while (size--)
	{
		*p++ = (uint8_t)v;
		v = v >> 8;
	}

	return p;
}

class usb_omicron_handler
	: public usb_control_handler
{
public:
	usb_omicron_handler()
		: m_running(false), m_start_src_index(0), m_start_recv_index(0)
	{

	}

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
		case cmd_start:
			if (req.wLength == 18)
			{
				if (m_running)
					this->stop();
				return true;
			}
			break;
		case cmd_stop:
			if (req.wLength == 0)
			{
				this->stop();
				return true;
			}
			break;
		case cmd_get_sample_index:
			if (req.wLength >= 12)
				return true;
			break;
		case cmd_get_config:
			return true;
		case cmd_unchoke:
			{
				uint32_t ctrl = SDRAM_DMA_CTRL;
				if (!(SDRAM_DMA_CTRL & SDRAM_DMA_CHOKED_bm))
					return false;

				uint8_t choke_addr = (ctrl & SDRAM_DMA_CHOKE_ADDR_bm) >> SDRAM_DMA_CHOKE_ADDR_gp;
				uint32_t sfaddr = SDRAM_DMA_SFADDR & SDRAM_DMA_SFADDR_PTR_bm;

				if ((sfaddr >> 16) == choke_addr)
					return false;

				return true;
			}
		case cmd_move_choke:
			if (req.wLength == 4)
				return true;
			break;
		}

		return false;
	}

	bool on_data_out(usb_ctrl_req_t & req, uint8_t const * p, uint8_t len)
	{
		switch (req.cmd())
		{
		case cmd_set_wraddr:
			if (len)
			{
				USB_EP3_OUT_CTRL = USB_EP_PAUSE_SET;

				while (!(SDRAM_DMA_WRSTATUS & SDRAM_DMA_BUF_EMPTY_bm))
				{
				}

				SDRAM_DMA_WRADDR = load_le<uint32_t>(p);
				USB_EP3_OUT_CTRL = USB_EP_PAUSE_CLR;
			}
			return true;
		case cmd_set_rdaddr:
			if (len)
			{
				USB_EP3_IN_CTRL = USB_EP_PAUSE_SET;
				SDRAM_DMA_RDSTATUS = 0;

				while (USB_EP3_IN_STATUS & USB_EP_TRANSIT_bm)
				{
				}

				while (SDRAM_DMA_RDSTATUS & SDRAM_DMA_BUF_BUSY_bm)
				{
				}

				while (!(USB_EP3_IN_STATUS & USB_EP_EMPTY))
				{
					USB_EP3_IN_CTRL = USB_EP_PULL;
				}

				SDRAM_DMA_RDADDR = load_le<uint32_t>(p);

				SDRAM_DMA_RDSTATUS = SDRAM_DMA_ENABLED_bm;
				USB_EP3_IN_CTRL = USB_EP_PAUSE_CLR;
			}
			return true;
		case cmd_start:
			if (len)
			{
				assert(!m_running);
				if (*p > 4)
					return false;

				SAMPLER_MUX1 = load_le<uint32_t>(p + 6);
				SAMPLER_MUX2 = load_le<uint32_t>(p + 10);
				SAMPLER_MUX3 = load_le<uint32_t>(p + 14);

				this->start(
					p[0],
					load_le<uint32_t>(p + 2),
					p[1]);
			}
			return true;
		case cmd_move_choke:
			if (len)
			{
				uint32_t addr = load_le<uint32_t>(p);
				uint8_t new_choke = (addr + 0xff0000) >> 16;
				SDRAM_DMA_CTRL = (new_choke << SDRAM_DMA_CHOKE_ADDR_gp) | SDRAM_DMA_CHOKE_ENABLE_bm;
			}
			return true;
		}

		return false;
	}

	void start(uint8_t shift, uint32_t tmr, uint8_t edge_ctrl)
	{
		assert(!m_running);

		m_serializer_shift = shift;
		m_start_src_index = SAMPLER_SRC_SAMPLE_INDEX_LO;
		m_start_src_index |= (uint64_t)SAMPLER_SRC_SAMPLE_INDEX_HI << 32;

		uint32_t start_sfaddr = (SDRAM_DMA_SFADDR & SDRAM_DMA_SFADDR_PTR_bm);
		m_start_recv_index = SDRAM_DMA_CURRENT_MARKER & SDRAM_DMA_MARKER_IDX_bm;

		uint8_t choke_addr = (start_sfaddr + 0xff0000) >> 16;
		SDRAM_DMA_CTRL = (choke_addr << SDRAM_DMA_CHOKE_ADDR_gp) | SDRAM_DMA_CHOKE_ENABLE_bm | SDRAM_DMA_CHOKE_bm | SDRAM_DMA_CLEAR_MARKER_STATE_bm;

		SAMPLER_TMR_PER = tmr;
		SAMPLER_CTRL = (edge_ctrl << SAMPLER_EDGE_CTRL_gp) | (shift << SAMPLER_LOG_CHANNELS_gp) | SAMPLER_CLEAR_PIPELINE_bm | SAMPLER_ENABLE_bm;

		m_running = true;
	}

	uint8_t on_data_in(usb_ctrl_req_t & req, uint8_t * p)
	{
		uint8_t * p_orig = p;
		switch (req.cmd())
		{
		case cmd_get_sample_index:
			return this->get_trail(p);
		case cmd_get_config:
			p = store_le<uint8_t>(p, (m_running? 0x80: 0) | m_serializer_shift);
			p = store_le<uint8_t>(p, (SAMPLER_CTRL & SAMPLER_EDGE_CTRL_gm) >> SAMPLER_EDGE_CTRL_gp);
			p = store_le(p, SAMPLER_TMR_PER);
			p = store_le(p, SAMPLER_MUX1);
			p = store_le(p, SAMPLER_MUX2);
			p = store_le(p, SAMPLER_MUX3);
			break;
		case cmd_unchoke:
			p = store_le(p, SDRAM_DMA_SFADDR & SDRAM_DMA_SFADDR_PTR_bm);
			SDRAM_DMA_CTRL |= SDRAM_DMA_UNCHOKE_bm;
			p = store_le(p, SDRAM_DMA_START_MARKER);
			break;
		}
		return p - p_orig;
	}

	uint8_t get_trail(uint8_t * p)
	{
		uint64_t src_idx = SAMPLER_SRC_SAMPLE_INDEX_LO;
		src_idx |= ((uint64_t)SAMPLER_SRC_SAMPLE_INDEX_HI<<32);
		src_idx -= m_start_src_index;

	restart:
		SAMPLER_CTRL = SAMPLER_CTRL | SAMPLER_SET_MONITOR_bm;
		uint32_t sfaddr = SDRAM_DMA_SFADDR;
		uint64_t recv_idx = SDRAM_DMA_CURRENT_MARKER & SDRAM_DMA_MARKER_IDX_bm;
		recv_idx -= m_start_recv_index;
		recv_idx <<= 4 - m_serializer_shift;

	restart2:
		uint8_t * cur = p;

		cur = store_le<uint32_t>(cur, sfaddr & SDRAM_DMA_SFADDR_PTR_bm);
		if (SDRAM_DMA_CTRL & SDRAM_DMA_CHOKED_bm)
		{
			cur = store_le<uint64_t>(cur, SDRAM_DMA_STOP_MARKER);
			return cur - p;
		}

		cur = store_le<uint64_t>(cur, recv_idx);

		if (recv_idx >= src_idx)
		{
			*cur++ = 0;
			*cur++ = 0;
			return cur - p;
		}

		if (sfaddr & SDRAM_DMA_SFADDR_BUSY_bm)
			goto restart;

		uint32_t compressor_state = SAMPLER_COMPRESSOR_STATE;
		uint32_t compressor_samples;
		switch ((compressor_state >> 16) & 0x3)
		{
		case 0:
		case 1:
			*cur++ = 0;
			compressor_samples = 0;
			break;
		case 2:
			compressor_samples = (compressor_state & 0xffff);
			*cur++ = 2;
			*cur++ = compressor_samples;
			*cur++ = compressor_samples >> 8;
			break;
		case 3:
			goto restart;
		}

		compressor_samples <<= 4 - m_serializer_shift;
		if (recv_idx + compressor_samples < src_idx)
		{
			uint32_t serializer_state = SAMPLER_SERIALIZER_STATE;
			if ((SAMPLER_STATUS & SAMPLER_COMPRESSOR_MONITOR_bm) == 0)
				goto restart;

			uint8_t ser_samples = (serializer_state >> 16) & 0xf;
			*cur++ = ser_samples;
			*cur++ = serializer_state;
			*cur++ = serializer_state >> 8;
		}
		else
		{
			*cur++ = 0;
		}

		SAMPLER_CTRL = SAMPLER_CTRL | SAMPLER_SET_MONITOR_bm;
		uint32_t sfaddr2 = SDRAM_DMA_SFADDR;
		uint64_t recv_idx2 = SDRAM_DMA_CURRENT_MARKER & SDRAM_DMA_MARKER_IDX_bm;
		recv_idx2 -= m_start_recv_index;
		recv_idx2 <<= 4 - m_serializer_shift;

		if (recv_idx2 != recv_idx || (SDRAM_DMA_CTRL & SDRAM_DMA_CHOKED_bm))
		{
			sfaddr = sfaddr2;
			recv_idx = recv_idx2;
			goto restart2;
		}

		return cur - p;
	}

	void stop()
	{
		SAMPLER_CTRL = 0;
		while (SAMPLER_STATUS & SAMPLER_PIPELINE_BUSY_bm)
		{
		}

		while (SDRAM_DMA_SFADDR & SDRAM_DMA_SFADDR_BUSY_bm)
		{
		}

		SDRAM_DMA_CTRL = SDRAM_DMA_CHOKE_bm;
		m_running = false;
	}

private:
	enum
	{
		cmd_set_wraddr = 0x4101,
		cmd_set_rdaddr = 0x4102,
		cmd_start = 0x4103,
		cmd_stop = 0x4104,
		cmd_get_sample_index = 0xc105,
		cmd_get_config = 0xc106,
		cmd_unchoke = 0xc107,
		cmd_move_choke = 0x4108,
	};

	bool m_running;
	uint8_t m_serializer_shift;
	uint64_t m_start_src_index;
	uint64_t m_start_recv_index;
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

	for (;;)
	{
		if (rxready())
		{
			switch (recv())
			{
			case 'b':
				LEDBITS ^= 1;
				break;
			case 'L':
				dh.reconfigure();
				break;
			case 'S':
				oh.start(4, 200000000, 0);
				break;
			case 's':
				oh.stop();
				break;
			case '1':
				SAMPLER_TMR_PER = 200000000;
				break;
			case '2':
				SAMPLER_TMR_PER = 2000;
				break;
			case '3':
				SAMPLER_TMR_PER = 2;
				break;
			case '4':
				SAMPLER_TMR_PER = 20;
				break;
			case '5':
				SAMPLER_TMR_PER = 200;
				break;
			case '6':
				SAMPLER_TMR_PER = 1;
				break;
			case '7':
				SAMPLER_TMR_PER = 0;
				break;
			case 'm':
				SAMPLER_MUX1 = 0x8a418820;
				break;
			case 'M':
				SAMPLER_MUX1 = 0x8a418834;
				break;
			case 't':
			{
				uint8_t buf[32];
				uint8_t s = oh.get_trail(buf);

				sendch('t');
				for (uint8_t i = 0; i < s; ++i)
					sendhex(buf[i]);
				sendch('\n');
				break;
			}
			default:
				send("omicron analyzer -- DFU loader");
				send("\nSAMPLER_STATUS: ");
				sendhex(SAMPLER_STATUS);
				send("\nbL?\n");
			}
		}

		dh.process();

		if (USB_CTRL & USB_CTRL_RST)
		{
			USB_ADDRESS = 0;
			USB_CTRL |= USB_CTRL_RST_CLR;
			USB_EP0_OUT_CTRL = USB_EP_STALL_SET | USB_EP_SETUP_CLR;
			USB_EP0_IN_CTRL = USB_EP_STALL_SET | USB_EP_SETUP_CLR;
			USB_EP1_IN_CTRL = USB_EP_TOGGLE_CLR | USB_EP_SETUP_CLR;
			USB_EP1_OUT_CTRL = USB_EP_TOGGLE_CLR | USB_EP_SETUP_CLR | USB_EP_PUSH;
			USB_EP1_IN_CNT = 0;
			USB_EP2_IN_CTRL = USB_EP_TOGGLE_CLR | USB_EP_SETUP_CLR;
			USB_EP2_OUT_CTRL = USB_EP_STALL_SET | USB_EP_SETUP_CLR;
			USB_EP3_IN_CTRL = USB_EP_TOGGLE_CLR | USB_EP_SETUP_CLR;
			USB_EP3_OUT_CTRL = USB_EP_TOGGLE_CLR | USB_EP_SETUP_CLR;

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
				usb_handler = 0;
			}
			else
			{
				assert(usb_req.wLength);
				if (!usb_handler->on_data_out(usb_req, (uint8_t const *)USB_EP0_OUT, cnt))
				{
					USB_EP0_OUT_CTRL = USB_EP_STALL_SET;
					USB_EP0_IN_CTRL = USB_EP_STALL_SET;
					usb_handler = 0;
				}
				else if ((usb_req.wLength -= cnt) != 0)
				{
					USB_EP0_OUT_CTRL = USB_EP_PULL | USB_EP_PUSH;
				}
				else
				{
					USB_EP0_OUT_CTRL = USB_EP_STALL_SET;
					if (!usb_handler->on_data_out(usb_req, 0, 0))
					{
						USB_EP0_IN_CTRL = USB_EP_STALL_SET;
						usb_handler = 0;
					}
					else
					{
						USB_EP0_IN_CTRL = USB_EP_PUSH;
					}
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

#if 0
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
#endif

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
