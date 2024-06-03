# qt515_qtwebkit_build
Build scripts: QtWebkit 5.212 for Qt 5.15.x

The script `build_qt_unix.sh` is meant to build patched [QtWebkit](https://github.com/dilshodm/qtwebkit) 5.212 and Qt 5.15.x **mainly for macOS**. It can also be used for Linux, but it's not well tested yet.

This environment is needed to build the [xTuple](https://github.com/dilshodm/qt-client/) software.

**ATTENTION**: all shell commands below assumes that current directory is this repository scripts. They do `source setenv.sh` to set necessary variables.

## Build Qt and QtWebkit
### Pre-requisites
#### MacOS
1. xcode
2. [hombrew](https://brew.sh)

The rest (python3, python2, perl...) will be installed by script if not yet installed (see `install_prerequisites` step in `build_qt_unix.sh`).

### User defined vars
Edit `setenv.sh` to change software version, source and build directories:
```bash
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
```

### Edit build steps
Building can sometimes fail, so to make the try-and-error process easier, the build is divided into steps. If a step fails, the script will exit. On re-run, it will continue from the failed step, with the last successful step saved in the `last_successful_step` file under the source directory.

You can disable any step by commenting it out.

Building Qt and QtWebkit is divided into three steps each: prep, build, install. This way, it's easier to continue if a failure happens during the build.

```bash
# File to track the last successfully completed step
STATE_FILE="$SRC_DIR/last_successful_step"

# List of functions to run
BUILD_STEPS=(
    "install_prerequisites"
    "download_sources"
    "build_png"
    "build_jpg"
    "build_psql"
    "prep_qt"
    "build_qt"
    "install_qt"
    "prep_webkit"
    "build_webkit"
    "install_webkit"
)
```

### Build Qt and QtWebkit
Run
```sh
sh build_qt_unix.sh
```
It will take quite some time (1-4 hours depending on hardware).

### Cleanup build and source dirs
When build finished all the necessary files will be installed in `$QT_DIR` directory. Source and build directories can be removed (`$SRC_DIR` and `$BUILD_DIR`) using file manager or this commands from shell:
```sh
source setenv.sh && rm -rf $SRC_DIR
source setenv.sh && rm -rf $BUILD_DIR
```

## Build xTuple
### Get the sources
To build xTuple on MacOS/Linux first get the sources:

```sh
source setenv.sh && mkdir -p "$XTUPLE_PREFIX" && cd "$XTUPLE_PREFIX" && git clone --recurse-submodules --depth=1 https://github.com/dilshodm/qt-client.git && cd -
```

Note `--depth=1` - this is to clone shallow copy. If you need full repo with history, then remove that argument.

### Build xTuple
```sh
sh build_xtuple_unix.sh
```
   
This will build xtuple and if it's macOS it will create dmg file which will be located in `qt-client/bin/` directory.

## Author

Dilshod Mukhtarov `dilshodm<at>gmail.com`


