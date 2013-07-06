import sys, os, os.path, re

class Port:
    In = 0
    Out = 1
    InOut = 2

    def __init__(self, dir, name, upper=None, lower=None):
        if isinstance(dir, str):
            if dir == 'input':
                self.dir = Port.In
            elif dir == 'output':
                self.dir = Port.Out
            else:
                self.dir = Port.InOut
        else:
            self.dir = dir
        self.name = name
        self.upper = upper
        self.lower = lower

    def format_range(self):
        return '[%d:%d]' % (self.upper, self.lower) if self.upper is not None else ''

    def __repr__(self):
        if self.dir == Port.In:
            d = 'Port.In'
        elif self.dir == Port.Out:
            d = 'Port.Out'
        else:
            d = 'Port.InOut'
        if self.upper is not None:
            return 'Port(%s, %r, %r, %r)' % (d, self.name, self.upper, self.lower)
        else:
            return 'Port(%s, %r)' % (d, self.name)

    def __str__(self):
        if self.dir == Port.In:
            d = 'input'
        elif self.dir == Port.Out:
            d = 'output'
        else:
            d = 'inout'
        return '%s%s %s' % (d, self.format_range(), self.name)

    def has_range(self):
        return self.upper is not None

class Module:
    def __init__(self, name, ports=[]):
        self.name = name
        self.ports = list(ports)

    def add_port(self, port):
        self.ports.append(port)

    def __repr__(self):
        return 'Module(%r, %r)' % (self.name, self.ports)

    def __str__(self):
        return 'module %s(\n    ' % self.name + ',\n    '.join((str(port) for port in self.ports)) + ');'

def _process_file(filename, mods):
    with open(filename, 'r') as fin:
        contents = fin.read()

    for m in re.finditer(r'\bmodule\s*(\w+)\((.*?)\)\s*;', contents, re.S):
        mod = Module(m.group(1))

        for m2 in re.finditer(r'(input|output|inout)(?:\s+reg|)(?:\s*\[(\d+):(\d+)\]|\s)\s*(\w+)', m.group(2), re.S):
            if m2.group(2) is None:
                p = Port(
                    m2.group(1),
                    m2.group(4));
            else:
                p = Port(
                    m2.group(1),
                    m2.group(4),
                    int(m2.group(2)),
                    int(m2.group(3)));
            mod.add_port(p)

        mods[mod.name] = mod

class AxiInstance:
    def __init__(self, mod, name):
        self.mod = mod
        self.name = name

class AxiBus:
    def __init__(self, name, masters=[], slaves=[], data_width=32, addr_width=32):
        self.name = name
        self.masters = masters
        self.slaves = slaves
        self.data_width = data_width
        self.addr_width = addr_width
        self.extern = False

class AxiConnection:
    def __init__(self, inst, addr=None):
        if '.' in inst:
            self.inst, self.axi_port_name = inst.split('.', 1)
            self.port_prefix = self.axi_port_name + '_'
        else:
            self.inst = inst
            self.axi_port_name = ''
            self.port_prefix = ''
        self.addr = addr

class AxiSpecs:
    def __init__(self, name, insts, busses, module_params):
        self.name = name
        self.insts = insts
        self.busses = busses
        self.module_params = module_params

class AxiPort(object):
    port_names = [
        'awvalid', 'awready', 'awaddr',
        'wvalid', 'wready', 'wdata', 'wstrb',
        'bvalid', 'bready',
        'arvalid', 'arready', 'araddr',
        'rvalid', 'rready', 'rdata']

    def __init__(self):
        self.ports = dict(((port_name, None) for port_name in AxiPort.port_names))

    def __getattr__(self, name):
        return self.ports[name]

#    def __setattr__(self, name, value):
#        ports = object.__getattr__(self, 'ports')
#        if name not in ports:
#            object.__setattr__(self, name, value)
#        else:
#            ports[name] = value

def _make_axi_port(mod, prefix):
    axi_port = AxiPort()
    for port in mod.ports:
        if not port.name.startswith(prefix):
            continue
        port_name = port.name[len(prefix):]
        if port_name in AxiPort.port_names:
            axi_port.ports[port_name] = port
    return axi_port

class AxiSpecsFormatError(RuntimeError):
    pass

def parse_axi_specs(fin, name):
    def _params(toks):
        for tok in toks:
            s = tok.split('=', 1)
            if len(s) == 1:
                yield s[0], ''
            else:
                yield s

    bus = None
    busses = []
    insts = {}
    module_params = {}
    for line in fin:
        line = line.strip().rstrip(':')
        if line.startswith('#'):
            continue

        toks = line.split()
        if not toks:
            continue

        if toks[0] == 'module':
            name = toks[1]
            module_params.update(_params(toks[2:]))
        elif toks[0] == 'inst':
            if len(toks) != 3:
                raise AxiSpecsFormatError('''Expected 'inst <module> <name>' instead of %r''' % line.strip())
            inst = AxiInstance(toks[1], toks[2])
            insts[toks[2]] = inst
        elif toks[0] == 'bus':
            bus = AxiBus(toks[1])
            busses.append(bus)
            for k, v in _params(toks[2:]):
                if k == 'data_width':
                    bus.data_width = int(v)
                elif k == 'addr_width':
                    bus.addr_width = int(v)
                elif k == 'extern':
                    bus.extern = v
                else:
                    raise AxiSpecsFormatError('''Unknown attribute for a bus: %r''' % k)
        elif toks[0] == 'master':
            bus.masters.append(AxiConnection(toks[1]))
        elif toks[0] == 'slave':
            bus.slaves.append(AxiConnection(toks[1], int(toks[2], 0)))
        else:
            raise AxiSpecsFormatError('''Expected command: %r''' % line.strip())

    return AxiSpecs(name, insts, busses, module_params)

def _gen_interconnect(mods, specs):
    clocks = []
    top_ports = []
    needs_global_clock = False

    reset_signal_name = specs.module_params.get('reset')
    if not reset_signal_name:
        reset_signal_name = specs.module_params.get('reset_n', 'rst_n')
        reset_expr = '!' + reset_signal_name
    else:
        reset_expr = reset_signal_name

    reset_signal = Port(Port.In, reset_signal_name)
    top_ports.append(reset_signal)

    # identify each port in every instance,
    # prepare the list of clocks, external ports and
    # the list of interconnect signals required.
    for inst in specs.insts.itervalues():
        inst.port_map = {}
        mod = mods[inst.mod]
        for port in mod.ports:
            port_name = port.name.lower()
            if port_name in ('rst', 'reset', 'areset', 'arst'):
                inst.port_map[port_name] = reset_expr
            elif port_name in ('rst_n', 'reset_n', 'areset_n', 'arst_n'):
                if reset_expr.startswith('!'):
                    inst.port_map[port_name] = reset_expr[1:]
                else:
                    inst.port_map[port_name] = '!' + reset_expr
            elif port_name in ('clk', 'clock'):
                inst.port_map[port_name] = '$global_clock'
                needs_global_clock = True
            elif port_name.startswith('clk_'):
                clk = 'clk_' + port_name[4:]
                inst.port_map[port_name] = clk
                clocks.append(clk)
            elif port_name.startswith('clock_'):
                clk = 'clk_' + port_name[6:]
                inst.port_map[port_name] = clk
                clocks.append(clk)

    global_clock = specs.module_params.get('clock')
    if global_clock is None and needs_global_clock:
        if not clocks:
            global_clock = 'clk'
            clocks.insert(0, 'clk')
        elif len(clocks) == 1:
            global_clock = clocks[0]
        else:
            raise AxiSpecsFormatError('''There is no global clock specified''')
    elif needs_global_clock and global_clock not in clocks:
        clocks.insert(0, global_clock)

    for inst in specs.insts.itervalues():
        for pk in inst.port_map:
            if inst.port_map[pk] == '$global_clock':
                inst.port_map[pk] = global_clock

    for clock in clocks:
        top_ports.append(Port(Port.In, clock))

    wires = []
    processes = []
    for bus in specs.busses:
        if len(bus.masters) != 1:
            raise AxiSpecsFormatError('''An AXI bus must currently have exactly one master''')
        master = bus.masters[0]
        master_inst = specs.insts[master.inst]
        master_mod = mods[master_inst.mod]
        axi_port = _make_axi_port(master_mod, master.port_prefix)
        for port_name, port in axi_port.ports.iteritems():
            if not port:
                continue
            if bus.extern is not None:
                prefix = '%s_' % bus.extern if bus.extern else ''
                top_ports.append(Port(port.dir, '%s%s' % (prefix, port.name), port.upper, port.lower))
                if port.dir == Port.Out:
                    processes.append('assign %s%s = %s_%s;' % (prefix, port.name, bus.name, port.name))
                else:
                    print port
            else:
                wires.append('wire%s %s_%s;' % (port.format_range(), bus.name, port.name))
            master_inst.port_map[port.name] = '%s_%s' % (bus.name, port.name)

        wredies = []
        arredies = []
        rdatas = []

        maxi = axi_port
        for slave in bus.slaves:
            inst = specs.insts[slave.inst]
            mod = mods[inst.mod]
            saxi = _make_axi_port(mod, slave.port_prefix)

            if saxi.awaddr and maxi.awaddr:
                assert saxi.wdata.upper <= maxi.wdata.upper # XXX: data width conversions
                addr_width = min(saxi.awaddr.upper, maxi.awaddr.upper)
                inst.port_map[saxi.awaddr.name] = '%s_%s[%d:0]' % (bus.name, maxi.awaddr.name, addr_width)
                inst.port_map[saxi.wdata.name] = '%s_%s[%d:0]' % (bus.name, maxi.wdata.name, saxi.wdata.upper)
                inst.port_map[saxi.wvalid.name] = (
                    '%s_%s && (%s_%s[%d:%d] == %d\'h%x)' % (
                        bus.name,
                        maxi.wvalid.name,
                        bus.name,
                        maxi.awaddr.name,
                        maxi.awaddr.upper,
                        addr_width+1,
                        maxi.awaddr.upper - addr_width,
                        slave.addr >> (addr_width+1)))
                if saxi.wready:
                    wready = '%s_%s' % (inst.name, saxi.wready.name)
                    wires.append('wire %s;' % wready)
                    inst.port_map[saxi.wready.name] = wready

                    wredies.append('''if (%s_%s[%d:%d] == %d'h%x)\n        %s_%s = %s_%s;\n    else''' % (
                        bus.name,
                        maxi.awaddr.name,
                        maxi.awaddr.upper,
                        addr_width+1,
                        maxi.awaddr.upper - saxi.awaddr.upper,
                        slave.addr >> (addr_width+1),
                        bus.name,
                        maxi.wready.name,
                        inst.name,
                        saxi.wready.name))

            if saxi.araddr and maxi.araddr:
                addr_width = min(saxi.araddr.upper, maxi.araddr.upper)
                inst.port_map[saxi.araddr.name] = '%s_%s[%d:0]' % (bus.name, maxi.araddr.name, addr_width)

                rdata = '%s_%s' % (inst.name, maxi.rdata.name)
                wires.append('wire%s %s;' % (saxi.rdata.format_range(), rdata))
                inst.port_map[saxi.rdata.name] = '%s%s' % (rdata, saxi.rdata.format_range())

                rdatas.append('''if (%s_%s) begin\n        %s_%s = %s_%s;\n        %s_%s = 1'b1;\n    end else''' % (
                    inst.name,
                    saxi.rvalid.name,
                    bus.name,
                    maxi.rdata.name,
                    inst.name,
                    saxi.rdata.name,
                    bus.name,
                    maxi.rvalid.name))

                inst.port_map[saxi.arvalid.name] = (
                    '%s_%s && (%s_%s[%d:%d] == %d\'h%x)' % (
                        bus.name,
                        maxi.arvalid.name,
                        bus.name,
                        maxi.araddr.name,
                        maxi.araddr.upper,
                        addr_width+1,
                        maxi.araddr.upper - addr_width,
                        slave.addr >> (addr_width+1)))

                rvalid = '%s_%s' % (inst.name, saxi.rvalid.name)
                wires.append('wire %s;' % rvalid)
                inst.port_map[saxi.rvalid.name] = rvalid

                if saxi.arready:
                    arready = '%s_%s' % (inst.name, saxi.arready.name)
                    wires.append('wire %s;' % arready)
                    inst.port_map[saxi.arready.name] = arready

                    arredies.append('''if (%s_%s[%d:%d] == %d'h%x)\n        %s_%s = %s_%s;\n    else''' % (
                        bus.name,
                        maxi.araddr.name,
                        maxi.araddr.upper,
                        addr_width+1,
                        maxi.araddr.upper - saxi.araddr.upper,
                        slave.addr >> (addr_width+1),
                        bus.name,
                        maxi.arready.name,
                        inst.name,
                        saxi.arready.name))

        processes.append('''\
always @(*) begin
    %s
        %s_%s = 1'b0;
end
''' % (' '.join(wredies), bus.name, maxi.wready.name))

        processes.append('''\
always @(*) begin
    %s
        %s_%s = 1'b0;
end
''' % (' '.join(arredies), bus.name, maxi.arready.name))

        processes.append('''\
always @(*) begin
    %s begin
        %s_%s = 1'sbx;
        %s_%s = 1'b0;
    end
end
''' % (' '.join(rdatas), bus.name, maxi.rdata.name, bus.name, maxi.rvalid.name))

    # walk all the ports that are unconnected and lead them out of the top module
    for inst in specs.insts.itervalues():
        mod = mods[inst.mod]
        for port in mod.ports:
            if port.name in inst.port_map:
                continue
            top_port = Port(port.dir, '%s_%s' % (inst.name, port.name), port.upper, port.lower)
            top_ports.append(top_port)
            inst.port_map[port.name] = top_port.name

    print 'module %s(' % (specs.name)
    print ',\n'.join(('    %s' % port for port in top_ports))
    print '    );\n'

    print '\n'.join(wires)
    print ''

    for inst in specs.insts.itervalues():
        print '%s %s(' % (inst.mod, inst.name)
        print ',\n'.join(('    .%s(%s)' % (port, expr) for port, expr in inst.port_map.iteritems()))
        print '    );\n'

    print '\n'.join(processes)

    print 'endmodule'

def _main():
    mods = {}
    for dirpath, dirnames, filenames in os.walk('.'):
        for filename in filenames:
            if os.path.splitext(filename)[1] != '.v':
                continue
            if '_test' in filename:
                continue
            _process_file(os.path.join(dirpath, filename), mods)
        if '_work' in dirnames:
            dirnames.remove('_work')

#    for mod in mods.itervalues():
#        print mod

    with open(sys.argv[1], 'r') as fin:
        specs = parse_axi_specs(fin, os.path.splitext(os.path.split(sys.argv[1])[1])[0])

    _gen_interconnect(mods, specs)

if __name__ == '__main__':
    _main()
