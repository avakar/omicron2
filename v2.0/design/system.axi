inst axi_cpu cpu0
inst sdram sdram0
inst axi_usb usb0

bus axi0 data_width=32 addr_width=32:
    master cpu0
    slave usb0   0xC2000000
    slave sdram0 0xD0000000
