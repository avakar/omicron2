import sys, base64, struct, argparse, uuid, subprocess, binascii, datetime

class HexFileError(RuntimeError):
    def __init__(self, fname, lineno, msg):
        RuntimeError.__init__(self, '%s(%d): %s' % (fname, lineno, msg))

class DeviceMemory:
    def __init__(self):
        self._chunks = []

    def add_range(self, address, data):
        for i, chunk in enumerate(self._chunks):
            chaddr, chdata = self._chunks[i]
            if address < chaddr:
                if address + len(data) > address:
                    raise RuntimeError('data overlap')
                elif address + len(data) == address:
                    self._chunks[i] = (address, data + chdata)
                    break
                else:
                    self._chunks.insert(i, (address, data))
                    break
            elif chaddr + len(chdata) == address:
                self._chunks[i] = (chaddr, chdata + data)
                chdata = self._chunks[i][1]
                while len(self._chunks) > i + 1 and self._chunks[i+1][0] == chaddr + len(chdata):
                    self._chunks[i] = (chaddr, chdata + self._chunks[i+1][1])
                    self._chunks.remove(i+1)
                    chdata = self._chunks[i][1]
                break
        else:
            self._chunks.append((address, data))

    def data(self):
        res = {}
        for chaddr, chdata in self._chunks:
            res[chaddr] = chdata
        return res

def read_hex(fin, mem):
    base_address = 0
    eof_encountered = False
    for lineno, line in enumerate(fin):
        if eof_encountered:
            raise HexFileError(fin.name, lineno + 1, 'no lines beyond the EOF record are allowed')
        if not line.startswith(':'):
            raise HexFileError(fin.name, lineno + 1, 'lines must start with a colon')
        data = base64.b16decode(line[1:-1], casefold=True)
        if ord(data[0]) + 5 != len(data):
            raise HexFileError(fin.name, lineno + 1, 'record\'s size doesn\'t match the line length')
        address, record_type = struct.unpack('>HB', data[1:4])
        checksum = ord(data[-1])
        data = data[4:-1]

        if record_type == 0:
            mem.add_range(base_address + address, data)
        elif record_type == 1:
            if len(data) != 0:
                raise HexFileError(fin.name, lineno + 1, 'eof records should contain no data')
            eof_encountered = True
        elif record_type == 2:
            if address != 0:
                raise HexFileError(fin.name, lineno + 1, 'segment address records should have address fields set to 0')
            if len(data) != 2:
                raise HexFileError(fin.name, lineno + 1, '16-bit segment address expected')
            base_address, = struct.unpack('>H', data)
        elif record_type == 4:
            if address != 0:
                raise HexFileError(fin.name, lineno + 1, 'segment address records should have address fields set to 0')
            if len(data) != 4:
                raise HexFileError(fin.name, lineno + 1, '32-bit address expected')
            base_address, = struct.unpack('>I', data)
        else:
            raise HexFileError(fin.name, lineno + 1, 'invalid record type')

def pad(data, align):
    if len(data) % align == 0:
        return data
    return data + '\x00'* (align - len(data)%align)

def _main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flash', type=argparse.FileType('rb'))
    parser.add_argument('--pic', type=argparse.FileType('r'))
    parser.add_argument('-o', '--output', type=argparse.FileType('wb'))
    args = parser.parse_args()

    res = []

    output = subprocess.check_output(['git', 'log', '-1', '--date=raw', '--pretty=format:%H %cd'])
    githash, ts, zone = output.split()
    short_hash = githash[:7]
    githash = base64.b16decode(githash, casefold=True)
    ts = int(ts)
    zone = int(zone, 10)
    zone = (zone // 100) * 60 + (zone % 100)
    ts_str = datetime.datetime.utcfromtimestamp(ts + zone*60).strftime('%Y_%m_%d')

    yb = uuid.UUID('49e8fed9-9f8d-4ff9-bc8c-c8d0f43f904f')
    res.append(struct.pack('<B16sIhH20s19s', 2, yb.get_bytes(), ts, zone, 20, githash, ''))

    if args.flash:
        data = args.flash.read()
        res.append(struct.pack('<III52s', 1, len(data), 0, ''))
        res.append(pad(data, 64))

    if args.pic:
        mem = DeviceMemory()
        read_hex(args.pic, mem)
        for chaddr, chdata in mem.data().iteritems():
            res.append(struct.pack('<III52s', 2, len(chdata), chaddr, ''))
            res.append(pad(chdata, 64))

    res.append(struct.pack('<HHHHBBBB',
        0x0203, 0x679c, 0x4a61,
        0x100, 0x55, 0x46, 0x44, 0x10))

    crc = binascii.crc32('')
    for ch in res:
        crc = binascii.crc32(ch, crc) & 0xffffffff

    res.append(struct.pack('<I', crc))

    content = ''
    if args.flash is None:
        content = '_pic'
    elif args.pic is None:
        content = '_flash'

    if subprocess.call(['git', 'diff-index', '--quiet', 'HEAD']):
        short_hash += '_dirty'

    if args.output is None:
        args.output = open('omicron20%s_%s_%s.dfu' % (content, ts_str, short_hash), 'wb')
    args.output.writelines(res)
    args.output.close()
    return 0

if __name__ == '__main__':
    sys.exit(_main())
