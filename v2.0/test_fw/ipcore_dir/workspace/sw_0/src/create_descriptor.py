import struct, sys, os, os.path
from uuid import UUID

from usb_desc import *
usb_desc = {
    'comment': 'run-mode descriptor',
    0x100: DeviceDescriptor(
        bcdUSB=0x110,
        bDeviceClass=0xff,
        bDeviceSubClass=0xff,
        bDeviceProtocol=0xff,
        bMaxPacketSize0=64,
        idVendor=0x4a61,
        idProduct=0x679c,
        bcdDevice=0x0203,
        iManufacturer=0,
        iProduct=1,
        iSerialNumber=2,
        bNumConfigurations=1
        ),
    0x200: ConfigurationDescriptor(
        bConfigurationValue=1,
        bmAttributes=ConfigurationAttributes.Sig,
        bMaxPower=50,
        interfaces=[
            InterfaceDescriptor(
                bInterfaceNumber=0,
                bInterfaceClass=0xFE,
                bInterfaceSubClass=0x01,
                bInterfaceProtocol=0x01,
                iInterface=4,
                endpoints=[],
                functional=[
                    DfuDescriptor(
                        canDnload=True,
                        canUpload=True,
                        manifestationTolerant=True,
                        willDetach=False,
                        wTransferSize=256
                        )
                    ]
                ),
            InterfaceDescriptor(
                bInterfaceNumber=1,
                bInterfaceClass=0x0A,
                bInterfaceSubClass=0,
                bInterfaceProtocol=0,
                iInterface=3,
                endpoints=[
                    EndpointDescriptor(
                        bEndpointAddress=1 | Endpoint.In,
                        bmAttributes=Endpoint.Bulk,
                        wMaxPacketSize=64,
                        bInterval=16),
                    EndpointDescriptor(
                        bEndpointAddress=1,
                        bmAttributes=Endpoint.Bulk,
                        wMaxPacketSize=64,
                        bInterval=16)
                    ]
                ),
            ]
        ),
    0x300: LangidsDescriptor([0x409]),
    0x301: StringDescriptor('omicron'),
    0x303: StringDescriptor('debug'),
    0x304: StringDescriptor('omicron dfu'),
    }

dfu_desc = {
    'comment': 'DFU-mode descriptor',
    0x100: DeviceDescriptor(
        bcdUSB=0x110,
        bDeviceClass=0xff,
        bDeviceSubClass=0xff,
        bDeviceProtocol=0xff,
        bMaxPacketSize0=64,
        idVendor=0x4a61,
        idProduct=0x679c,
        bcdDevice=0x0203,
        iManufacturer=0,
        iProduct=1,
        iSerialNumber=2,
        bNumConfigurations=1
        ),
    0x200: ConfigurationDescriptor(
        bConfigurationValue=1,
        bmAttributes=ConfigurationAttributes.Sig,
        bMaxPower=50,
        interfaces=[
            InterfaceDescriptor(
                bInterfaceNumber=0,
                bInterfaceClass=0xFE,
                bInterfaceSubClass=0x01,
                bInterfaceProtocol=0x02,
                iInterface=4,
                endpoints=[],
                functional=[
                    DfuDescriptor(
                        canDnload=True,
                        canUpload=True,
                        manifestationTolerant=True,
                        willDetach=False,
                        wTransferSize=256
                        )
                    ]
                )
            ]
        ),
    0x300: LangidsDescriptor([0x409]),
    0x301: StringDescriptor('omicron'),
    0x303: StringDescriptor('debug'),
    0x304: StringDescriptor('omicron dfu'),
    }

if __name__ == '__main__':
    if len(sys.argv) < 2:
        fout = sys.stdout
    else:
        fout = open(sys.argv[1], 'w')
    print_descriptors(fout, [usb_desc, dfu_desc])
    fout.close()
