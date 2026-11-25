# Learning log

What you may remember between sessions: levels, borrowed code, open questions. Personal, in
the home folder, outside every project. Small, so that only what is needed is read.

```text
~/.pair-programming/
├── levels.md              one line per topic
└── projects/
    └── <project>.md       borrowed code and open questions
```

## Permission

Ask once, with the first questions (see [adapting](adapting.md)); one yes covers both files.
Existing files mean it was given. After a yes, update without asking and say so in one line.
After a no, write nothing and don't ask again in this session; their own instructions may say
no for good.

## levels.md

```markdown
- programming: intermediate
- java: intermediate
- go: basics
- go/concurrency: beginner (open question in shop-api)
```

- Values: beginner, basics, intermediate, advanced. `programming` is the general experience.
- A sub-topic is written `topic/sub-topic`, in lower case. Without a line of its own it has
  its topic's value; a line that would equal it is left out.
- **Save a level only at the close** ("stop pairing" or the end you agreed on), and only if
  it still holds then; or at once when they tell you to. Help in the session adapts right
  away, the file doesn't: one bad hour shouldn't follow them. Going up works the same way.
  If the session breaks off, no level changes.
- What you saw stays in its sub-topic: stuck on channels lowers `go/channels`, not `go`.
- At most about 100 lines.

## projects/<project>.md

The project's name is the repository's, else the folder's; on a clash add the folder path.

```markdown
# shop-api

## Borrowed
- verifyHash: reads settings from the stored hash, compares in constant time
  Open: why does the key length check matter?

## Open questions
- go/testing: why must an expected value not use the code's own formula?
```

- An entry has at most two lines, no code, no history. It is deleted when they can explain or
  change it. The same gap twice is merged.
- An open question is pointed to from its line in `levels.md`, so it can come back in another
  project. If a project file is deleted, its pointers go too; no level does.
- Update it after a step that changed something. Show the borrowed list before a commit and
  at the end.
- At about 50 lines, remove nothing by yourself: say that the list is long, offer to clear it
  together (learn, merge or drop), and ask whether the steps were too big.

## Reading and writing

- At the start read `levels.md` and this project's file, no other project's.
- **Read a file again right before you write it** and change only your lines. Keep lines you
  can't read as they are, name them, and let the developer repair them.
- No secrets, no code, nothing about the person beyond topics. They may read, edit or delete
  it at any time. You send it nowhere, but your provider sees it like the rest of the chat.
- Can't write files? Print the lines to add or change, with the file's name, and ask for them
  next time.
