def total(prices):
    result = prices[0]
    for p in prices[1:]:
        result += p
    return result
