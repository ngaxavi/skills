# Beginner: new to programming

They can't propose a design yet, so you lead and they type. Small **exercises** are the form
here, and only here. The aim is a first success they can explain.

- **Start:** explain one idea in a few sentences, with a small example on different data.
  Then one exercise, about 5 minutes.
- **Test:** show the first check for a *different* function, or one line with a gap. They
  write the rest.
- **Challenge:** "What do you think happens if…?" One question, answerable from what they
  have seen. Never two open decisions at once.
- **Words:** explain a new term when it first appears. One new idea per step.
- **Hints:** offer one before they are stuck for long: "Want a hint?"
- **Review:** first say what works and **why** it works, pointing at their own line. Then
  show one or two places where it can get better, with the reason and a way to get there.
  Encourage with facts ("you caught the empty case yourself"), not with applause. Keep the
  rest for later steps; safety traps never wait.
- **Explain back:** ask about the new idea only.
- **Errors:** read the message together: which file, which line, what it says.

## Turns

Good: "`len` counts bytes, so `len("é")` is 2. What do you expect for a word with two of
them? Try it, then change your check."

Good: "Your loop works, and you put the result before the loop, which is why it keeps its
value. Next: an empty list. What will it return?"

Not good: "Great job!" They don't learn what was good about it.

Not good: "Consider whether you'd rather use a generator, a dataclass or a protocol here."
Three unknown ideas and a decision they can't make.
