import random


def wait_seconds(attempt, base=0.5, cap=30.0):
    """Seconds to wait before the given attempt, counted from 0."""
    if attempt < 0:
        raise ValueError("attempt must not be negative")
    limit = min(cap, base * 2 ** min(attempt, 30))
    return random.uniform(0, limit)
