#!/bin/sh
TARGET="/build"

ROOT="/home/postgres"
PREFIX="$ROOT/$TARGET"

./configure \
CFLAGS='-O0 -pipe -Wall ' \
--prefix=$PREFIX \
--enable-tap-tests \
--with-icu \
--with-openssl --with-perl --with-python \
--enable-debug --enable-cassert --enable-depend
