#!/bin/bash
# run_benchmarks.sh
#
# This script installs the required packages on a fresh Ubuntu Server 24.04,
# then collects system info, runs disk I/O tests with fio,
# network tests with iperf3, and a Geekbench 5 benchmark.
#
# It generates a report similar to your sample.
#
# IMPORTANT:
# - Run this script with Bash, not sh:
#       sudo bash run_benchmarks.sh
# - An active Internet connection is required.

# --- Ensure noninteractive installation ---
export DEBIAN_FRONTEND=noninteractive

# --- Check for root privileges ---
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try using sudo." 1>&2
  exit 1
fi

# --- Update package lists and install dependencies ---
echo "Updating package lists and installing dependencies..."
apt update
apt install -y fio iperf3 jq wget tar

# --- Install Geekbench 5 CLI if not already installed ---
if ! command -v geekbench5 &>/dev/null; then
    echo "Geekbench5 CLI not found, downloading and installing..."
    # Set the version you wish to install.
    GEEKBENCH_VERSION="5.4.1"
    GEEKBENCH_TAR="Geekbench-${GEEKBENCH_VERSION}-Linux.tar.gz"
    GEEKBENCH_URL="https://cdn.geekbench.com/${GEEKBENCH_TAR}"

    wget -O "/tmp/${GEEKBENCH_TAR}" "${GEEKBENCH_URL}"
    if [ $? -ne 0 ]; then
      echo "Failed to download Geekbench 5. Please check the URL or your connection." 1>&2
      exit 1
    fi
    tar -xzf "/tmp/${GEEKBENCH_TAR}" -C /tmp
    # The Geekbench executable is inside a folder named "Geekbench-<version>-Linux"
    if [ -f "/tmp/Geekbench-${GEEKBENCH_VERSION}-Linux/geekbench5" ]; then
      cp "/tmp/Geekbench-${GEEKBENCH_VERSION}-Linux/geekbench5" /usr/local/bin/
      chmod +x /usr/local/bin/geekbench5
      echo "Geekbench5 installed successfully."
    else
      echo "Geekbench5 executable not found in the extracted archive." 1>&2
      exit 1
    fi
fi

# --- Configuration for iperf3 Test Servers ---
# (Edit these server entries to match your available iperf3 servers.)
ipv4_servers=(
  "Clouvider|London, UK (10G)|ipv4.london.clouvider.com"
  "Online.net|Paris, FR (10G)|ipv4.paris.online.net"
  "Hybula|The Netherlands (40G)|ipv4.netherlands.hybula.net"
  "Uztelecom|Tashkent, UZ (10G)|ipv4.tashkent.uztelecom.com"
  "Clouvider|NYC, NY, US (10G)|ipv4.nyc.clouvider.com"
  "Clouvider|Dallas, TX, US (10G)|ipv4.dallas.clouvider.com"
  "Clouvider|Los Angeles, CA, US (10G)|ipv4.losangeles.clouvider.com"
)

ipv6_servers=(
  "Clouvider|London, UK (10G)|ipv6.london.clouvider.com"
  "Online.net|Paris, FR (10G)|ipv6.paris.online.net"
  "Hybula|The Netherlands (40G)|ipv6.netherlands.hybula.net"
  "Uztelecom|Tashkent, UZ (10G)|ipv6.tashkent.uztelecom.com"
  "Clouvider|NYC, NY, US (10G)|ipv6.nyc.clouvider.com"
  "Clouvider|Dallas, TX, US (10G)|ipv6.dallas.clouvider.com"
  "Clouvider|Los Angeles, CA, US (10G)|ipv6.losangeles.clouvider.com"
)

# Temporary directory for fio test files
TMPDIR=$(mktemp -d)

# Create a timestamped report file.
REPORTFILE="benchmark_report_$(date +'%Y%m%d_%H%M%S').txt"

# --- Utility Function ---
# Convert bits-per-second to a human-readable string.
convert_bps() {
  local bps=$1
  if (( bps >= 1000000000 )); then
    # Convert to Gbits/sec
    printf "%.2f Gbits/sec" "$(echo "$bps/1000000000" | bc -l)"
  else
    # Convert to Mbits/sec
    printf "%.2f Mbits/sec" "$(echo "$bps/1000000" | bc -l)"
  fi
}

# --- Begin Report Generation ---
{
  # Header date/time (example: Thu 16 Jun 2022 10:42:59 AM CEST)
  date
  echo

  # --- Basic System Information ---
  echo "Basic System Information:"
  echo "---------------------------------"

  # Uptime (using uptime -p gives a “pretty” uptime)
  uptime_out=$(uptime -p)
  echo "Uptime     : ${uptime_out#up }"

  # Processor and CPU details (using lscpu)
  cpu_model=$(lscpu | awk -F: '/Model name/ {gsub(/^ +/, "", $2); print $2; exit}')
  cpu_cores=$(lscpu | awk -F: '/^CPU\(s\)/ {gsub(/^ +/, "", $2); print $2; exit}')
  cpu_mhz=$(lscpu | awk -F: '/CPU MHz/ {gsub(/^ +/, "", $2); print $2; exit}')
  echo "Processor  : $cpu_model"
  echo "CPU cores  : $cpu_cores @ ${cpu_mhz} MHz"

  # Check for AES-NI (search for "aes" in /proc/cpuinfo)
  if grep -qi aes /proc/cpuinfo; then
    echo "AES-NI     : ✔ Enabled"
  else
    echo "AES-NI     : ❌ Disabled"
  fi

  # Check for virtualization support (vmx for Intel, svm for AMD)
  if grep -qiE 'vmx|svm' /proc/cpuinfo; then
    echo "VM-x/AMD-V : ✔ Enabled"
  else
    echo "VM-x/AMD-V : ❌ Disabled"
  fi

  # RAM and Swap (from free -h)
  ram=$(free -h | awk '/^Mem:/ {print $2}')
  swap=$(free -h | awk '/^Swap:/ {print $2}')
  echo "RAM        : $ram"
  echo "Swap       : $swap"

  # Disk size (using df -h on the root filesystem)
  disk=$(df -h / | awk 'NR==2 {print $2}')
  echo "Disk       : $disk"

  # Distro (from /etc/os-release)
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Distro     : $PRETTY_NAME"
  else
    echo "Distro     : Unknown"
  fi

  # Kernel version
  echo "Kernel     : $(uname -r)"
  echo

  # --- fio Disk Speed Tests (Mixed R/W 50/50) ---
  echo "fio Disk Speed Tests (Mixed R/W 50/50):"
  echo "---------------------------------"

  # Run fio tests with different block sizes.
  for bs in 4k 64k 512k 1m; do
    echo "Running fio test with block size = $bs …"
    fio --name=randrw --rw=randrw --rwmixread=50 \
        --ioengine=libaio --direct=1 --size=1G --runtime=30 \
        --bs=$bs --group_reporting > "$TMPDIR/fio_${bs}.txt" 2>&1
  done

  echo
  echo "Results for fio tests:"
  for bs in 4k 64k 512k 1m; do
    echo "------ Block Size: $bs ------"
    cat "$TMPDIR/fio_${bs}.txt"
    echo
  done

  # Clean up temporary fio files
  rm -rf "$TMPDIR"

  # --- iperf3 Network Speed Tests (IPv4) ---
  echo "iperf3 Network Speed Tests (IPv4):"
  echo "---------------------------------"
  for entry in "${ipv4_servers[@]}"; do
    IFS='|' read -r provider location server <<< "$entry"
    echo -n "$provider       | $location | "
    # Run a 10-second iperf3 test in JSON mode.
    result=$(iperf3 -c "$server" -t 10 -J 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
      sent=$(echo "$result" | jq '.end.sum_sent.bits_per_second')
      recv=$(echo "$result" | jq '.end.sum_received.bits_per_second')
      send_hr=$(convert_bps "$sent")
      recv_hr=$(convert_bps "$recv")
      echo "Send Speed: $send_hr | Recv Speed: $recv_hr"
    else
      echo " (Install jq to parse iperf3 JSON output)"
    fi
  done
  echo

  # --- iperf3 Network Speed Tests (IPv6) ---
  echo "iperf3 Network Speed Tests (IPv6):"
  echo "---------------------------------"
  for entry in "${ipv6_servers[@]}"; do
    IFS='|' read -r provider location server <<< "$entry"
    echo -n "$provider       | $location | "
    result=$(iperf3 -c "$server" -t 10 -J 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
      sent=$(echo "$result" | jq '.end.sum_sent.bits_per_second')
      recv=$(echo "$result" | jq '.end.sum_received.bits_per_second')
      send_hr=$(convert_bps "$sent")
      recv_hr=$(convert_bps "$recv")
      echo "Send Speed: $send_hr | Recv Speed: $recv_hr"
    else
      echo " (Install jq to parse iperf3 JSON output)"
    fi
  done
  echo

  # --- Geekbench 5 Benchmark Test ---
  echo "Geekbench 5 Benchmark Test:"
  echo "---------------------------------"
  echo "Running Geekbench 5… (this may take several minutes)"
  gb_out=$(geekbench5 --upload 2>/dev/null)
  # Extract scores if possible.
  gb_single=$(echo "$gb_out" | grep -i "Single-Core Score" | awk -F: '{print $2}' | xargs)
  gb_multi=$(echo "$gb_out" | grep -i "Multi-Core Score" | awk -F: '{print $2}' | xargs)
  gb_full=$(echo "$gb_out" | grep -Eo 'https?://[^ ]+' | head -n1)
  echo "Test            | Value"
  echo "                |"
  echo "Single Core     | ${gb_single:-N/A}"
  echo "Multi Core      | ${gb_multi:-N/A}"
  echo "Full Test       | ${gb_full:-N/A}"
  echo

  echo "Benchmark complete."
} > "$REPORTFILE"

echo "Benchmark report saved to $REPORTFILE"
