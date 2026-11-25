import unittest
from parse import parse


class ParseTest(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(parse(""), {})
