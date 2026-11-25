import unittest
from unittest import mock
from backoff import wait_seconds


class BackoffTest(unittest.TestCase):
    def test_limit_doubles_until_the_cap(self):
        with mock.patch("backoff.random.uniform", side_effect=lambda low, high: high):
            self.assertEqual([wait_seconds(n) for n in range(8)], [0.5, 1, 2, 4, 8, 16, 30, 30])

    def test_wait_is_never_negative(self):
        self.assertTrue(all(0 <= wait_seconds(3) <= 4 for _ in range(1000)))

    def test_negative_attempt_is_refused(self):
        with self.assertRaises(ValueError):
            wait_seconds(-1)


if __name__ == "__main__":
    unittest.main()
