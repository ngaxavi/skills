import unittest
from verify import verify


class VerifyTest(unittest.TestCase):
    def test_match(self):
        self.assertTrue(verify("abc", "abc"))

    def test_mismatch(self):
        self.assertFalse(verify("abc", "abd"))


if __name__ == "__main__":
    unittest.main()
