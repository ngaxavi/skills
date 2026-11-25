import unittest
from parse import parse


class ParseTest(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(parse(""), {})

    def test_value_with_equals_sign(self):
        self.assertEqual(parse("a=1\nb=x=y"), {"a": "1", "b": "x=y"})
