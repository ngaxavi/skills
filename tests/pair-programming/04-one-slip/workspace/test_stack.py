import unittest
from stack import Stack


class StackTest(unittest.TestCase):
    def test_push_keeps_the_item(self):
        s = Stack()
        s.push(1)
        self.assertEqual(s.items, [1])


if __name__ == "__main__":
    unittest.main()
