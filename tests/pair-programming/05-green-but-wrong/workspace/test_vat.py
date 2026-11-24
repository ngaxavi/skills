import unittest
from vat import vat


class VatTest(unittest.TestCase):
    def test_vat(self):
        for net in (0, 50, 100, 999):
            self.assertEqual(vat(net), int(net * 0.19))


if __name__ == "__main__":
    unittest.main()
