#!/bin/bash
# run_sysbench_one_line.sh
#
# Runs sysbench CPU (single-thread), memory, file I/O, threads, and mutex tests.
# Extracts a single numerical result per test and outputs a single CSV line.
#
# Expected output format:
#   <cpu_events/sec>,<memory_MB/sec>,<fileio_read_MiB/sec>,<threads_events/sec>,<mutex_events/sec>
# Example:
#   1499.85,204.12,98.45,522.18,8756.44
#
# Usage:
#   chmod +x run_sysbench_one_line.sh
#   ./run_sysbench_one_line.sh
#
OUTPUT_FILE="sysbench_values.txt"

# Ensure sysbench is installed
if ! command -v sysbench >/dev/null 2>&1; then
    echo "Error: sysbench is not installed. Install it and try again." >&2
    exit 1
fi

# 1. CPU Benchmark (Single Thread) - Extract "events per second"
cpu_output=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>&1)
cpu_value=$(echo "$cpu_output" | grep "events per second:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
cpu_value=${cpu_value:-0.00}  # Default to 0 if empty

# 2. Memory Benchmark - Extract "MB/sec"
mem_output=$(sysbench memory --memory-total-size=10G run 2>&1)
mem_value=$(echo "$mem_output" | grep -i "MB/sec" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
mem_value=${mem_value:-0.00}

# 3. File I/O Benchmark - Extract "read, MiB/s"
echo ">> Preparing File I/O test..."
sysbench fileio --file-total-size=1G prepare > /dev/null 2>&1
fio_output=$(sysbench fileio --file-total-size=1G run 2>&1)
fio_value=$(echo "$fio_output" | grep "read, MiB/s:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
fio_value=${fio_value:-0.00}
sysbench fileio --file-total-size=1G cleanup > /dev/null 2>&1

# 4. Threads Benchmark - Extract "events per second"
thr_output=$(sysbench threads run 2>&1)
thr_value=$(echo "$thr_output" | grep "events per second:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
thr_value=${thr_value:-0.00}

# 5. Mutex Benchmark - Extract "events per second"
mutex_output=$(sysbench mutex run 2>&1)
mutex_value=$(echo "$mutex_output" | grep "events per second:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
mutex_value=${mutex_value:-0.00}

# Generate single CSV line
result="${cpu_value},${mem_value},${fio_value},${thr_value},${mutex_value}"

# Save to output file
echo "$result" > "$OUTPUT_FILE"

# Print result
echo "$result"
