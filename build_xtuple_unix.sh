#!/bin/bash

# By Dilshod Mukhtarov <dilshodm@gmail.com> May 2024

# Build XTUPLE script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && source "$SCRIPT_DIR/setenv.sh" || exit 1

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
NPROC=$(num_cores) # Number of processors to use for make

# This is need to be done once after checking out from git
cd $XTUPLE/openrpt && qmake CONFIG+=release openrpt.pro && make -j $NPROC && cd $XTUPLE/csvimp && qmake CONFIG+=release csvimp.pro && make -j $NPROC

# This is need to me done every time when need to recompile xtuple
cd $XTUPLE && qmake CONFIG+=release xtuple.pro && make -j $NPROC

# This if for MacOS only
if [[ "$OSTYPE" == "darwin"* ]]; then
    macdeployqt $XTUPLE/bin/xtuple.app

    cp -R $XTUPLE/share/certificates $XTUPLE_BUILD/bin/xtuple.app/Contents/Resources/
    mkdir -p $XTUPLE_BUILD/bin/xtuple.app/Contents/Resources/dict
    cp $XTUPLE/share/dict/*.qm $XTUPLE_BUILD/bin/xtuple.app/Contents/Resources/dict
    mkdir -p $XTUPLE_BUILD/bin/xtuple.app/Contents/Resources/hunspell
    cp $XTUPLE/hunspell/English.* $XTUPLE_BUILD/bin/xtuple.app/Contents/Resources/hunspell

    mkdir -p $XTUPLE_BUILD/bin/xtuple.app/Contents/PlugIns
    cp $XTUPLE/csvimp/plugins/libcsvimpplugin.dylib $XTUPLE_BUILD/bin/xtuple.app/Contents/PlugIns/
    mkdir -p $XTUPLE_BUILD/bin/xtuple.app/Contents/PlugIns/designer
    cp $XTUPLE/widgets/libxtuplewidgets.dylib $XTUPLE_BUILD/bin/xtuple.app/Contents/PlugIns/designer
    cp -r $QT_DIR/plugins/webview $XTUPLE_BUILD/bin/xtuple.app/Contents/PlugIns/

    rm $XTUPLE_BUILD/bin/xtuple.dmg
    macdeployqt $XTUPLE_BUILD/bin/xtuple.app -dmg
fi

