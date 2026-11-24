class Stack:
    def __init__(self):
        self.items = []

    def push(self, item):
        self.items.append(item)

    def peek(self):
        # my idea: look without removing, None when empty
        return self.items[-1] if self.items else None
