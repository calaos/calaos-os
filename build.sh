#!/bin/bash

# Copied from https://github.com/Angstrom-distribution/setup-scripts
# Modified for building calaos oe images

# Original script done by Don Darling
# Later changes by Koen Kooi and Brijesh Singh

# Revision history:
# 20090902: download from twiki
# 20090903: Weakly assign MACHINE and DISTRO
# 20090904:  * Don't recreate local.conf is it already exists
#            * Pass 'unknown' machines to OE directly
# 20090918: Fix /bin/env location
#           Don't pass MACHINE via env if it's not set
#           Changed 'build' to 'bitbake' to prepare people for non-scripted usage
#           Print bitbake command it executes
# 20091012: Add argument to accept commit id.
# 20091202: Fix proxy setup
#
# For further changes consult 'git log' or browse to:
#   http://git.angstrom-distribution.org/cgi-bin/cgit.cgi/setup-scripts/
# to see the latest revision history

# Use this till we get a maintenance branch based of the release tag


###############################################################################
# OE_BASE    - The root directory for all OE sources and development.
###############################################################################
export OE_BASE=${PWD}
export OE_BUILD_DIR=${PWD}
export OE_SOURCE_DIR=${PWD}/src
OE_LAYERS_TXT="${OE_BASE}/src/layers.txt"

# incremement this to force recreation of config files
OE_ENV_FILE=./env.sh

if ! git help log | grep -q no-abbrev ; then 
	echo "Your installed version of git is too old, it lacks --no-abbrev. Please install 1.7.6 or newer"
	exit 1
fi

red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
black='\e[0;30m'
BLACK='\e[1;30m'
green='\e[0;32m'
GREEN='\e[1;32m'
purple='\e[0;35m'
PURPLE='\e[1;35m'
brown='\e[0;33m'
BROWN='\e[1;33m'
bold='\033[1m'
nobold='\033[0m'
NC='\e[0m' # No Color

###############################################################################
# CONFIG_OE() - Configure OpenEmbedded
###############################################################################
function config_oe()
{

    MACHINE="${CL_MACHINE}"

    #--------------------------------------------------------------------------
    # Write out the OE bitbake configuration file.
    #--------------------------------------------------------------------------
    mkdir -p ${OE_BUILD_DIR}/conf


    if [ ! -e ${OE_BUILD_DIR}/conf/auto.conf ]; then
        cat > ${OE_BUILD_DIR}/conf/auto.conf <<_EOF
MACHINE ?= "${MACHINE}"
_EOF
    else
	eval "sed -i -e 's/^MACHINE.*$/MACHINE ?= \"${MACHINE}\"/g' ${OE_BUILD_DIR}/conf/auto.conf"
    fi
}



###############################################################################
# OE_CONFIG() - Configure OE for a target
###############################################################################
function oe_config()
{
    
    config_oe

    echo ""
    echo "Setup for ${CL_MACHINE} completed"
}

###############################################################################
# UPDATE_OE() - Update OpenEmbedded distribution.
###############################################################################
function update_oe()
{
    #manage meta-openembedded and meta-angstrom with layerman
    env gawk -v command=update -f ./scripts/layers.awk ${OE_LAYERS_TXT}

    #ugly hack to remove bbappend which doesn't exists with our various revisions
    rm -rf src/meta-ti/recipes-misc/images/cloud9-gnome-image.bb
    rm -rf src/meta-ti/recipes-misc/images/cloud9-image.bb
    rm -rf src/meta-ti/recipes-misc/images/ti-hw-bringup-image.bb
    rm -rf src/meta-ti/recipes-misc/images/cloud9-gfx-image.bb
    rm -rf src/meta-intel/common/recipes-graphics/mesa/mesa_9.1.5.bbappend
    rm -rf src/meta-openembedded/meta-systemd/oe-core/recipes-core/util-linux/util-linux_2.23.1.bbappend

}

function clone_or_update()
{
    dir=$1
    gitrepo=$2
    branch=$3

    echo "Syncing repository $gitrepo"

    if ! [ -e ${dir} ] ; then
        git clone $gitrepo $dir
        ( cd $dir; git checkout $branch; )
    else
        ( cd $dir; git clean -d -f -x; git reset --hard $branch; git checkout $branch; git pull --rebase; )
    fi
}

function jenkins_build()
{
    MACH=$1
    BRANCH="master"  #default to master branch
    [ ! -z "$2" ] && BRANCH=$2
    BUILDDIR=$(pwd)/calaos-os
    BUILD_TYPE=$3

    clone_or_update $BUILDDIR https://github.com/calaos/calaos-os.git $BRANCH
    cd $BUILDDIR

    ./build.sh init $MACH
    ./build.sh update
    ./build.sh config $MACH

    ###TODO: this need to be fixed properly to use relative path and not fixed
    #echo "FEED_DEPLOYDIR_BASE_URI = \"http://oe.calaos.fr/\"" >> conf/local.conf
    echo "DL_DIR = \"/home/ubuntu/calaos-os/downloads\"" >> conf/local.conf
    echo "SSTATE_DIR = \"/home/ubuntu/calaos-os/sstate-cache\"" >> conf/local.conf

    builddate=`date +%F`

    if [ "$BUILD_TYPE" = "STABLE" ]; then
        VERSION=$(git describe --tags --always master)
        tarfile="calaos-image-${MACH}-${VERSION}.tar.xz"
    else
        VERSION=$(git describe --long --tags --always master)
        tarfile="calaos-image-${MACH}-${VERSION}-${builddate}.tar.xz"
    fi
    echo "DISTRO_VERSION=\"$VERSION\"" >> conf/local.conf

    source ./env.sh

    bitbake calaos-image

    cd tmp-eglibc/deploy/images/$MACH
    if [ "$MACH" = "nuc" ] ; then
        imgfile="$(basename $(readlink -f calaos-image-${MACH}.hddimg))"
    else
        if [ "$MACH" = "n450" ] ; then
            imgfile="$(basename $(readlink -f calaos-image-${MACH}.hddimg))"
        else
            imgfile="$(basename $(readlink -f calaos-image-${MACH}.*-sdimg))"
        fi
    fi

    tar -cJvf $tarfile -h $imgfile

    type=experimental
    [ "$BUILD_TYPE" = "TESTING" ] && type=testing
    [ "$BUILD_TYPE" = "STABLE" ] && type=stable

    rsync -avz -e ssh $tarfile uploader@calaos.fr:/home/raoul/www/download.calaos.fr/$type/calaos-os/$MACH
    ssh uploader@calaos.fr tar -C /home/raoul/www/download.calaos.fr/$type/calaos-os/$MACH -xJvf /home/raoul/www/download.calaos.fr/$type/calaos-os/$MACH/$tarfile

    cd ../../../..
}

function tag()
{

    calaos_projects="calaos_base calaos_installer calaos-web-app"
    tag_name=$1
    if [ "$tag_name" == "delete" ]; then
	tag_name=$2
	delete="1"
    fi 
    
    echo -e "Create TAG $tag_name for "
    for p in $calaos_projects ; do
	echo -e "$p"
    done
    echo "."

    
    echo "Check if all calaos repositories are present in ../calaos directory"
    if [ ! -d "../calaos" ]; then
	echo "../calaos doesn't exist, creating."
	mkdir -p "../calaos"
    fi

    for p in $calaos_projects ; do
	cd "../calaos/"
	if [ ! -d "../calaos/$p" ] ; then
	   echo "$p doesnt exists clone it"
	   git clone "https://github.com/calaos/$p.git"
	fi
	cd $p
	if [ "$delete" ==  "1" ]; then
	    echo "Deleting tag $tag_name for $p :"
	    git tag -d $tag_name
	    git push origin :refs/tags/$tag_name
	else
	    echo "Creating tag $tag_name for $p :"
	    git tag $tag_name
	    git push --tag

	fi
	git tag
	cd ..
    done
    cd ../calaos-os/
    ./build.sh init
    if [ "$delete" == "1" ]; then
	echo "Deleting tag $tag_name for $p :"
	git tag -d $tag_name
	git push origin :refs/tags/$tag_name
    else
	echo "Creating tag $tag_name for $p :"
	git tag $tag_name
	git push --tag
    fi
    cd src/meta-calaos

    if [ "$delete" -eq "1" ]; then
	echo "Deleting tag $tag_name for $p :"
	git tag -d $tag_name
	git push origin :refs/tags/$tag_name
    else
	echo "Creating tag $tag_name for $p :"
	git tag $tag_name
	git push --tag
    fi
}

###############################################################################
# Build the specified OE packages or images.
###############################################################################

# FIXME: converted to case/esac

if [ $# -gt 0 ]
then
    case $1 in   
        "init" )
            shift
            CL_MACHINE=$1
            shift
            oe_config $*
            update_oe
            exit 0
            ;;
        "update" ) 
            update_oe
            exit 0
            ;;
        
        "config" )
            shift
            CL_MACHINE=$1
            shift
            oe_config $*
            exit 0
            ;;
        "jenkins" )  #Usage ./build.sh jenkins <MACHINE> <BRANCH> <TYPE>
            shift
            jenkins_build $*
            exit 0
	    ;;
        "tag" ) #Usage ./build.sh tag tag_name
            shift
            tag $*
            exit 0
    esac
fi

# Help Screen
echo -e "${CYAN}################################################################################${NC}"
echo -e "${CYAN}#                                                                              #${NC}"
echo -e "${CYAN}#    ${BLUE}Calaos OS build system - (c) The Calaos Team                        ${CYAN}#${NC}"
echo -e "${CYAN}#    ${BLUE}http://www.calaos.fr                                                ${CYAN}#${NC}"
echo -e "${CYAN}#                                                                              #${NC}"
echo -e "${CYAN}################################################################################${NC}"
echo ""
echo "Usage: $0 config <machine>"
echo "       $0 init <machine>"
echo "       $0 update"
echo ""
echo ""
echo "You must invoke \"$0 config <machine>\" and then \"$0 update\" prior"
echo "to your first bitbake command"
echo ""
echo "The <machine> argument can be one of the following"
echo "       intel-core2-32:       x86 Intel Atom board. Select it if you want to build an image for generic x86 32bits"
echo "       intel-corei7-64:      x86_64 Intel Board. Select it if you want to build an image for generic x86-64."
echo "       mele:                 Mele A1000/A2000 using A10 processor"
echo "       meleg:                Mele A1000G/A2000G using A10 processor"
echo "       cubieboard:           Cubieboard"
echo "       cubieboard2:          Cubieboard 2 (A20 cpu)"
echo "       raspberrypi:          Raspberry Pi"
echo "       olinuxino-a13:        Olinuxino A13"
echo "       beagleboard:          Beagleboard"
echo "       qemuarm:              Emulated ARM machine"
echo "       qemux86:              Emulated x86 machine"
echo ""
