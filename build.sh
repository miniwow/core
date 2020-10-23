#!/bin/sh

cd build
make -j $(nproc)
make install
