#!/bin/bash
# Runs tests on the production MB::M::Polynomial code using fft_offsets.rb.
# (C)2024 Mike Bourgeous

set -eu -o pipefail

BASEDIR=$(readlink -m "$(dirname "$0")")

export MIN_OFFSET=0
export MAX_OFFSET=0
export PRINT_JSON=1
export DEBUG=0

set -x

$BASEDIR/fft_offsets.rb > /dev/null
SEED=0 ORDER_A=3 ORDER_B=6 $BASEDIR/fft_offsets.rb > /dev/null
SEED=0 ORDER_A=6 ORDER_B=6 REPEATS=6 $BASEDIR/fft_offsets.rb > /dev/null
SEED=0 REPEATS=30 $BASEDIR/fft_offsets.rb > /dev/null
COEFF_A='[-33, -97, -65]' COEFF_B='[89, 0, -89, 0]' SEED=0 $BASEDIR/fft_offsets.rb > /dev/null
COEFF_A='[-33, -97, -65]' SEED=0 $BASEDIR/fft_offsets.rb > /dev/null
COEFF_B='[5, 0, -5, 0]' COEFF_A='[89, 0, 89, 0]' REPEATS=1 $BASEDIR/fft_offsets.rb > /dev/null
ORDER_A=71 MIN_ORDER=10 MAX_ORDER=20 REPEATS=1000 $BASEDIR/fft_offsets.rb > /dev/null
ORDER_A=5000 ORDER_B=299 REPEATS=100 $BASEDIR/fft_offsets.rb > /dev/null
MIN_ORDER=1 MAX_ORDER=10 REPEATS=100 $BASEDIR/fft_offsets.rb > /dev/null
REPEATS=1000 MAX_ORDER=100 MIN_ORDER=98 ORDER_A=6 $BASEDIR/fft_offsets.rb > /dev/null
ORDER_A=10000 ORDER_B=5101 REPEATS=20 $BASEDIR/fft_offsets.rb > /dev/null

set +x

printf "\n\n\n\033[1;32mFFT deconvolution stress tests passed\033[0m\n\n\n"
