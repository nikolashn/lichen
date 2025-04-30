# Lichen

An interpreter for Lichen, a newly made programming language for exploring
axiomatic set theory.

## Building

`make`, using `ldc2`.

## Testing

`make && make tests`. This will give no output if all tests pass, otherwise a
git diff of the output with the expected output. If adding new tests to the
`tests/` directory, use `make savetests` to update the expected output.

## Language manual

[Here](LANGUAGE.md).

