## Comments and documentation

Document the current code, not the process that produced it.

- Never record implementation history, debugging history, discarded approaches,
  or reasoning chronology in comments or documentation.
- Comments should explain only non-obvious intent, constraints, invariants,
  contracts, workarounds, or risks.
- Do not restate behavior that is evident from the code.
- Prefer deleting an unnecessary comment over expanding it.
- Documentation describes the current supported behavior.
- Git history and the PR retain change history; do not duplicate it in source docs.

## Pull requests

Describe the net change, not the implementation journey.

Include only:
- what changed and why,
- material behavior or architecture changes,
- reviewer-relevant risks,
- verification,
- unresolved limitations when applicable.

Do not include investigation logs, intermediate attempts, discarded approaches,
routine implementation details, or exhaustive file-by-file narration.
