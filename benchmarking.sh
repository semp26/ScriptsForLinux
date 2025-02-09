#!/bin/bash
OUTPUT_FILE="sysbench_values.txt"

# Ensure sysbench is installed
if ! command -v sysbench >/dev/null 2>&1; then
    echo "Error: sysbench is not installed." >&2
    exit 1
fi

# 1. CPU Benchmark (Single Thread)
cpu_output=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>&1)
cpu_value=$(echo "$cpu_output" | grep "events per second:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
cpu_value=${cpu_value:-0.00}

# 2. Memory Benchmark
mem_output=$(sysbench memory --memory-total-size=10G run 2>&1)
mem_value=$(echo "$mem_output" | grep -i "transferred" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
mem_value=${mem_value:-0.00}

# 3. File I/O Benchmark
echo ">> Preparing File I/O..."
sysbench fileio --file-total-size=1G prepare > /dev/null 2>&1
fio_output=$(sysbench fileio --file-total-size=1G run 2>&1)
fio_value=$(echo "$fio_output" | grep -Eo 'read, MiB/s: [0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
fio_value=${fio_value:-0.00}
sysbench fileio --file-total-size=1G cleanup > /dev/null 2>&1

# 4. Threads Benchmark
thr_output=$(sysbench threads run 2>&1)
thr_value=$(echo "$thr_output" | grep "events per second:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
thr_value=${thr_value:-0.00}

# 5. Mutex Benchmark
mutex_output=$(sysbench mutex run 2>&1)
mutex_value=$(echo "$mutex_output" | grep "events per second:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
mutex_value=${mutex_value:-0.00}

# Generate CSV output
result="${cpu_value},${mem_value},${fio_value},${thr_value},${mutex_value}"
echo "$result" > "$OUTPUT_FILE"
echo "$result"
