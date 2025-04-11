# Lichen

An interpreter for Lichen, a newly made programming language for exploring
axiomatic set theory.

## Building

`make`, using `ldc2`.

## Sets

Lichen has values called sets.

### Membership

Sets can have elements which are also sets. The assertion `x < y` holds if and
only if `x` is an element of `y`.

### Extensionality

If every element of `x` is an element of `y`, and every element of `y` is an
element of `x`, then `x` and `y` are equal, and the assertion `x = y` holds.
Otherwise, the assertion `x /= y` holds.

### Empty set

`0` is the set with no elements. It is equal to `{ }`.

### Pairing

If `x`, `y` are sets, then `{ x }`, the set whose only element is `x`, and
`{ x, y }`, whose only elements are `x` and `y`, are sets. For each set `x`,
`{ x }` is equal to `{ x, x }`.

## Statements

Statements are either definitions, assertions or value statements. Instances of
these are separated sequentially by a final semicolon.

### Definitions

A definition binds an identifier to a value of some kind. `x := y` binds the
identifier `x` to the set `y`. Lichen has no notion of scope for definitions.

### Assertions

Assertions are formulas, which may be either true or false. Assertions that
succeed continue, and assertions that fail give an error message. For sets `x`,
`y`, the following are atomic formulas: `x < y`, `x = y`, `x /= y`. If `φ`, `ψ`
are formulas, then `~φ` (true if and only if `φ` is false), `φ & ψ` (true if and
only if both `φ` and `ψ` are true) and `φ | ψ` (true if and only if at least one
of `φ` and `ψ` is true).

### Value statements

A value statement is just a set by itself as a statement, i.e. `x;` for any set
`x`. Lichen prints a (not necessarily unique) representation of the set.

