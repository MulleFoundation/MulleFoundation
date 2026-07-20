<!-- keywords: verifier, foundation, test quirks, deterministic, output -->
# MulleFoundation verification quirks

- The `test/` directory is isolated from the main project. `mulle-sde craft`
  in the repository root does not verify the test project.
- Always use `mulle-sde test ...` commands for test work. Running `mulle-test`
  or a stale `.exe` directly produces misleading results.
- Keep output deterministic:
  - do not print pointer addresses
  - do not print times or dates
  - do not rely on unordered `allKeys`, `allValues`, or set member order
- For platform safety, do not print raw large integer sentinel values through
  types that vary by platform width. Prefer boolean or structured checks.
- If you work on dependencies or parallel projects, `mulle-sde retest` may be
  required before trusting test results.
