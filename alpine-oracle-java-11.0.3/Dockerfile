FROM alpine:latest
MAINTAINER kamal.maiti@XXXX

ENV JAVA_HOME="/usr/lib/jvm/java-11-oracle"  \
    PATH="/usr/lib/jvm/java-11-oracle/bin:$PATH"  \
    JAVA_VERSION=11.0.3 \
    JAVA_BUILD=12

RUN GLIBC_VERSION=2.28-r0 && \
    GCC_LIBS_VERSION=8.2.0-2 && \
    ZLIB_VERSION=1.2.11-2  && \
    JAVA_VERSION=11.0.3  && \
    JAVA_BUILD=12 && \
    apk --update add --no-cache ca-certificates curl openssl binutils xz && \
    curl -Ls https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub && \
    curl -Ls https://github.com/sgerrand/alpine-pkg-glibc/releases/download/"${GLIBC_VERSION}"/glibc-"${GLIBC_VERSION}".apk \
        -o /tmp/glibc-"${GLIBC_VERSION}".apk && \
    apk add /tmp/glibc-"${GLIBC_VERSION}".apk && \
    mkdir /tmp/gcc-libs && \
    curl -Ls https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-"${GCC_LIBS_VERSION}"-x86_64.pkg.tar.xz \
        | tar x -J -C /tmp/gcc-libs && \
    mv /tmp/gcc-libs/usr/lib/libgcc* /tmp/gcc-libs/usr/lib/libstdc++* /usr/glibc-compat/lib && \
    strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so* && \
    mkdir /tmp/zlib && \
    curl -Ls https://archive.archlinux.org/packages/z/zlib/zlib-1%3A"${ZLIB_VERSION}"-x86_64.pkg.tar.xz \
        | tar x -J -C /tmp/zlib && \
    mv /tmp/zlib/usr/lib/libz.so* /usr/glibc-compat/lib && \
    apk del binutils

COPY jdk-"${JAVA_VERSION}"_linux-x64_bin.tar.gz /tmp
RUN  tar xvzf /tmp/jdk-"${JAVA_VERSION}"_linux-x64_bin.tar.gz -C /tmp && \
     mkdir -p /usr/lib/jvm && mv /tmp/jdk-${JAVA_VERSION} "${JAVA_HOME}" && \
     rm -rf /tmp/* /var/cache/apk/*
