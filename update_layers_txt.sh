#!/bin/bash

set -e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}"  )" && pwd  )

pushd $SCRIPTDIR/src > /dev/null

for entry in *
do
    if [ ! -d $entry ]; then
        continue
    fi

    cd $entry

    gitrev=$(git rev-parse HEAD)
    gitbranch=$(git rev-parse --abbrev-ref HEAD)
    gitrepo=$(git config --get remote.origin.url)

    echo $entry,$gitrepo,$gitbranch,$gitrev

    cd ..
done

popd > /dev/null
