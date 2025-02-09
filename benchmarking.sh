#!/bin/bash
# run_sysbench.sh
#
# This script runs a suite of sysbench benchmarks:
#   - CPU (single core and all cores)
#   - Memory
#   - File I/O (prepare, run, cleanup)
#   - Threads (dummy test)
#   - Mutex
#
# Progress messages are printed to the console,
# and all output is compiled into a minimalistic report file.
#
# Make sure sysbench is installed on your system.

# Name of the output report file
OUTPUT_FILE="sysbench_results.txt"

# Helper function to print and log messages
log() {
    echo -e "$1" | tee -a "$OUTPUT_FILE"
}

# Check if sysbench is installed
if ! command -v sysbench >/dev/null 2>&1; then
    echo "Error: sysbench is not installed. Please install sysbench and try again." >&2
    exit 1
fi

# Start a new report
cat <<EOF > "$OUTPUT_FILE"
========================================
         Sysbench Benchmark Report
         Started: $(date)
========================================

EOF

##############################
# CPU Benchmark (Single Core)
##############################
log ">> Starting CPU benchmark (Single Core)..."
log "----------------------------------------"
# Run the CPU test with 1 thread and a high prime limit (tweak --cpu-max-prime as needed)
sysbench cpu --cpu-max-prime=20000 --threads=1 run | tee -a "$OUTPUT_FILE"
log ">> Completed CPU benchmark (Single Core)."
log "\n"

#############################
# CPU Benchmark (All Cores)
#############################
NUM_THREADS=$(nproc)
log ">> Starting CPU benchmark (All Cores: $NUM_THREADS threads)..."
log "----------------------------------------"
sysbench cpu --cpu-max-prime=20000 --threads="$NUM_THREADS" run | tee -a "$OUTPUT_FILE"
log ">> Completed CPU benchmark (All Cores)."
log "\n"

########################
# Memory Benchmark Test
########################
log ">> Starting Memory benchmark..."
log "----------------------------------------"
# The memory test will transfer a total of 10GB (adjust as needed)
sysbench memory --memory-total-size=10G run | tee -a "$OUTPUT_FILE"
log ">> Completed Memory benchmark."
log "\n"

#########################
# File I/O Benchmark Test
#########################
log ">> Starting File I/O benchmark..."
log "----------------------------------------"
# Prepare the file I/O test (this creates test files totaling 1GB)
log ">> Preparing File I/O test..."
sysbench fileio --file-total-size=1G prepare | tee -a "$OUTPUT_FILE"

# Run the file I/O test
log ">> Running File I/O test..."
sysbench fileio --file-total-size=1G run | tee -a "$OUTPUT_FILE"

# Cleanup test files
log ">> Cleaning up File I/O test..."
sysbench fileio --file-total-size=1G cleanup | tee -a "$OUTPUT_FILE"
log ">> Completed File I/O benchmark."
log "\n"

########################
# Threads Benchmark Test
########################
log ">> Starting Threads benchmark..."
log "----------------------------------------"
sysbench threads run | tee -a "$OUTPUT_FILE"
log ">> Completed Threads benchmark."
log "\n"

########################
# Mutex Benchmark Test
########################
log ">> Starting Mutex benchmark..."
log "----------------------------------------"
sysbench mutex run | tee -a "$OUTPUT_FILE"
log ">> Completed Mutex benchmark."
log "\n"

log "========================================"
log "Benchmarking complete. Results saved in: $OUTPUT_FILE"
