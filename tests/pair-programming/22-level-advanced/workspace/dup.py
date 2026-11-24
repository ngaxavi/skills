def duplicates(emails, seen=set()):
    result = []
    for email in emails:
        if email in seen:
            result.append(email)
        seen.add(email)
    return result
