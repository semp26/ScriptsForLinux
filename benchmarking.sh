#!/bin/bash
# run_sysbench_one_line.sh
#
# This script runs several sysbench tests:
#   - CPU (single-threaded; metric: events per second)
#   - Memory (metric: MB/sec transferred)
#   - File I/O (metric: read throughput in MiB/s)
#   - Threads (metric: events per second)
#   - Mutex (metric: events per second)
#
# It extracts one numeric value from each test’s output and writes
# a single comma-separated line with just the values to the output file.
#
# Usage:
#   chmod +x run_sysbench_one_line.sh
#   ./run_sysbench_one_line.sh
#
# Expected output format (one line):
#   <cpu>,<memory>,<fileio>,<threads>,<mutex>
#
# Example:
#   1234.56,205.78,98.76,543.21,8765.43
#

# Check that sysbench is installed.
if ! command -v sysbench >/dev/null 2>&1; then
    echo "Error: sysbench is not installed. Please install sysbench and try again." >&2
    exit 1
fi

# 1. CPU Benchmark (Single Thread)
#    We'll extract the "events per second" value.
cpu_output=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>&1)
# Expecting a line like: "events per second:  1234.56"
cpu_value=$(echo "$cpu_output" | grep "events per second:" | tail -n 1 | awk '{print $NF}')

# 2. Memory Benchmark
#    We'll try to extract the throughput in MB/sec.
#    Depending on sysbench version, the output may contain a line similar to:
#       "transferred (MB/sec): 205.78"
mem_output=$(sysbench memory --memory-total-size=10G run 2>&1)
mem_value=$(echo "$mem_output" | grep -i "MB/sec" | grep -oE '[0-9]+\.[0-9]+' | tail -n 1)

# 3. File I/O Benchmark
#    We extract the "read, MiB/s:" value.
#    Example output line: "read, MiB/s:  98.76"
fio_output=$(sysbench fileio --file-total-size=1G run 2>&1)
fio_value=$(echo "$fio_output" | grep "read, MiB/s:" | grep -oE '[0-9]+\.[0-9]+' | tail -n 1)

# 4. Threads Benchmark
#    Extract the "events per second" value.
thr_output=$(sysbench threads run 2>&1)
thr_value=$(echo "$thr_output" | grep "events per second:" | tail -n 1 | awk '{print $NF}')

# 5. Mutex Benchmark
#    Extract the "events per second" value.
mutex_output=$(sysbench mutex run 2>&1)
mutex_value=$(echo "$mutex_output" | grep "events per second:" | tail -n 1 | awk '{print $NF}')

# Combine the values into one comma-separated line.
# Order: CPU events/sec, Memory MB/sec, File I/O (read MiB/s), Threads events/sec, Mutex events/sec
result="${cpu_value},${mem_value},${fio_value},${thr_value},${mutex_value}"

# Write the single-line result to the output file.
OUTPUT_FILE="sysbench_values.txt"
echo "$result" > "$OUTPUT_FILE"

# Also print the result to the console.
echo "$result"
