def parse(text):
    result = {}
    for line in text.splitlines():
        if "=" not in line:
            raise ValueError(f"no equals sign: {line!r}")
        key, value = line.split("=", 1)
        result[key] = value
    return result
