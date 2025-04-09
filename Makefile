include config.mk

D_FILES=$(shell find src | grep \\.d$)

all:
	${DC} -of=lichen ${D_FILES} ${FLAGS}

debug:
	${DC} -of=lichen ${D_FILES} ${DEBUG_FLAGS}

clean:
	rm -f lichen *.o *.a

.PHONY: all debug clean

