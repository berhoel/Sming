#!/bin/bash
#
# This file should be sourced after pulling in Sming repo, i.e:
#
#    . /opt/sming/Tools/install.sh
#

[ "$0" = "${BASH_SOURCE[0]}" ]; sourced=$?

inst_host=0
inst_doc=0
inst_esp8266=0
inst_esp32=0
inst_rp2040=0
err=0

FONT_PACKAGES=(\
    fonts-ubuntu \
    fonts-noto-mono \
    xfonts-base \
    fonts-urw-base35 \
    fonts-droid-fallback \
    )

EXTRA_PACKAGES=()
OPTIONAL_PACKAGES=()

for opt in "$@"; do
    opt=$(echo "$opt" | tr '[:upper:]' '[:lower:]')
    case $opt in
        all)
            inst_host=1
            inst_esp8266=1
            inst_esp32=1
            inst_rp2040=1
            ;;

        host | doc | esp8266 | esp32 | rp2040)
            eval "inst_$opt=1"
            ;;

        fonts)
            EXTRA_PACKAGES+=("${FONT_PACKAGES[@]}")
            ;;

        optional)
            OPTIONAL_PACKAGES+=(\
                clang-format-8 \
                "linux-modules-extra-$(uname -r)" \
                exfatprogs \
            )
            ;;

        *)
            echo "Unknown option '$opt'"
            err=1
            ;;
    esac
done

if [[ $err -eq 1 ]] || [ $# -eq 0 ]; then
    echo 'Sming Installation options:'
    echo '   host      Host development tools'
    echo '   esp8266   ESP8266 development tools'
    echo '   esp32     ESP32 development tools'
    echo '   rp2040    RP2040 tools (Raspberry Pi Pico)'
    echo '   all       Install all architectures'
    echo '   doc       Tools required to build documentation'
    echo '   fonts     Install fonts used by Graphics library (normally included with Ubuntu)'
    echo '   optional  Install optional development tools'
    echo
    if [ $sourced = 1 ]; then
        return 1
    else
        exit 1
    fi
fi

# Sming repository for binary archives
export SMINGTOOLS=https://github.com/SmingHub/SmingTools/releases/download/1.0

# Set default environment variables
source "$(dirname "${BASH_SOURCE[0]}")/export.sh"

export WGET="wget --no-verbose"

# Installers put downloaded archives here
DOWNLOADS="downloads"
mkdir -p $DOWNLOADS

# Identify package installer for distribution
if [[ "$(uname)" = "Darwin" ]]; then
    DIST=darwin
    PKG_INSTALL="brew install"
elif [ -n "$(command -v apt)" ]; then
    DIST=debian
    PKG_INSTALL="sudo apt-get install -y"
elif [ -n "$(command -v dnf)" ]; then
    DIST=fedora
    PKG_INSTALL="sudo dnf install -y"
else
    _OK=1
    echo "Unsupported distribution"
    _REQUIRED_TOOLS=(
            ccache \
            cmake \
            curl \
            git \
            make \
            ninja \
            unzip \
            g++ \
            python3 \
            pip3 \
	    wget \
	    )
    for _TOOL in "${_REQUIRED_TOOLS[@]}"; do
	if ! [ -x "$(command -v $_TOOL)" ]; then
	    _OK=0
	    echo "Install required tool ${_TOOL}"
	fi
    done
    if [ $_OK != 1 ]; then
    if [ $sourced = 1 ]; then
        return 1
    else
        exit 1
    fi
    fi
fi

# Common install

MACHINE_PACKAGES=()
case $DIST in
    debian)
        case $(uname -m) in
            arm | aarch64)
                ;;
            *)
                MACHINE_PACKAGES+=(g++-multilib)
                ;;
        esac
        if [ ${#OPTIONAL_PACKAGES[@]} ]; then
            # Provide repo. for clang-format-8 on Ubuntu 22.04
            sudo apt-add-repository -y 'deb http://mirrors.kernel.org/ubuntu focal main universe'
        fi
        sudo apt-get -y update || echo "Update failed... Try to install anyway..."
        $PKG_INSTALL \
            ccache \
            cmake \
            curl \
            git \
            make \
            ninja-build \
            unzip \
            g++ \
            python3 \
            python3-pip \
            python3-setuptools \
            wget \
            "${MACHINE_PACKAGES[@]}" \
            "${EXTRA_PACKAGES[@]}"

        if [ -n "$OPTIONAL_PACKAGES" ]; then
            $PKG_INSTALL "${OPTIONAL_PACKAGES[@]}" || printf "\nWARNING: Failed to install optional %s.\n\n" "$OPTIONAL_PACKAGES"
        fi
        ;;

    fedora)
        case $(uname -m) in
            x86_64)
                MACHINE_PACKAGES=(\
                    glibc-devel.i686 \
                    libstdc++.i686 \
                    )
                ;;
        esac
        $PKG_INSTALL \
            ccache \
            cmake \
            gawk \
            gcc \
            gcc-c++ \
            gettext \
            git \
            make \
            ninja-build \
            python3 \
            python3-pip \
            sed \
            unzip \
            wget \
            "${MACHINE_PACKAGES[@]}"
        ;;

    darwin)
        $PKG_INSTALL \
            ccache \
            binutils \
            coreutils \
            gnu-sed \
            ninja
        ;;

esac

if [ $(/usr/bin/python -c "import sys;print(sys.version_info[0])") != 3 ]; then
if [ "$DIST" != "darwin" ]; then
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 100
fi
fi

set -e

if [ -f "/usr/bin/clang-format-8" ]; then
    sudo update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-8 100
fi

python3 -m pip install --upgrade pip protobuf -r "$SMING_HOME/../Tools/requirements.txt"


install() {
    echo
    echo
    echo "** Installing $1 toolchain"
    echo
    source "$SMING_HOME/Arch/$1/Tools/install.sh"
}

if [ $inst_host -eq 1 ]; then
    install Host
fi

if [ $inst_doc -eq 1 ]; then
    source "$SMING_HOME/../docs/Tools/install.sh"
fi

if [ $inst_esp8266 -eq 1 ]; then
    install Esp8266
fi

if [ $inst_esp32 -eq 1 ]; then
    install Esp32
fi

if [ $inst_rp2040 -eq 1 ]; then
    install Rp2040
fi

if [ -z "$KEEP_DOWNLOADS" ]; then
    rm -rf "${DOWNLOADS:?}/"*
fi


echo
echo Installation complete
echo

if [ $sourced != 1 ]; then
    echo "You may need to set environment variables:"
    echo "  source $SMING_HOME/../Tools/export.sh"
    echo
fi
