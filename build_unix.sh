#!/bin/bash

# By Dilshod Mukhtarov <dilshodm@gmail.com> May 2024

# This scipt is intended to build qt/qtwebkit framework to build xTuple client

# IMPORTANT: xcode command line tools has to be installed before running this script
# xcode-select --install

# To debug script, uncomment the line below
#set -x

# Source the user defined variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && source "$SCRIPT_DIR/setenv.sh" || exit 1

# User defined vars: ===============================================================

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


# NORMALLY THESE VARS SHOUDN'T BE EDITED ==========================================

LIBS_INSTALL_PREFIX="$BUILD_DIR/install_dir"  # to install png and jpeg libraries
PSQL_INSTALL_PREFIX="$QT_DIR/pgsql" # to install postgresql

# Names of the directories
PNG_NAME=libpng-$PNG_VER
JPG_NAME=jpeg-$JPG_VER
PSQL_NAME=postgresql-$PSQL_VER
QT_NAME=qt-everywhere-src-$QT_VER
WEBKIT_NAME=qtwebkit

# Archive filenames
PNG_FILE=$PNG_NAME.tar.xz
JPG_FILE=jpegsrc.v$JPG_VER.tar.gz
PSQL_FILE=$PSQL_NAME.tar.bz2
QT_FILE=qt-everywhere-opensource-src-$QT_VER.tar.xz

# URLS
PNG_URL=https://download.sourceforge.net/libpng/$PNG_FILE
JPG_URL=https://ijg.org/files/$JPG_FILE
PSQL_URL=https://ftp.postgresql.org/pub/source/v$PSQL_VER/$PSQL_FILE
QT_URL=https://download.qt.io/official_releases/qt/5.15/$QT_VER/single/$QT_FILE

# Environment variables for cmake (needed by qtwebkit to find png, jpeg libs)
export CMAKE_INCLUDE_PATH="$LIBS_INSTALL_PREFIX/include"
export CMAKE_LIBRARY_PATH="$LIBS_INSTALL_PREFIX/lib"

# =================================================================================
# Define the functions

function install_prerequisites {
    echo "Running build step install_prerequisites..."

    cd "$SRC_DIR"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        install_macos_prerequisites
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        install_linux_prerequisites
    fi
}

function download_sources {
    echo "Running build step download_sources..."

    cd "$SRC_DIR"

    if [ ! -e "$PNG_FILE" ]; then
        echo "Downloading $PNG_FILE..."
        curl -O -L $PNG_URL || return $?
    fi
    rm -rf $PNG_NAME
    echo "Unpacking $PNG_FILE..."
    tar -xf $PNG_FILE || return $?


    if [ ! -e "$JPG_FILE" ]; then
        echo "Downloading $JPG_FILE..."
        curl -O -L $JPG_URL || return $?
    fi
    rm -rf $JPG_NAME
    echo "Unpacking $JPG_FILE..."
    tar -xf $JPG_FILE || return $?


    if [ ! -e "$PSQL_FILE" ]; then
        echo "Downloading $PSQL_FILE..."
        curl -O -L $PSQL_URL || return $?
    fi
    rm -rf $PSQL_NAME
    echo "Unpacking $PSQL_FILE..."
    tar -xf $PSQL_FILE || return $?


    if [ ! -e "$QT_FILE" ]; then
        echo "Downloading $QT_FILE..."
        curl -O -L $QT_URL || return $?
    fi
    rm -rf $QT_NAME
    echo "Unpacking $QT_FILE..."
    tar \
        --exclude="$QT_NAME/qt3d" \
        --exclude="$QT_NAME/qtdatavis3d" \
        --exclude="$QT_NAME/qtquick3d" \
        --exclude="$QT_NAME/qtwebengine" \
        -xf $QT_FILE || return $?

    echo "Patching $QT_NAME..."
    patch --batch -d "$SRC_DIR/$QT_NAME/qtbase" -p1 < "$SCRIPT_DIR/patches/qt-mac-build-fix-cdf64b0.diff" || return $?
    patch --batch -d "$SRC_DIR/$QT_NAME" -p1 < "$SCRIPT_DIR/patches/qt-mbgl-mac-build-fix.patch" || return $?
    patch --batch -d "$SRC_DIR/$QT_NAME" -p1 < "$SCRIPT_DIR/patches/qt-avf-cpp17-mac-fix.patch" || return $?


    if [ ! -d $WEBKIT_NAME ]; then
        echo "Cloning qtwebkit..."
        git clone --depth=1 https://github.com/dilshodm/$WEBKIT_NAME.git || return $?
    else
        echo "Updating qtwebkit..."
        cd $WEBKIT_NAME
        git pull || return $?
        cd ..
    fi

    return 0
}

function build_png {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step build_png..."

        rm -rf "$BUILD_DIR/$PNG_NAME"
        mkdir -p "$BUILD_DIR/$PNG_NAME"
        cd "$BUILD_DIR/$PNG_NAME" || return $?

        cmake "$SRC_DIR/$PNG_NAME" -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
            -DCMAKE_INSTALL_PREFIX="$LIBS_INSTALL_PREFIX" \
            -DPNG_SHARED=OFF -DPNG_FRAMEWORK=OFF -DPNG_TESTS=OFF -DPNG_TOOLS=OFF \
            -DPNG_HARDWARE_OPTIMIZATIONS=OFF || return $?
        cmake --build . --config Release || return $?
        cmake --install . || return $?
    )
}

function build_jpg {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step build_jpg..."

        set_cflags

        rm -rf "$BUILD_DIR/$JPG_NAME"
        mkdir -p "$BUILD_DIR/$JPG_NAME"
        cd "$BUILD_DIR/$JPG_NAME" || return $?

        "$SRC_DIR/$JPG_NAME/configure" --disable-shared --prefix="$LIBS_INSTALL_PREFIX" || return $?
        make -j $NPROC || return $?
        make install || return $?
    )
}

function build_psql {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step build_psql..."

        set_cflags

        # Building in the source directory, out of source build fails
        cd "$SRC_DIR/$PSQL_NAME" || return $?
        if [ -e "Makefile" ]; then
            make clean
        fi

        ./configure --without-icu --prefix="$PSQL_INSTALL_PREFIX" || return $?
        make -j $NPROC || return $?
        make install || return $?
    )
}

function prep_qt {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step prep_qt..."

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            return 0
        fi

        rm -rf "$BUILD_DIR/$QT_NAME" || return $?
        mkdir -p "$BUILD_DIR/$QT_NAME"
        cd "$BUILD_DIR/$QT_NAME" || return $?

        # macOS
        "$SRC_DIR/$QT_NAME/configure" -opensource -confirm-license -release \
            -prefix "$QT_DIR" -silent \
            -qt-zlib -qt-pcre -qt-libpng -qt-libjpeg \
            -qt-freetype -qt-harfbuzz -qt-doubleconversion \
            -nomake tests -nomake examples -no-openssl -securetransport \
            -sql-psql -I "$PSQL_INSTALL_PREFIX/include" -L "$PSQL_INSTALL_PREFIX/lib" \
            -skip qt3d -skip qtquick3d -skip qtactiveqt -skip qtdatavis3d \
            -skip qtdoc -skip qtwebengine \
            QMAKE_APPLE_DEVICE_ARCHS="x86_64 arm64" || return $?
    )
}

function build_qt {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step build_qt..."

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            return 0
        fi

        cd "$BUILD_DIR/$QT_NAME" || return $?
        make -j $NPROC || return $?
    )
}

function install_qt {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step install_qt..."

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            return 0
        fi

        cd "$BUILD_DIR/$QT_NAME" || return $?
        make -j $NPROC install || make -j $NPROC install || return $?
    )
}

function prep_webkit {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step prep_webkit..."

        set_qmake || return $?

        rm -rf "$BUILD_DIR/$WEBKIT_NAME"
        mkdir -p "$BUILD_DIR/$WEBKIT_NAME"
        cd "$BUILD_DIR/$WEBKIT_NAME" || return $?

        if [[ "$OSTYPE" == "darwin"* ]]; then
            cmake -G Ninja -DPORT=Qt -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
                -DQt5_DIR="$QT_DIR/lib/cmake/Qt5" \
                -DCMAKE_INSTALL_PREFIX="$QT_DIR" \
                -DENABLE_WEBKIT2=OFF \
                -DENABLE_TOOLS=OFF \
                -DENABLE_TEST_SUPPORT=OFF \
                -DENABLE_GEOLOCATION=OFF \
                -DENABLE_DEVICE_ORIENTATION=OFF \
                "$SRC_DIR/$WEBKIT_NAME" || return $?

        else
            # Linux
            cmake -G Ninja -DPORT=Qt -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_CXX_STANDARD=17 \
                -DQt5_DIR="$QT_DIR/lib/cmake/Qt5" \
                -DENABLE_WEBKIT2=OFF \
                -DENABLE_TOOLS=OFF \
                -DENABLE_TEST_SUPPORT=OFF \
                -DENABLE_GEOLOCATION=OFF \
                -DENABLE_DEVICE_ORIENTATION=OFF \
                "$SRC_DIR/$WEBKIT_NAME" || return $?
        fi
    )
}

function build_webkit {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step build_webkit..."

        set_qmake || return $?

        cd "$BUILD_DIR/$WEBKIT_NAME" || return $?
        cmake --build . || return $?
    )
}

function install_webkit {
    # Use subshell to keep env vars local to this step
    (
        echo "Running build step install_webkit..."

        cd "$BUILD_DIR/$WEBKIT_NAME" || return $?
        cmake --install . || return $?
    )
}

# HELPER FUNCTIONS ================================================================

function set_cflags {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Build universal binaries for mac osx
        export CFLAGS="-O2 -arch arm64 -arch x86_64"
        export CXXFLAGS="-O2 -arch arm64 -arch x86_64"
        export LDFLAGS="-arch arm64 -arch x86_64"
    fi

    return 0
}

function set_qmake {
    export PATH=$QT_DIR/bin:$PATH
    return 0
}

function num_cores {
    # Check the number of processor cores based on the OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sysctl -n hw.ncpu
    else
        # Linux
        nproc
    fi
}

function install_macos_prerequisites {
    # Install prerequisites

    # Check if python2.7 or python2 command exists
    if command -v python2.7 &> /dev/null
    then
        echo "Python 2.7 is installed"
    else
        echo "Python 2.7 is not installed. Installing..."
        curl -O -L https://www.python.org/ftp/python/2.7.18/python-2.7.18-macosx10.9.pkg || return $?
        sudo installer -pkg python-2.7.18-macosx10.9.pkg -target / || return $?
        rm python-2.7.18-macosx10.9.pkg
    fi

#    brew install cmake ninja python3 perl autoconf pkg-config || return $?

    return 0
}

function install_linux_prerequisites {
    # Install prerequisites

    if [ -f /etc/debian_version ]; then
        # Debian-based
        sudo apt-add-repository universe    # for python2.7
        sudo apt-get update || return $?
        sudo apt-get install -y build-essential cmake ninja-build python3 python2-minimal perl autoconf pkg-config ruby || return $?
    else
        echo "Unsupported Linux distribution, install using package manager following:"
        echo "cmake ninja python3 python2 perl autoconf pkg-config ruby"
    fi

    return 0
}

# Function to get the owner of a directory
get_owner() {
    DIR=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses -f '%Su' to get the user name
        stat -f '%Su' "$DIR"
    else
        # Assume Linux with GNU stat uses -c '%U' to get the user name
        stat -c '%U' "$DIR"
    fi
}

# Function to create directory and handle permissions
create_dir() {
    DIR=$1

    if [ -d "$DIR" ]; then
        # Directory exists
        echo "Directory $DIR already exists."
        OWNER=$(get_owner "$DIR")

        if [ "$OWNER" != "$USER" ]; then
            echo "Directory $DIR is not owned by user $USER. Changing ownership..."
            sudo chown "$USER" "$DIR"
            echo "Ownership of $DIR changed to user $USER."
        else
            echo "Directory $DIR is already owned by user $USER."
        fi
    else
        # Directory does not exist, try to create it without sudo
        mkdir -p "$DIR" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "Directory $DIR created successfully without sudo."
        else
            echo "Directory $DIR requires sudo to create."
            sudo mkdir -p "$DIR"

            if [ $? -eq 0 ]; then
                echo "Directory $DIR created successfully with sudo."
                # Change ownership of the last directory to the current user
                sudo chown "$USER" "$DIR"
                echo "Ownership of $DIR changed to user $USER."
            else
                echo "Failed to create directory $DIR even with sudo."
                exit 1
	    fi
        fi
    fi
}

# =================================================================================

# Determine the operating system
NPROC=$(num_cores) # Number of processors to use for make

# Ask for sudo password at the beginning
#echo "Some commands to install to /usr/local will require sudo access. Please enter it now."
#sudo -v || (echo "Please enter correct password. Exiting..."; exit 1)

# Keep sudo alive by periodically updating the timestamp until the script finishes
# This runs in the background
#while true; do sudo -n true; sleep 60; done 2>/dev/null &
#SUDO_PID=$!
#trap 'kill $SUDO_PID' EXIT

create_dir "$SRC_DIR"
create_dir "$BUILD_DIR"

create_dir "$QT_DIR"

# Read the last successful step from the file, if it exists
if [ -f "$STATE_FILE" ]; then
    LAST_SUCCESSFUL_STEP=$(cat "$STATE_FILE")
else
    LAST_SUCCESSFUL_STEP=0
fi

# Loop through the build steps, starting from the next step after the last successful one
for (( i = LAST_SUCCESSFUL_STEP; i < ${#BUILD_STEPS[@]}; i++ )); do
    STEP=${BUILD_STEPS[$i]}
    echo && echo "Starting $STEP..."

    # Run the current step
    $STEP

    # Check if the step was successful
    if [ $? -ne 0 ]; then
        echo "$STEP failed. Exiting..."
        exit 1
    fi

    # Update the state file with the current step number
    echo $((i + 1)) > "$STATE_FILE"
done

echo "All build steps completed successfully."
echo "To rebuild again, remove $STATE_FILE"
