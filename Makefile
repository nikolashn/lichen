include config.mk

# D_FILES=$(shell find src | grep \\.d$)
D_FILES=src/foldconst.d src/lexer.d src/set.d src/syntax.d src/env.d src/formula.d src/parser.d src/interpreter.d src/main.d

all:
	${DC} -of=lichen ${D_FILES} ${FLAGS}

debug:
	${DC} -of=lichen ${D_FILES} ${DEBUG_FLAGS}

tests:
	for file in tests/*.li ; do \
		echo "--- $$file ---" ; \
		./lichen $$file ; \
	done > .make_tests_output 2>&1 \
	&& git diff --no-index tests/output .make_tests_output
	rm -f .make_tests_output

savetests:
	for file in tests/*.li ; do \
		echo "--- $$file ---" ; \
		./lichen $$file ; \
	done > tests/output 2>&1

clean:
	rm -f lichen *.o *.a .make_tests_output

.PHONY: all debug tests clean

