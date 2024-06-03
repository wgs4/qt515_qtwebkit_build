#!/bin/bash

export PNG_VER=1.6.43      # http://www.libpng.org/pub/png/libpng.html
export JPG_VER=9f          # https://ijg.org/files/
export PSQL_VER=16.3       # https://www.postgresql.org/ftp/source/
export QT_VER=5.15.15      # https://download.qt.io/official_releases/qt/5.15/

# This is for macOS where it will be installed. For linux it might be used pre-installed qt
export QT_DIR="/opt/Qt/$QT_VER/qt_xtuple"

export SRC_DIR="$HOME/work/src"
export BUILD_DIR="$HOME/work/build"

# This will be used for xtuple build
export XTUPLE_PREFIX="$HOME/work"
export XTUPLE="$XTUPLE_PREFIX/qt-client"
export XTUPLE_BUILD="$XTUPLE"
