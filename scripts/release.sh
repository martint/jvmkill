#!/bin/sh
# Cross-compile the agent for all supported platforms using the rustxc
# image and stage release artifacts under dist/. The same Makefile rule
# that dev uses for the native build is invoked once per target here, so
# the compile flags / header paths live in exactly one place.
#
# The host's $JAVA_HOME is bind-mounted into the container and exposed
# as JAVA_HOME=/jdk to the Makefile. Any modern JDK works for any
# target — jvmti.h is platform-pure and the Unix targets share the same
# primitive sizes via jni_md.h.
#
# Assumes the rustxc image provides:
#   - make
#   - x86_64-linux-gnu-gcc, aarch64-linux-gnu-gcc, powerpc64le-linux-gnu-gcc
#   - osxcross with o64-clang and oa64-clang on PATH (the unversioned
#     aliases osxcross creates for x86_64 / arm64 darwin targets)
set -e

if [ ! -d /jdk ]; then
    # Not inside the container yet — re-exec via docker.
    [ -z "$JAVA_HOME" ] && { echo "JAVA_HOME must be set" >&2; exit 1; }
    [ ! -f "$JAVA_HOME/include/jvmti.h" ] && {
        echo "JAVA_HOME=$JAVA_HOME has no include/jvmti.h" >&2
        exit 1
    }
    exec docker run --rm \
        --mount type=bind,source="$PWD",target=/mnt \
        --mount type=bind,source="$JAVA_HOME",target=/jdk,readonly \
        --workdir /mnt \
        --user "$(id -u):$(id -g)" \
        --env HOME=/tmp \
        --env JAVA_HOME=/jdk \
        ghcr.io/martint/rustxc:latest \
        sh scripts/release.sh
fi

mkdir -p dist

# -B forces a rebuild each call (OUTPUT changes per target, but make's
# timestamp check doesn't know that).
one() { make -B CC="$1" LINK="$2" OUTPUT="$3"; }

one x86_64-linux-gnu-gcc      -shared     dist/libjvmkill-x86_64-unknown-linux-gnu.so
one aarch64-linux-gnu-gcc     -shared     dist/libjvmkill-aarch64-unknown-linux-gnu.so
one powerpc64le-linux-gnu-gcc -shared     dist/libjvmkill-powerpc64le-unknown-linux-gnu.so
one o64-clang                 -dynamiclib dist/libjvmkill-x86_64-apple-darwin.dylib
one oa64-clang                -dynamiclib dist/libjvmkill-aarch64-apple-darwin.dylib
