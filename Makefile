ifndef JAVA_HOME
    $(error JAVA_HOME not set)
endif

ifeq ($(shell uname),Darwin)
    JNI_MD ?= darwin
else
    JNI_MD ?= linux
endif

CC     ?= gcc
LINK   ?= -shared
OUTPUT ?= libjvmkill.so

CFLAGS = -Wall -Werror -fPIC \
    -I"$(JAVA_HOME)/include" \
    -I"$(JAVA_HOME)/include/$(JNI_MD)" \
    $(LINK)

.PHONY: all clean test release

all: $(OUTPUT)

$(OUTPUT): jvmkill.c
	$(CC) $(CFLAGS) -o $(OUTPUT) jvmkill.c

clean:
	rm -f *.so *.dylib *.class *.hprof
	rm -rf dist

test: all
	$(JAVA_HOME)/bin/javac JvmKillTest.java
	@output=$$($(JAVA_HOME)/bin/java -Xss512m \
	    -agentpath:$(PWD)/$(OUTPUT) \
	    -cp $(PWD) JvmKillTest 2>&1 || true); \
	echo "$$output"; \
	echo "$$output" | grep -q 'ResourceExhausted:.*killing current process' || { \
	    echo 'ERROR: jvmkill agent did not fire on thread exhaustion' >&2; exit 1; \
	}

release:
	./scripts/release.sh
