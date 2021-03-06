#!/usr/bin/env python
# Copyright (c) 2004 Guy Hutchison (ghutchis@opencores.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# This script generates I/O mapped control and status registers based
# on an XML configuration file.
# 

import reglib
import xml.dom.minidom
import sys
import argparse


def node_info(node):
    print("Methods:", dir(node))
    print("Child Nodes:", node.childNodes)


def create_addr_vh(filename, dg):
    fh = open(filename, 'w')
    for d in dg.ranges:
        print(repr(d))
        ba = d.get_base_addr()
        fh.write("`define %s 'h%x\n" % (d.name.upper(), ba))
    fh.close()


def create_addr_decoder(node):
    rg = reglib.decoder_group()

    rg.name = node.getAttribute("name")
    rg.addr_size = reglib.number(node.getAttribute("addr_sz"))

    data_sz = node.getAttribute("data_sz")
    if data_sz != '':
        rg.data_size = reglib.number(data_sz)

    return rg


def create_decoder_verilog(top_node):
    dg = create_addr_decoder(top_node)

    # get list of address ranges
    range_nodes = top_node.getElementsByTagName("range")
    for rn in range_nodes:
        prefix = rn.getAttribute("prefix")
        base = reglib.number(rn.getAttribute("base"))
        bits = int(rn.getAttribute("bits"))
        r = reglib.decoder_range(prefix, base, bits)
        dg.add_range(r)

    fname = dg.name + ".v"
    fh = open(fname, 'w')
    fh.write(dg.verilog())
    fh.close()
    create_addr_vh(dg.name + ".vh", dg)


def create_reg_group(node):
    rg = reglib.register_group()

    rg.name = node.getAttribute("name")
    rg.addr_size = reglib.number(node.getAttribute("addr_sz"))
    rg.base_addr = reglib.number(node.getAttribute("base_addr"))

    data_sz = node.getAttribute("data_sz")
    if data_sz != '':
        rg.data_size = reglib.number(data_sz)

    rread = node.getAttribute("registered_read")
    if data_sz != '':
        rg.registered_read = reglib.number(rread)

    return rg


def create_register(rg, node):
    params = {}
    params['name'] = node.getAttribute("name")
    typ = node.getAttribute("type")
    width = node.getAttribute("width")
    if width == '':
        params['width'] = 1
    else:
        params['width'] = int(width)
    params['default'] = node.getAttribute("default")
    params['int_value'] = node.getAttribute("int_value")
    address = node.getAttribute("address")
    if address != '':
        params['address'] = reglib.number(address)

    print("Reg:", params['name'], " width:", params['width'])
    fld_nodes = node.getElementsByTagName("field")
    fld_list = []
    cum_width = 0
    cum_default = 0
    if len(fld_nodes) != 0:
        for fld in fld_nodes:
            wstr = fld.getAttribute("width")
            if wstr == '':
                width = 1
            else:
                width = int(wstr)
            fld_list.append(reglib.net('wire', fld.getAttribute("name"), width))

            default = fld.getAttribute("default")
            if default == '':
                default = 0
            else:
                default = reglib.number(default)
            cum_default = cum_default | (default << cum_width)
            print("Fld: %20s CD: %x CW: %d D: %x" % (fld.getAttribute("name"), cum_default, cum_width, default))
            cum_width += width

        params['width'] = cum_width
        params['default'] = cum_default
        fld_list.reverse()
    else:
        if params['default'] == '':
            params['default'] = 0
        else:
            params['default'] = reglib.number(params['default'])

    if typ == '':
        typ = 'config'

    rg.add_register(typ, params)
    rg.registers[-1].fields = fld_list


def create_verilog(top_node):
    rg = create_reg_group(top_node)

    # get list of register nodes
    reg_nodes = top_node.getElementsByTagName("register")

    for r in reg_nodes:
        create_register(rg, r)

    fname = rg.name + ".v"
    fh = open(fname, 'w')
    fh.write(rg.verilog())
    fh.close()

    create_map(rg)
    create_vh(rg)
    return rg


def create_vhdl_component(rg):
    txt = "component {} is port (\n".format(rg.name)
    portlist = []
    for p in rg.ports:
        if p.width == 1:
            typ = "std_logic"
        else:
            typ = "std_logic_vector({} downto 0)".format(p.width - 1)
        portlist.append("{0} : {1} {2}".format(p.name, p.direction[:-3], typ))
    txt += ';\n'.join(portlist) + '\n);\n'
    txt += "end component;\n"

    with open(rg.name + '.vhdc', 'w') as fh:
        fh.write(txt)


def create_vh(rg):
    fname = rg.name + ".vh"
    fh = open(fname, 'w')
    for r in rg.registers:
        fh.write("`define %s 16'h%04x\n" % (r.name.upper(), rg.base_addr + r.offset))
    fh.close()


def create_map(rg):
    fname = rg.name + ".h"
    fh = open(fname, 'w')

    for r in rg.registers:
        fh.write("#define %s 0x%x\n" % (r.name.upper(), r.offset))

    # for r in rg.registers:
    #    fh.write ("sfr at 0x%02x %s;\n" % (r.offset, r.name))
    fh.close()


def parse_file(filename, args):
    rdoc = xml.dom.minidom.parse(filename)
    blk_list = rdoc.getElementsByTagName("registers")

    for blk in blk_list:
        rg = create_verilog(blk)
        if args.vhdl:
            create_vhdl_component(rg)

    dec_list = rdoc.getElementsByTagName("it_decoder")

    for dec in dec_list:
        create_decoder_verilog(dec)

    rdoc.unlink()


def check_version():
    version = float(sys.version[0:3])
    if version < 3.5:
        print("rgen requires at least Python 3.5 to function correctly")
        sys.exit(1)


if __name__ == "__main__":
    check_version()
    parser = argparse.ArgumentParser(description="Process register file(s)")
    parser.add_argument('--vhdl', action='store_true', help="Generate VHDL component declarations")
    parser.add_argument('filename', metavar='F', type=str, nargs='+', help="XML definition file")
    args = parser.parse_args()

    for f in args.filename:
        print("Parsing file", f)
        parse_file(f, args)
