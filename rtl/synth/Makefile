# Quartus project name
PROJECT_NAME = pipelined_heap

# Module parameters
ITEMS=7
TS_WIDTH=32
META_WIDTH=16

all:
	ITEMS=$(ITEMS) TS_WIDTH=$(TS_WIDTH) META_WIDTH=$(META_WIDTH) \
	quartus_sh --flow compile ${PROJECT_NAME}

open:
	export ITEMS=$(ITEMS) TS_WIDTH=$(TS_WIDTH) META_WIDTH=$(META_WIDTH) && \
	quartus $(PROJECT_NAME).qpf

clean:
	rm -rf *.asm*
	rm -rf *.done*
	rm -rf *.fit*
	rm -rf *.flow*
	rm -rf *.jdi*
	rm -rf *.map*
	rm -rf *.pin*
	rm -rf *.qws*
	rm -rf *.sld*
	rm -rf *.sof*
	rm -rf *.sta*
	rm -rf *db*
