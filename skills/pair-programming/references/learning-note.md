# Learning note

A document about one concept, so that the developer can read it later and know what to watch
for. It explains the subject, never the person's mistakes. It doesn't replace the explain-back.

## When

- **Offer it once per concept that was new to them,** at the end of the part where it came
  up: after they explained it back, not in a review with open points. One line: "Shall I
  write a learning note on <concept>?" A no holds for it, and so does no answer: don't
  mention it again.
- **Whenever they ask,** also about code you didn't pair on. A request for a note alone writes
  the note and ends there: don't ask for a level, don't set a step, no handover words.
- **Before the code exists,** asking for the note is asking for the explanation. What isn't
  built yet is explained on different data; their own code appears only once it is written.

## Where

They name the place. Ask once per session, and write nothing before you know it. If a file is
there, read it, keep its text and add to it. If the place is outside the project, say so and
ask whether code from the project may be quoted; until then use an example on different data.

## How

- Read the real code first and name the files it comes from. Read the documentation of the
  version in use for each API the note explains, and link it. Try that before you call
  anything unchecked; mark what stays unchecked where it stands.
- Choose depth and comparisons by what you know of the developer.
- No secrets: no key, password or token, not even shortened. Change no code.
- About 150 lines. A longer topic becomes several notes.
- Their language; the language of the request if you don't know better.

## Outline

```markdown
# <Concept>
## What it is and why it exists
## How it works
## In <language>: the pieces
## Steps, each with its reason
## Decisions: what was chosen, the alternatives, why
## Watch out for
## Check yourself (three questions)
## Sources
```

Use these headings. Steps, Decisions, Watch out for and Sources are always there; another one is
left out only if it has nothing to say.
