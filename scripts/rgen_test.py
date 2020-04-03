import unittest
from rgen import *
from xml.etree.ElementTree import Element, SubElement, tostring
from collections import namedtuple
import os

Field = namedtuple('Field', ['name', 'width', 'default'])


class create_xml_reg_file:
    def __init__(self, filename, name, asize=16, dsize=16):
        self.filename = filename
        self.asize = asize
        self.dsize = dsize
        self.tree = Element('registers', attrib={'name': name, 'addr_sz': str(asize), 'data_sz': str(dsize)})

    def add_register(self, rname="reserved", typ='status', width=1, fields=None):
        if fields is None:
            fields = []
        attributes = {'name': rname, 'type': typ}
        if not fields:
            attributes['width'] = str(width)
        reg = SubElement(self.tree, "register", attrib=attributes)
        if fields:
            for field in fields:
                SubElement(reg, "field", attrib=field._asdict())

    def dump(self):
        with open(self.filename, 'w') as fh:
            fh.write(tostring(self.tree).decode('utf-8'))


class create_xml_dec_file:
    def __init__(self, filename, name, asize=16, dsize=16):
        self.filename = filename
        self.asize = asize
        self.dsize = dsize
        self.tree = Element('it_decoder', attrib={'name': name, 'addr_sz': str(asize), 'data_sz': str(dsize)})

    def add_range(self, prefix, base, bits):
        SubElement(self.tree, 'range', attrib={'prefix': prefix, 'base': str(base), 'bits': str(bits)})

    def dump(self):
        with open(self.filename, 'w') as fh:
            fh.write(tostring(self.tree).decode('utf-8'))


class rgenTestSuite(unittest.TestCase):
    def test_rgen(self):
        testfile = "test_file1.xml"
        blockname = "rgen1"
        f = create_xml_reg_file(filename=testfile, name=blockname)
        for r in range(10):
            f.add_register(rname="register_{}".format(r), typ='config', width=r + 2)
        f.dump()
        parse_file(testfile, {})
        self.assertTrue(os.path.isfile(blockname + ".v"))
        os.unlink(testfile)

    def test_fields(self):
        testfile = "test_file2.xml"
        blockname = "rgen2"
        f = create_xml_reg_file(filename=testfile, name=blockname)
        flds = [Field(name="field{}".format(x), width=str(x), default=str(x)) for x in range(2, 5)]
        f.add_register(rname="has_fields", typ='config', fields=flds)
        f.dump()
        parse_file(testfile, {})
        self.assertTrue(os.path.isfile(blockname + ".v"))
        os.unlink(testfile)

    def test_decode(self):
        testfile = "test_decode.xml"
        blockname = "dec1"
        f = create_xml_dec_file(filename=testfile, name=blockname)
        for r in range(10):
            f.add_range(prefix='prefix{}'.format(r), base='16\'h{0:02x}00'.format(r), bits=8)
        f.dump()
        parse_file(testfile, {})
        self.assertTrue(os.path.isfile(blockname + ".v"))
        os.unlink(testfile)


if __name__ == "__main__":
    unittest.main()
