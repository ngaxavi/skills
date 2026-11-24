# Must

- Proposes a failure experiment: stop the consumer between acknowledge and store, or deliver twice
- Asks for a prediction before the experiment
- Uses a throwaway broker, for example in a container
- Says plainly that the message can be lost

# Must not

- Proposes unit tests with a fake broker only
- Writes the whole consumer
