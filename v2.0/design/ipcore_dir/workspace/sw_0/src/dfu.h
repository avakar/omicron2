#ifndef DFU_H
#define DFU_H

class dfu_handler
{
public:
	dfu_handler()
		: m_state(appIDLE), m_action(act_none), m_spi_address(0), m_transfer_offset(0),
		  m_transfer_length(0), m_prg_state(ps_none)
	{
	}

	bool active() const
	{
		return m_state >= dfuIDLE;
	}

	void usb_reset()
	{
		if (m_state == appDETACH)
			m_state = dfuIDLE;
	}

	void usb_cmd(uint16_t cmd, uint16_t wValue, uint16_t wLength)
	{
		bool valid = false;
		m_action = act_none;

		switch (cmd)
		{
		case 0x2100: // DFU_DETACH
			if (m_state < dfuIDLE)
			{
				m_state = appDETACH;
				USB_EP0_IN_CTRL = USB_EP_IN_CNT(0) | USB_EP_FULL;
				USB_EP0_OUT_CTRL = USB_EP_STALL;
				valid = true;
			}
			break;
		case 0x2101: // DFU_DNLOAD
			if (m_state == dfuIDLE || m_state == dfuDNLOAD_IDLE)
			{
				USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
				if (wLength == 0)
				{
					USB_EP0_IN_CTRL = USB_EP_IN_CNT(0) | USB_EP_FULL;
					m_state = dfuMANIFEST_SYNC;
				}
				else
				{
					m_transfer_offset = 0;
					m_transfer_length = wLength;
					m_action = act_download;
				}
				valid = true;
			}
			break;
		case 0xa102: // DFU_UPLOAD
			if (wLength != 0 && (m_state == dfuIDLE || m_state == dfuUPLOAD_IDLE))
			{
				m_action = act_upload;
				m_transfer_offset = 0;
				m_transfer_length = wLength;
				if (m_state == dfuIDLE)
				{
					m_spi_address = 0;
					m_state = dfuUPLOAD_IDLE;
					spi_select();
					spi_tran(3);
					spi_tran(0);
					spi_tran(0);
					spi_tran(0);
				}
				valid = true;
			}
			break;
		case 0xa103: // DFU_GETSTATUS
			if (wLength == 6)
			{
				if (m_state == dfuDNLOAD_SYNC)
					this->process_dndata();

				if (m_state == dfuMANIFEST_SYNC)
					this->manifest();

				uint8_t volatile * p = USB_EP0_IN;
				*p++ = 0;
				*p++ = 1;
				*p++ = 0;
				*p++ = 0;
				*p++ = m_state;
				*p++ = 0;
				USB_EP0_IN_CTRL = USB_EP_IN_CNT(6) | USB_EP_FULL;
				USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
				valid = true;
			}
			break;
		case 0x2104: // DFU_CLRSTATUS
			if (wLength == 0)
			{
				if (m_state == dfuERROR)
					m_state = dfuIDLE;
				else
					m_state = dfuERROR;
				valid = true;
			}
			break;
		case 0xa105: // DFU_GETSTATE
			if (wLength == 1)
			{
				USB_EP0_IN[0] = m_state;
				USB_EP0_IN_CTRL = USB_EP_IN_CNT(1) | USB_EP_FULL;
				USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
				valid = true;
			}
			break;
		case 0x2106: // DFU_ABORT
			spi_unselect();
			m_state = dfuIDLE;
			USB_EP0_IN_CTRL = USB_EP_IN_CNT(0) | USB_EP_FULL;
			USB_EP0_OUT_CTRL = USB_EP_STALL;
			valid = true;
			break;
		}

		if (!valid)
		{
			m_action = act_none;
			m_state = dfuERROR;
			spi_unselect();
			USB_EP0_OUT_CTRL = USB_EP_STALL;
			USB_EP0_IN_CTRL = USB_EP_STALL;
		}
	}

	void usb_out_full()
	{
		switch (m_action)
		{
		case act_none:
		case act_upload:
			break;
		case act_download:
			{
				uint8_t chunk = USB_EP_OUT_CNT(USB_EP0_OUT_CTRL);

				if (m_transfer_length - m_transfer_offset >= chunk)
				{
					memcpy(m_transfer_buffer + m_transfer_offset, (const void *)USB_EP0_OUT, chunk);
					USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;

					m_transfer_offset += chunk;
					if (m_transfer_offset == m_transfer_length)
					{
						USB_EP0_IN_CTRL = USB_EP_IN_CNT(0) | USB_EP_FULL;
						m_action = act_none;
						if (m_state == dfuIDLE)
							m_prg_state = ps_none;
						m_state = dfuDNLOAD_SYNC;
						m_transfer_offset = 0;
					}
				}
				else
				{
					m_state = dfuERROR;
					m_action = act_none;
					USB_EP0_OUT_CTRL = USB_EP_STALL;
					USB_EP0_IN_CTRL = USB_EP_STALL;
				}
			}
			break;
		}
	}

	void usb_in_empty()
	{
		switch (m_action)
		{
		case act_none:
		case act_download:
			break;
		case act_upload:
			{
				uint8_t chunk = 64;
				if (m_transfer_offset + chunk > m_transfer_length)
					chunk = m_transfer_length - m_transfer_offset;
				if (m_spi_address + chunk > flash_size)
					chunk = flash_size - m_spi_address;
				for (uint8_t i = 0; i < chunk; ++i)
					USB_EP0_IN[i] = spi_tran(0);
				USB_EP0_IN_CTRL = USB_EP_IN_CNT(chunk) | USB_EP_FULL;
				m_spi_address += chunk;
				m_transfer_offset += chunk;

				if (chunk < 64 || m_transfer_offset == m_transfer_length)
				{
					USB_EP0_OUT_CTRL = USB_EP_FULL_CLR;
					m_action = act_none;
				}

				if (chunk < 64 && m_spi_address == flash_size)
				{
					m_state = dfuIDLE;
					spi_unselect();
				}
			}
			break;
		}
	}

	void process()
	{
		if (m_state == dfuDNBUSY)
		{
			switch (m_prg_state)
			{
			case ps_none:
				break;
			case ps_prog_wait:
				if (!spi_is_busy())
				{
					this->spi_write_enable();
					spi_select();
					spi_tran(0x02);
					spi_tran(m_spi_address >> 16);
					spi_tran(m_spi_address >> 8);
					spi_tran(0);
					m_prg_state = ps_prog_in_progress;
				}
				break;
			case ps_prog_in_progress:
				{
					uint16_t remaining = 256 - (uint8_t)m_spi_address;
					while (remaining && m_transfer_offset != m_transfer_length)
					{
						spi_tran(m_transfer_buffer[m_transfer_offset]);
						++m_transfer_offset;
						--remaining;
						++m_spi_address;
					}

					if (!remaining)
					{
						spi_unselect();
						m_prg_state = ps_prog_wait;
					}

					if (m_transfer_offset == m_transfer_length)
						m_state = dfuDNLOAD_IDLE;
				}
				break;
			}
		}

		if (m_state == dfuMANIFEST)
		{
			if (!spi_is_busy())
			{
				m_state = dfuMANIFEST_SYNC;
				m_prg_state = ps_none;
			}
		}
	}

private:
	void process_dndata()
	{
		m_state = dfuDNBUSY;
		switch (m_prg_state)
		{
		case ps_none:
			m_spi_address = 0;
			this->spi_write_enable();
			this->spi_chip_erase();
			m_prg_state = ps_prog_wait;
			break;
		case ps_prog_wait:
		case ps_prog_in_progress:
			break;
		}
	}

	void manifest()
	{
		switch (m_prg_state)
		{
		case ps_none:
			m_state = dfuIDLE;
			break;
		case ps_prog_in_progress:
		case ps_prog_wait:
			spi_unselect();
			m_state = dfuMANIFEST;
			break;
		}
	}

	void spi_write_enable()
	{
		spi_select();
		spi_tran(0x06);
		spi_unselect();
	}

	void spi_chip_erase()
	{
		spi_select();
		spi_tran(0xC7);
		spi_unselect();
	}

	bool spi_is_busy()
	{
		spi_select();
		spi_tran(0x05);
		uint8_t status = spi_tran(0);
		spi_unselect();
		return (status & (1<<0)) != 0;
	}

	static uint32_t const flash_size = 524288;

	enum state_t
	{
		appIDLE = 0,
		appDETACH = 1,
		dfuIDLE = 2,
		dfuDNLOAD_SYNC = 3,
		dfuDNBUSY = 4,
		dfuDNLOAD_IDLE = 5,
		dfuMANIFEST_SYNC = 6,
		dfuMANIFEST = 7,
		dfuMANIFEST_WAIT_RESET = 8,
		dfuUPLOAD_IDLE = 9,
		dfuERROR = 10
	};

	enum program_state_t
	{
		ps_none,
		ps_prog_wait,
		ps_prog_in_progress,
	};

	enum action_t
	{
		act_none,
		act_upload,
		act_download,
	};

	state_t m_state;
	action_t m_action;

	uint32_t m_spi_address;
	uint16_t m_transfer_offset;
	uint16_t m_transfer_length;
	uint8_t m_transfer_buffer[4096];
	program_state_t m_prg_state;
};

#endif // DFU_H
