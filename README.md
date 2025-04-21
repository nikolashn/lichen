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

### Union and grouping

If `x` is a set, then `U x` is the set whose elements are exactly those that are
members of some `z` which is an element of `x`.

If `x` and `y` are sets, then `x U y` is equal to `U{ x, y }`. For clarity and
to enforce a preferred precedence, set expressions can be grouped with
parentheses: for any set `x`, `(x)` is equal to `x`.

### Subsets and powersets

If `x`, `y` are sets, then `x sub y` if and only if each each element of `x` is
an element of `y`, i.e. `x` is a subset of `y`. `P x` is the powerset of `x`:
a set `z` is an element of `P x` if and only if `z` is a subset of `x`.

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
of `φ` and `ψ` is true). Precedence can be ensured by using enclosing
parentheses `(φ)`.

There are also quantifier formulas. For a set `x`, formula `φ`, `all a(x) φ` is
true if and only if for each set `y` element of `x`, `φ` is true when each free
instance of variable `a` are replaced with `y`. (A variable `a` is free in `φ`
if it is not enclosed with a quantifier in `φ`.)

Similarly, `exist a(x) φ` is true if and only if there exists a set `y` element
of `x` such that `φ` is true when each free instance of variable `a` is replaced
with `y`.

### Value statements

A value statement is just a set by itself as a statement, i.e. `x;` for any set
`x`. Lichen prints a (not necessarily unique) representation of the set.

