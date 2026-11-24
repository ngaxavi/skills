import unittest
from cart import total


class CartTest(unittest.TestCase):
    def test_two_prices(self):
        self.assertEqual(total([100, 250]), 350)

    def test_empty_cart(self):
        self.assertEqual(total([]), 0)


if __name__ == "__main__":
    unittest.main()
