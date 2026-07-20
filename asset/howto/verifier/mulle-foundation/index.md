<!-- keywords: verifier, testing, foundation, non-graphical, stdout, golden, include.h, import.h -->
# Verifying MulleFoundation code

Use this bundle when verifying non-graphical MulleFoundation code such as model
objects, utilities, collections, parsers, and value-transforming helpers.

## When to use it

Prefer this verifier topic when the change touches:

- Foundation classes and helpers
- non-UI logic
- collection behavior
- parsing or formatting code
- ownership and teardown behavior
- deterministic stdout-based tests

For graphical interaction paths, use a UI-specific verifier topic such as
`event-replay` instead.

## Understand first

```bash
mulle-sde api apropos "<class terms>"
ls test
mulle-sde howto show verifier testing
```

Useful references in this project:

- `asset/howto/coder/mulle-foundation/index.md`
- `test/.mulle/share/howto/running-tests.md`
- `.mulle/share/howto/testing.md`
- `.mulle/share/howto/coverage.md`

## Verification model

For MulleFoundation work, verification should usually be test-first or
test-driven:

1. add or adjust a focused test under `test/`
2. run that specific test until it passes
3. run the broader test suite
4. use coverage when the task is explicitly about missed branches

This is the default verifier path for non-graphical code. Do not reach for UI
replay machinery unless the behavior actually depends on a UI event path.

## Core commands

The `test` directory is its own mulle-sde project. Use:

```bash
mulle-sde test craft
mulle-sde test run
mulle-sde test run /absolute/path/to/test/file.m
mulle-sde test run --timeout 10 /absolute/path/to/test/file.m
mulle-sde test --valgrind run /absolute/path/to/test/file.m
mulle-sde retest
```

Do not use `mulle-test` directly and do not run the produced executable
directly.

## Test shape

Prefer small, focused tests with deterministic output:

```objc
#import "import.h"

int main( void)
{
   mulle_printf( "...\n");
   return( 0);
}
```

Use `include.h` or `import.h` according to the local test style. Prefer
`mulle_printf` and stable stdout over ad-hoc assertion frameworks when the
project already verifies via golden output.

## Golden output

After the output is correct, golden it:

```bash
mulle-sde test run --rerun --golden-stdout /absolute/path/to/test/file.m
cat /absolute/path/to/test/file.tmp.stdout
cat /absolute/path/to/test/file.tmp.stderr
```

Use absolute paths for single-test commands so the test project resolves the
right file.

## Report

Report:

- which test proves the change
- whether verification is specific-test, full-suite, or coverage-based
- the first failing test if verification is incomplete
