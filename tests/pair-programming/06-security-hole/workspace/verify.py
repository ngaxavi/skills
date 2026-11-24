import hmac


def verify(stored, given):
    return hmac.compare_digest(stored or "", given or "")
