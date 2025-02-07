#!/bin/bash

# Install sysbench if not already installed
if ! command -v sysbench &> /dev/null
then
    echo "Sysbench not found, installing..."
    sudo apt-get update
    sudo apt-get install -y sysbench
fi

# Create a markdown file to save the results
output_file="sysbench_results.md"
echo "# Sysbench Benchmark Results" > $output_file
echo "" >> $output_file

# Function to run CPU benchmark
run_cpu_benchmark() {
    echo "Running CPU benchmark..."
    echo "## CPU Benchmark" >> $output_file
    sysbench cpu --cpu-max-prime=20000 run | tee -a $output_file
    echo "" >> $output_file
}

# Function to run file I/O benchmark
run_fileio_benchmark() {
    echo "Preparing file I/O benchmark..."
    sysbench fileio --file-total-size=1G prepare
    echo "Running file I/O benchmark..."
    echo "## File I/O Benchmark" >> $output_file
    sysbench fileio --file-total-size=1G --file-test-mode=rndrw --max-time=300 --max-requests=0 run | tee -a $output_file
    echo "Cleaning up file I/O benchmark..."
    sysbench fileio --file-total-size=1G cleanup
    echo "" >> $output_file
}

# Function to run memory benchmark
run_memory_benchmark() {
    echo "Running memory benchmark..."
    echo "## Memory Benchmark" >> $output_file
    sysbench memory --memory-block-size=1M --memory-total-size=10G run | tee -a $output_file
    echo "" >> $output_file
}

# Function to run threads benchmark
run_threads_benchmark() {
    echo "Running threads benchmark..."
    echo "## Threads Benchmark" >> $output_file
    sysbench threads --threads=64 --time=60 run | tee -a $output_file
    echo "" >> $output_file
}

# Function to run mutex benchmark
run_mutex_benchmark() {
    echo "Running mutex benchmark..."
    echo "## Mutex Benchmark" >> $output_file
    sysbench mutex --mutex-num=4096 --time=60 run | tee -a $output_file
    echo "" >> $output_file
}

# Run all benchmarks
run_all_benchmarks() {
    run_cpu_benchmark
    run_fileio_benchmark
    run_memory_benchmark
    run_threads_benchmark
    run_mutex_benchmark
}

# Execute all benchmarks
run_all_benchmarks

echo "Benchmark results saved to $output_file"
