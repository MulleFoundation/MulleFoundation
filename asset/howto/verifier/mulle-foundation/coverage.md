<!-- keywords: verifier, coverage, foundation, golden, gcov -->
# Coverage-driven verification

Use this file when the task is specifically to improve MulleFoundation test
coverage rather than just verify one bug fix.

## Measure baseline coverage

```bash
mulle-sde test clean all
mulle-sde test coverage 2>&1 | grep -E "\\.m|TOTAL"
```

Focus on files with low coverage and uncovered lines that match the changed
code.

## Coverage workflow

1. inspect uncovered lines in the affected source file
2. add a focused test in `test/NN_topic/`
3. golden the expected stdout if needed
4. rerun the specific test
5. rerun full coverage

Typical commands:

```bash
mulle-sde test run --rerun --golden-stdout /absolute/path/to/test/file.m
mulle-sde test run --rerun /absolute/path/to/test/file.m
mulle-sde test run 2>&1 | tail -3
mulle-sde test clean all
mulle-sde test coverage 2>&1 | grep -E "\\.m|TOTAL"
```

## Coverage pitfall

After `mulle-sde test coverage`, check for stale `gcov_stubs.o` references if a
later plain test run starts failing unexpectedly:

```bash
grep "LDFLAGS\\|gcov_stubs" test/.mulle/etc/env/environment-global.sh
grep "LDFLAGS\\|gcov_stubs" test/.mulle/etc/env/environment-user-*.sh
```

If those stale lines appear, remove the `gcov_stubs` `LDFLAGS` entry before
returning to normal `mulle-sde test run` work.
