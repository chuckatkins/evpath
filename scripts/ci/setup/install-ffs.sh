#!/bin/bash

export atl_ROOT="${PWD}/atl/install"
export dill_ROOT="${PWD}/dill/install"

mkdir ffs
cd ffs
git clone https://github.com/GTKorvo/ffs.git source
mkdir build
cd build
cmake \
  -DCMAKE_BUILD_TYPE=$1 \
  -DBUILD_TESTING=OFF \
  -DCMAKE_INSTALL_PREFIX=${PWD}/../install \
  ../source
cmake --build . -j4 --config $1
cmake --install . --config $1
