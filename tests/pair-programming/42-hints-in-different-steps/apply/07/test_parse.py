import unittest
from parse import parse


class ParseTest(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(parse(""), {})

    def test_value_with_equals_sign(self):
        self.assertEqual(parse("a=1\nb=x=y"), {"a": "1", "b": "x=y"})

    def test_line_without_equals_sign(self):
        with self.assertRaisesRegex(ValueError, "no equals sign"):
            parse("abc")
