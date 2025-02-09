#!/bin/bash
# run_benchmarks.sh
#
# This script installs required packages on a fresh Ubuntu Server 24.04,
# then gathers basic system info, runs disk I/O tests with fio,
# network tests with iperf3, and a Geekbench 5 benchmark.
#
# It prints progress messages to the console and saves a report (similar to your sample)
# in a timestamped file. Estimated total run time is ~15 minutes.
#
# IMPORTANT: Run this with Bash (e.g., sudo bash run_benchmarks.sh)

# --- Ensure noninteractive installation ---
export DEBIAN_FRONTEND=noninteractive

# --- Check for root privileges ---
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try using sudo." 1>&2
  exit 1
fi

# --- Record start time ---
START_TIME=$(date +%s)

echo "Starting Benchmark Script. Estimated total run time: ~15 minutes."

# --- Update package lists and install dependencies ---
echo "Updating package lists and installing dependencies..."
apt update
apt install -y fio iperf3 jq wget tar
echo "Dependencies installed."

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
> "$REPORTFILE"  # initialize/empty the file

# --- Utility Function ---
# Convert bits-per-second to a human-readable string.
convert_bps() {
  local bps=$1
  if (( bps >= 1000000000 )); then
    printf "%.2f Gbits/sec" "$(echo "$bps/1000000000" | bc -l)"
  else
    printf "%.2f Mbits/sec" "$(echo "$bps/1000000" | bc -l)"
  fi
}

#############################
# Start Report Generation   #
#############################

# Write header (date/time) to report
{
  date
  echo
} >> "$REPORTFILE"

#############################
# Basic System Information  #
#############################
echo "Collecting basic system information..."
{
  echo "Basic System Information:"
  echo "---------------------------------"

  uptime_out=$(uptime -p)
  echo "Uptime     : ${uptime_out#up }"

  cpu_model=$(lscpu | awk -F: '/Model name/ {gsub(/^ +/, "", $2); print $2; exit}')
  cpu_cores=$(lscpu | awk -F: '/^CPU\(s\)/ {gsub(/^ +/, "", $2); print $2; exit}')
  cpu_mhz=$(lscpu | awk -F: '/CPU MHz/ {gsub(/^ +/, "", $2); print $2; exit}')
  echo "Processor  : $cpu_model"
  echo "CPU cores  : $cpu_cores @ ${cpu_mhz} MHz"

  if grep -qi aes /proc/cpuinfo; then
    echo "AES-NI     : ✔ Enabled"
  else
    echo "AES-NI     : ❌ Disabled"
  fi

  if grep -qiE 'vmx|svm' /proc/cpuinfo; then
    echo "VM-x/AMD-V : ✔ Enabled"
  else
    echo "VM-x/AMD-V : ❌ Disabled"
  fi

  ram=$(free -h | awk '/^Mem:/ {print $2}')
  swap=$(free -h | awk '/^Swap:/ {print $2}')
  echo "RAM        : $ram"
  echo "Swap       : $swap"

  disk=$(df -h / | awk 'NR==2 {print $2}')
  echo "Disk       : $disk"

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Distro     : $PRETTY_NAME"
  else
    echo "Distro     : Unknown"
  fi

  echo "Kernel     : $(uname -r)"
  echo
} >> "$REPORTFILE"
echo "Basic system information collected."

#############################
# fio Disk Speed Tests      #
#############################
echo "Starting fio disk speed tests (approx 2 minutes total)..."
{
  echo "fio Disk Speed Tests (Mixed R/W 50/50):"
  echo "---------------------------------"
} >> "$REPORTFILE"

for bs in 4k 64k 512k 1m; do
    echo "  Running fio test with block size = $bs (30 seconds)..."
    fio --name=randrw --rw=randrw --rwmixread=50 \
        --ioengine=libaio --direct=1 --size=1G --runtime=30 \
        --bs=$bs --group_reporting > "$TMPDIR/fio_${bs}.txt" 2>&1
    echo "  Finished fio test for block size = $bs."
done

{
  echo
  echo "Results for fio tests:"
} >> "$REPORTFILE"

for bs in 4k 64k 512k 1m; do
    {
      echo "------ Block Size: $bs ------"
      cat "$TMPDIR/fio_${bs}.txt"
      echo
    } >> "$REPORTFILE"
done

rm -rf "$TMPDIR"
echo "fio tests completed."

#############################
# iperf3 Network Tests (IPv4)
#############################
echo "Starting iperf3 IPv4 tests (approx 1.5 minutes total)..."
{
  echo "iperf3 Network Speed Tests (IPv4):"
  echo "---------------------------------"
} >> "$REPORTFILE"

for entry in "${ipv4_servers[@]}"; do
    IFS='|' read -r provider location server <<< "$entry"
    echo "  Running iperf3 IPv4 test for $provider at $location..."
    result=$(iperf3 -c "$server" -t 10 -J 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
      sent=$(echo "$result" | jq '.end.sum_sent.bits_per_second')
      recv=$(echo "$result" | jq '.end.sum_received.bits_per_second')
      send_hr=$(convert_bps "$sent")
      recv_hr=$(convert_bps "$recv")
      line="$provider       | $location | Send Speed: $send_hr | Recv Speed: $recv_hr"
    else
      line="$provider       | $location | (Install jq to parse iperf3 JSON output)"
    fi
    echo "$line" >> "$REPORTFILE"
done
echo "iperf3 IPv4 tests completed."

#############################
# iperf3 Network Tests (IPv6)
#############################
echo "Starting iperf3 IPv6 tests (approx 1.5 minutes total)..."
{
  echo "iperf3 Network Speed Tests (IPv6):"
  echo "---------------------------------"
} >> "$REPORTFILE"

for entry in "${ipv6_servers[@]}"; do
    IFS='|' read -r provider location server <<< "$entry"
    echo "  Running iperf3 IPv6 test for $provider at $location..."
    result=$(iperf3 -c "$server" -t 10 -J 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
      sent=$(echo "$result" | jq '.end.sum_sent.bits_per_second')
      recv=$(echo "$result" | jq '.end.sum_received.bits_per_second')
      send_hr=$(convert_bps "$sent")
      recv_hr=$(convert_bps "$recv")
      line="$provider       | $location | Send Speed: $send_hr | Recv Speed: $recv_hr"
    else
      line="$provider       | $location | (Install jq to parse iperf3 JSON output)"
    fi
    echo "$line" >> "$REPORTFILE"
done
echo "iperf3 IPv6 tests completed."

#############################
# Geekbench 5 Benchmark Test#
#############################
echo "Starting Geekbench 5 test (this may take 5–10 minutes)..."
{
  echo "Geekbench 5 Benchmark Test:"
  echo "---------------------------------"
  echo "Running Geekbench 5… (this may take several minutes)"
} >> "$REPORTFILE"

gb_out=$(geekbench5 --upload 2>/dev/null)
gb_single=$(echo "$gb_out" | grep -i "Single-Core Score" | awk -F: '{print $2}' | xargs)
gb_multi=$(echo "$gb_out" | grep -i "Multi-Core Score" | awk -F: '{print $2}' | xargs)
gb_full=$(echo "$gb_out" | grep -Eo 'https?://[^ ]+' | head -n1)
{
  echo "Test            | Value"
  echo "                |"
  echo "Single Core     | ${gb_single:-N/A}"
  echo "Multi Core      | ${gb_multi:-N/A}"
  echo "Full Test       | ${gb_full:-N/A}"
  echo
  echo "Benchmark complete."
} >> "$REPORTFILE"
echo "Geekbench 5 test completed."

#############################
# Final Summary             #
#############################
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
echo "Benchmarking complete. Total elapsed time: ${ELAPSED} seconds."
echo "Benchmark report saved to $REPORTFILE"
