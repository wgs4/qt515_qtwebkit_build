# qt515_qtwebkit_build
Build scripts: QtWebkit 5.212 for Qt 5.15.x

The script `build_unix.sh` is meant to build patched [QtWebkit](https://github.com/dilshodm/qtwebkit) 5.212 and Qt 5.15.x **mainly for macOS**. It can also be used for Linux, but it's not well tested there.

This environment is needed to build the [xTuple](https://github.com/dilshodm/qt-client/) software.

### Pre-requisites
#### MacOS
1. xcode
2. [hombrew](https://brew.sh)

The rest (python3, python2, perl...) will be installed by script if not yet installed (see `install_prerequisites` step).

### User defined vars
Edit `User defined vars:` section to setup sources and build directories, software versions:
```bash
PNG_VER=1.6.43      # http://www.libpng.org/pub/png/libpng.html
JPG_VER=9f          # https://ijg.org/files/
PSQL_VER=16.3       # https://www.postgresql.org/ftp/source/
QT_VER=5.15.15      # https://download.qt.io/official_releases/qt/5.15/

# This is for macOS where it will be installed. For linux we use pre-installed qt
#QT_DIR=$HOME/Qt/$QT_VER/clang_64
QT_DIR=/opt/Qt/$QT_VER/clang_64

LIBS_INSTALL_PREFIX="$BUILD_DIR/install_dir"  # to install png and jpeg libraries
PSQL_INSTALL_PREFIX="$QT_DIR/pgsql" # to install postgresql
```

### Build steps
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

### Author

Dilshod Mukhtarov `dilshodm<at>gmail.com`


