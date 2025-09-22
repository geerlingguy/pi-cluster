#!/bin/bash
set -e

# Disk benchmark script (Enhanced)
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
# Author: Jeff Geerling, 2024 | Enhanced by SinaAboutalebi

# --- Colors ---
CYAN='\033[1;36m'
GREEN='\033[1;32m'
RESET='\033[0m'

# --- Functions ---
print_header() {
  echo -e "${CYAN}\n========================================"
  echo -e "$1"
  echo -e "========================================${RESET}"
}

print_success() {
  echo -e "${GREEN}$1${RESET}"
}

# --- Start ---
print_header "📀 Disk Benchmark Script"

# Fail if $SUDO_USER is empty.
if [ -z "$SUDO_USER" ]; then
  echo -e "\nThis script must be run with sudo.\n"
  exit 1
fi

# --- Parameters ---
MOUNT_PATH=${MOUNT_PATH:-"/"}
USER_HOME_PATH=$(getent passwd $SUDO_USER | cut -d: -f6)
TEST_SIZE=${TEST_SIZE:-"1g"}
IOZONE_INSTALL_PATH=$USER_HOME_PATH
IOZONE_VERSION=iozone3_506

print_header "📋 Benchmark Parameters"
echo "Mount path     : $MOUNT_PATH"
echo "Test file size : $TEST_SIZE"
echo "Running as     : $SUDO_USER"
echo "User home path : $USER_HOME_PATH"
echo

cd $IOZONE_INSTALL_PATH

# --- Dependency Installation ---
if ! command -v curl &> /dev/null; then
  print_header "Installing curl"
  apt-get install -y curl
  print_success "✔ curl installed"
fi

if ! command -v make &> /dev/null; then
  print_header "Installing build-essential"
  apt-get install -y build-essential
  print_success "✔ build-essential installed"
fi

# --- iozone Download/Build ---
if [ ! -f $IOZONE_INSTALL_PATH/$IOZONE_VERSION/src/current/iozone ]; then
  print_header "📦 Installing iozone"
  curl "http://www.iozone.org/src/current/$IOZONE_VERSION.tar" | tar -x
  cd $IOZONE_VERSION/src/current
  case $(uname -m) in
    arm64|aarch64)
      make --quiet linux-arm
      ;;
    *)
      make --quiet linux-AMD64
  esac
  print_success "✔ iozone compiled successfully"
else
  cd $IOZONE_VERSION/src/current
fi

# --- Run Test ---
print_header "🚀 Running iozone Tests"
echo "Running 4K and 1024K random/sequential read/write tests...\n"

iozone_result=$(./iozone -e -I -a -s $TEST_SIZE -r 4k -r 1024k -i 0 -i 1 -i 2 -f $MOUNT_PATH/iozone | cut -c7-100 | tail -n6 | head -n4)
echo -e "$iozone_result"
echo

# --- Parse Results ---
random_read_4k=$(echo -e "$iozone_result" | awk 'FNR == 3 {printf "%.2f", $7/(1024)}')
random_write_4k=$(echo -e "$iozone_result" | awk 'FNR == 3 {printf "%.2f", $8/(1024)}')
random_read_1024k=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.2f", $7/(1024)}')
random_write_1024k=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.2f", $8/(1024)}')
sequential_read_1024k=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.2f", $6/(1024)}')
sequential_write_1024k=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.2f", $4/(1024)}')

# --- IOPS Calculations ---
random_read_4k_iops=$(echo -e "$iozone_result" | awk 'FNR == 3 {printf "%.0f", $7/4}')
random_write_4k_iops=$(echo -e "$iozone_result" | awk 'FNR == 3 {printf "%.0f", $8/4}')
random_read_1024k_iops=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.0f", $7/1024}')
random_write_1024k_iops=$(echo -e "$iozone_result" | awk 'FNR == 4 {printf "%.0f", $8/1024}')

# --- Output Results ---
print_header "📊 Benchmark Results"

echo -e "${CYAN}🔁 Random I/O Performance:${RESET}"
printf "4K Random Read     : %-10s MB/s (%s IOPS)\n" "$random_read_4k" "$random_read_4k_iops"
printf "4K Random Write    : %-10s MB/s (%s IOPS)\n" "$random_write_4k" "$random_write_4k_iops"
printf "1M Random Read     : %-10s MB/s (%s IOPS)\n" "$random_read_1024k" "$random_read_1024k_iops"
printf "1M Random Write    : %-10s MB/s (%s IOPS)\n" "$random_write_1024k" "$random_write_1024k_iops"

echo -e "\n${CYAN}📂 Sequential I/O Performance:${RESET}"
printf "1M Sequential Read : %-10s MB/s\n" "$sequential_read_1024k"
printf "1M Sequential Write: %-10s MB/s\n" "$sequential_write_1024k"

print_header "✅ Disk Benchmark Complete"
