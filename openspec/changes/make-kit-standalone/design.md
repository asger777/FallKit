## Context

`0.1.0` was extracted from several near-identical implementations. That was a sound way to find the right abstractions, and it left the kit carrying their vocabulary. This change keeps every abstraction and removes the vocabulary.

## Goals / Non-Goals

**Goals:**
- Nothing in the current tree identifies a consumer: no names, no ids, no sample data copied from one.
- The specs are the contract; the docs describe the kit on its own terms.
- The independence is enforced by the gate, so it stays that way.

**Non-Goals:**
- Changing resolution, parsing, the store or the transport.
- Rewriting git history. That would break the published `0.1.0` tag and anyone who fetched it.

## Decisions

1. **The generic options stay:** `LiveOpsWindowEnd` (exclusive or inclusive), `LiveOpsDisabled` (removed or closed), and instant or day windows. They are general live-ops concepts. The docs recommend one default for a new app: instant windows, end exclusive, disabled removed.
2. **The kind constants are the kinds the rule names.** Constants are a convenience, not a registry. Keeping one only because some consumer spells it that way would put that consumer's vocabulary into the API.
3. **`blockedEnvironment` uses an exact key and value.** The old flag rule (`KEY=1` or the argument `-KEY`) encoded one particular launch convention. Two explicit lists express the same thing without a convention.
4. **`LiveOpsGolden` is generic:** `mismatches(manifest:values:expected:)` returns readable differences. The expectation type (`LiveOpsGoldenExpectation`, with probes and an optional report) is public, so any app can keep golden files for its own console. The kit's fixtures live in a non-product `LiveOpsTestFixtures` target used only by the kit's tests.
5. **The forbidden-words guard reads an untracked file.** A list of consumer names committed to the repo would itself be a consumer reference. `.fallkit-forbidden-words` is git-ignored; the gate runs the check when the file exists and says so when it doesn't.

## Risks / Trade-offs

- [Consumers lose conveniences such as `.ads`] → Each is a one-line literal in the consumer.
- [Tag `0.1.0` still contains the old text] → Accepted; it's history. The current tree and every later tag are clean.
