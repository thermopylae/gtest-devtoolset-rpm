#! /bin/bash

SELF_DIR=$(dirname "$0")

rm -Rf "$SELF_DIR/../build/Dockerfile.tmp."* \
       "$SELF_DIR/../build/RPMS/"* \
       "$SELF_DIR/../build/SPECS/"* \
       "$SELF_DIR/../build/SOURCES/"*
