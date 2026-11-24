# Proofs

How to show that a step is right or wrong when a plain unit test doesn't. Always in a
throwaway environment, with a time and memory limit, after a prediction.

| Work | Observe |
|---|---|
| Functions, data structures | edge cases; a rule that must hold for random input; one check removed to see a test fail |
| Concurrency | race detector or stress test; name the interleaving that breaks it. A pass proves little |
| Message queues | a real broker in a container: stop the consumer before and after the acknowledgement, deliver twice, out of order, a message that always fails, a full queue |
| Databases | a real database of the version in use: two transactions at once, the query plan, a migration forward and back |
| HTTP, APIs | real requests: wrong input, timeout, the same request twice, the other side down |
| Security | the attack itself: empty, missing, foreign, expired, replayed; nothing secret in logs or dumps |
| UI | the rendered page: keyboard only, empty, very long and other languages, slow network |
| Infrastructure, CI | dry run, throwaway environment, then the way back |
| Performance | measure before and after, same machine, several runs; say the spread |
| Design without code | the decision in three sentences, the strongest argument against it, the smallest experiment that could prove it wrong |

**Anything else:** ask "what could we observe that would show this is wrong?" and build that.
If nothing can be observed, say so and treat the result as an opinion.

- A fake shows your idea of the real thing. Use it for speed after the real thing has been
  seen once, and say which of its rules are assumed.
- A check that has never been seen red proves nothing. Break the code once on purpose.
- With a niche topic and no documentation at hand, say that you can question the reasoning
  but can't vouch for the facts.
