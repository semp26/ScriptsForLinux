#!/bin/bash
# Sysbench Benchmark Script
# Runs CPU (single-thread), memory, file I/O, threads, and mutex benchmarks
# Outputs a **single-line CSV** with results.

OUTPUT_FILE="sysbench_values.txt"

# Ensure sysbench is installed
if ! command -v sysbench >/dev/null 2>&1; then
    echo "Error: sysbench is not installed. Install it and try again." >&2
    exit 1
fi

# 1️⃣ CPU Benchmark (Single Thread) - Extract "events per second"
cpu_output=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>&1)
cpu_value=$(echo "$cpu_output" | grep -E "events per second:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
cpu_value=${cpu_value:-0.00}

# 2️⃣ Memory Benchmark - Extract "MB/sec"
mem_output=$(sysbench memory --memory-total-size=10G run 2>&1)
mem_value=$(echo "$mem_output" | grep -i "transferred" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
mem_value=${mem_value:-0.00}

# 3️⃣ File I/O Benchmark - Extract "read, MiB/s"
echo ">> Preparing File I/O..."
sysbench fileio --file-total-size=1G prepare > /dev/null 2>&1
fio_output=$(sysbench fileio --file-total-size=1G --file-test-mode=rndrd run 2>&1)
fio_value=$(echo "$fio_output" | grep -E "read, MiB/s:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
fio_value=${fio_value:-0.00}
sysbench fileio --file-total-size=1G cleanup > /dev/null 2>&1

# 4️⃣ Threads Benchmark - Extract "total number of events"
thr_output=$(sysbench threads --time=10 run 2>&1)
thr_value=$(echo "$thr_output" | grep -E "total number of events:" | grep -Eo '[0-9]+' | tail -n 1)
thr_value=${thr_value:-0}

# 5️⃣ Mutex Benchmark - Extract "time per event"
mutex_output=$(sysbench mutex --time=10 run 2>&1)
mutex_events=$(echo "$mutex_output" | grep -E "total number of events:" | grep -Eo '[0-9]+' | tail -n 1)
mutex_events=${mutex_events:-1} # Avoid division by zero

mutex_time=$(echo "$mutex_output" | grep -E "total time:" | grep -Eo '[0-9]+\.[0-9]+' | tail -n 1)
mutex_time=${mutex_time:-0.00}

# Calculate time per event (execution time / total events)
mutex_time_per_event=$(awk "BEGIN {print $mutex_time / $mutex_events}")

# Generate CSV output
result="${cpu_value},${mem_value},${fio_value},${thr_value},${mutex_time_per_event}"
echo "$result" > "$OUTPUT_FILE"
echo "$result"
