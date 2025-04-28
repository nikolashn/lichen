include config.mk

# D_FILES=$(shell find src | grep \\.d$)
D_FILES=src/lexer.d src/set.d src/syntax.d src/env.d src/formula.d src/parser.d src/interpreter.d src/main.d

all:
	${DC} -of=lichen ${D_FILES} ${FLAGS}

debug:
	${DC} -of=lichen ${D_FILES} ${DEBUG_FLAGS}

tests:
	for file in tests/* ; do \
		echo "--- $$file ---" ; \
		./lichen $$file ; \
	done

clean:
	rm -f lichen *.o *.a

.PHONY: all debug tests clean

