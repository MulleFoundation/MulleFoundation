<!-- keywords: foundation, mullefoundation, model, utility, object -->
# MulleFoundation classes

Use this bundle when implementing a non-UI mulle-objc class such as a model
object, helper, or data structure.

## Understand first

```bash
mulle-sde vibecoding on
mulle-sde howto cat styleguide
mulle-sde howto cat mulle-c-syntax
mulle-sde api apropos "<class terms>"
mulle-sde code search "<similar class>"
```

Read `quirks.md` and `patterns.md` next.

## Design

```bash
mulle-sde api cat MulleObjC
mulle-sde api cat mulle-container
```

Plan:

- stored data
- ownership model
- initializer and teardown needs
- protocol conformance if any

## Implement and verify

```bash
mulle-sde add src/{ClassName}.m
mulle-sde reflect
mulle-sde craft
```

