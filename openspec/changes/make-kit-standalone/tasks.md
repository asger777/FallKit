## 1. Plan (PLAN §14)

- [x] 1.1 OpenSpec change make-kit-standalone and a neutral PLAN.md

## 2. Public API (PLAN §15)

- [x] 2.1 LiveOpsKind: rule kinds only
- [x] 2.2 LiveOpsGate.Policy.blockedEnvironment
- [x] 2.3 Neutral doc comments in every source file and Package.swift

## 3. Testing product (PLAN §16)

- [x] 3.1 LiveOpsGolden and LiveOpsGoldenExpectation in LiveOpsTesting
- [x] 3.2 Non-product LiveOpsTestFixtures target with neutral fixtures; re-record and review

## 4. Tests (PLAN §17)

- [ ] 4.1 Neutral sample data; no origin tags or comments

## 5. Docs (PLAN §18)

- [ ] 5.1 Docs/behaviour.md; delete migration.md, semantics.md and the 0.1.0 archive
- [ ] 5.2 README, CLAUDE.md, OpenSpec config and spec purposes, rule, manifest, CHANGELOG

## 6. Guard and release (PLAN §19)

- [ ] 6.1 Forbidden-words guard in ci-local.sh
- [ ] 6.2 Full gate, archive, tag 0.2.0, release, ConsumerCheck against 0.2.0
