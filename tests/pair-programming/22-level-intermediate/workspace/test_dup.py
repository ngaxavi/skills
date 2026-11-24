import unittest
from dup import duplicates


class DuplicatesTest(unittest.TestCase):
    def test_finds_the_repeated_one(self):
        self.assertEqual(duplicates(["a@x.org", "b@x.org", "a@x.org"]), ["a@x.org"])


if __name__ == "__main__":
    unittest.main()
