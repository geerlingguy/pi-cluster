#!/bin/bash
set -e

# Raspberry Pi HDD/SDD benchmark script.
#
# A script I use to automate the running and reporting of benchmarks I compile
# for my YouTube channel.
#
# Usage:
#   # Run it locally (overriding mount path and test size).
#   $ sudo MOUNT_PATH=/mnt/sda1 TEST_SIZE=1g ./disk-benchmark.sh
#
#   # Run it straight from GitHub (with default options).
#   $ curl https://raw.githubusercontent.com/geerlingguy/pi-cluster/master/benchmarks/disk-benchmark.sh | sudo bash
#
# Author: Jeff Geerling, 2024

printf "\n"
printf "Disk benchmarks\n"

# Fail if $SUDO_USER is empty.
if [ -z "$SUDO_USER" ]; then
  printf "This script must be run with sudo.\n"
  exit 1;
fi

# Variables.
MOUNT_PATH=${MOUNT_PATH:-"/"}
USER_HOME_PATH=$(getent passwd $SUDO_USER | cut -d: -f6)
TEST_SIZE="100m"
IOZONE_INSTALL_PATH=$USER_HOME_PATH
IOZONE_VERSION=iozone3_506

cd $IOZONE_INSTALL_PATH

# Install dependencies.
if [ ! `which curl` ]; then
  printf "Installing curl...\n"
  apt-get install -y curl
  printf "Install complete!\n\n"
fi
if [ ! `which make` ]; then
  printf "Installing build tools...\n"
  apt-get install -y build-essential
  printf "Install complete!\n\n"
fi

# Download and build iozone.
if [ ! -f $IOZONE_INSTALL_PATH/$IOZONE_VERSION/src/current/iozone ]; then
  printf "Installing iozone...\n"
  curl "http://www.iozone.org/src/current/$IOZONE_VERSION.tar" | tar -x
  cd $IOZONE_VERSION/src/current
  case $(uname -m) in
    arm64|aarch64)
      make --quiet linux-arm
      ;;
    *)
      make --quiet linux-AMD64
  esac
  printf "Install complete!\n\n"
else
  cd $IOZONE_VERSION/src/current
fi

printf "Running iozone 4K / 1024K read and write tests...\n"
iozone_result=$(./iozone -e -I -a -s $TEST_SIZE -r 4k -r 1024k -i 0 -i 1 -i 2 -f $MOUNT_PATH/iozone | cut -c7-78 | tail -n6 | head -n4)
echo -e "$iozone_result"
printf "\n"

random_read_4k=$(echo -e "$iozone_result" | awk 'FNR == 3 {printf "%.2f", $7/(1024)}')
random_write_4k=$(echo -e "$iozone_result" | awk 'FNR == 3 {printf "%.2f", $8/(1024)}')
random_read_1024k=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.2f", $7/(1024)}')
random_write_1024k=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.2f", $8/(1024)}')
sequential_read_1024k=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.2f", $6/(1024)}')
sequential_write_1024k=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.2f", $4/(1024)}')
cat << EOF
# --- Copy and paste the result below ---

| Benchmark                  | Result |
| -------------------------- | ------ |
| iozone 4K random read      | $random_read_4k MB/s |
| iozone 4K random write     | $random_write_4k MB/s |
| iozone 1M random read      | $random_read_1024k MB/s |
| iozone 1M random write     | $random_write_1024k MB/s |
| iozone 1M sequential read  | $sequential_read_1024k MB/s |
| iozone 1M sequential write | $sequential_write_1024k MB/s |

# --- End result ---
EOF
printf "\n"

printf "Disk benchmark complete!\n\n"
