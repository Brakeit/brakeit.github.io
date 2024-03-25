#!/bin/bash

#
# This script mostly does sanity checks, and when needed, installs dependencies for Brakeit
# to work based on the platform. It checks for the most common package managers if they are
# available, binary on PATH (brew, apt, yay, dnf..), for Linux and MacOS, always prompts
# before running the commands.
#
# It then just git clones the BrokenSource repository and runs brakeit.py, sourcing the
# virtual environment and spawning a new user's default Shell on it.
#
# Feel free to Pull Request fixes and improvements at (https://github.com/Brakeit/brakeit.github.io)
#

INSTALL_MAX_ATTEMPTS=3
MACOS=0

if [ "$(uname)" == "Darwin" ]; then
  MACOS=1
fi

# # Utilities Functions

ask_continue() {
  while true; do
    echo ""
    read -p ":: Do you want to proceed? [y/n] " yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

# Warn MacOS wasn't tested but should work
if [ $MACOS -eq 1 ]; then
  echo "Warning - MacOS installation wasn't tested but should work, please report any issues for fixes"
  echo "• This script is safe and won't run any commands without your consent"
  ask_continue
fi

install_brew() {
  if [ $MACOS -eq 0 ]; then
    return
  fi
  while true; do
    if [ -z "$(command -v brew)" ]; then
      command="/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      echo "Homebrew wasn't found, will install it with the recommended official command:"
      echo "• ($command)\n"
      ask_continue
      eval $command
      continue
    fi
    break
  done
}

install_brakeit_dependencies() {

  # MacOS at least is "centralized"
  if [ $MACOS -eq 1 ]; then
    install_brew
    brew install python git
    return
  fi

  # Try finding common Linux package managers
  ARCHLINUX_PACKAGES="git python python-pip"
  UBUNTU_PACKAGES="git python3 python3-pip"
  FEDORA_PACKAGES="git python3 python3-pip"
  SUSE_PACKAGES="git python3 python3-pip"
  command=""
  if   [ -x "$(command -v apt)"    ]; then
    command="sudo apt install -y $UBUNTU_PACKAGES"
  elif [ -x "$(command -v yay)"    ]; then
    command="yay -Sy --noconfirm $ARCHLINUX_PACKAGES"
  elif [ -x "$(command -v paru)"   ]; then
    command="paru -Sy --noconfirm $ARCHLINUX_PACKAGES"
  elif [ -x "$(command -v pacman)" ]; then
    command="sudo pacman -Sy --noconfirm $ARCHLINUX_PACKAGES"
  elif [ -x "$(command -v dnf)"    ]; then
    command="sudo dnf install -y $FEDORA_PACKAGES"
  elif [ -x "$(command -v yum)"    ]; then
    command="sudo yum install -y $FEDORA_PACKAGES"
  elif [ -x "$(command -v zypper)" ]; then
    command="sudo zypper install -y $SUSE_PACKAGES"
  fi

  if [ -z "$command" ]; then
    echo "Couldn't find a Package Manager to install the dependencies"
    echo "• Consider sending a Pull Request for your platform"
    echo "• Will return and ignore, might cause recursion"
    ask_continue
    return
  fi

  echo "Will install dependencies with the following command:"
  echo "• ($command)\n"
  ask_continue
  eval $command
}

# # Have dependencies

python=""
for attempt in $(seq 1 $INSTALL_MAX_ATTEMPTS); do
  for option in python3 python; do
    if [ -x "$(command -v $option)" ]; then
      python=$(readlink -f $(which $option))
      echo "• Found Python at ($python)"
      break 2
    fi
  done
  if [ $attempt -eq $INSTALL_MAX_ATTEMPTS ]; then
    echo "Couldn't find Python after $INSTALL_MAX_ATTEMPTS attempts, things might not work.."
    ask_continue
  fi
  install_brakeit_dependencies
done

git=""
for attempt in $(seq 1 $INSTALL_MAX_ATTEMPTS); do
  if [ -x "$(command -v git)" ]; then
    git=$(readlink -f $(which git))
    echo "• Found Git at ($git)"
    break
  fi
  if [ $attempt -eq $INSTALL_MAX_ATTEMPTS ]; then
    echo "Couldn't find Git after $INSTALL_MAX_ATTEMPTS attempts, things might not work.."
    ask_continue
  fi
  install_brakeit_dependencies
done

# # "Standard" installation procedure

printf "\n:: Cloning BrokenSource Repository\n\n"
$git clone https://github.com/BrokenSource/BrokenSource --recurse-submodules --jobs 4
cd BrokenSource

printf "\n:: Checking out all submodules to Master\n"
git submodule foreach --recursive 'git checkout Master || true'

# Brakeit shouldn't spawn a shell on its own as that will be always bash
# in this script, but we want the user's shell defined in $SHELL
printf "\n:: Running brakeit.py\n"
BRAKEIT_NO_SHELL=1 $python ./brakeit.py
printf ":: Sourcing the Virtual Environment\n\n"
source `$python -m poetry env info --path`/bin/activate
exec $SHELL
