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
echo "       n450:          x86 Intel Atom board. Select it if you want to build an image for generic x86 32bits"
echo "       nuc:           x86_64 Intel Board. Select it if you want to build an image for generic x86-64."
echo "       mele:          Mele A1000/A2000 using A10 processor"
echo "       meleg:         Mele A1000G/A2000G using A10 processor"
echo "       cubieboard:    Cubieboard"
echo "       cubieboard2:   Cubieboard 2 (A20 cpu)"
echo "       raspberrypi:   Raspberry Pi"
echo "       olinuxino-a13: Olinuxino A13"
echo "       beagleboard:   Beagleboard"
echo "       qemuarm:       Emulated ARM machine"
echo "       qemux86:       Emulated x86 machine"
echo ""
