#!/bin/bash
# run_sysbench.sh
#
# This script runs a suite of sysbench benchmarks and saves a minimalistic
# summary of each test (capturing only the last few lines of output) to a text file.
#
# Make sure sysbench is installed on your system.

OUTPUT_FILE="sysbench_results.txt"

# Print a header to the output file.
cat <<EOF > "$OUTPUT_FILE"
========================================
       Sysbench Benchmark Report Summary
       Started: $(date)
========================================

EOF

# Helper function to run a benchmark test,
# capture its output, and then extract a short summary.
run_benchmark() {
    local test_label="$1"
    shift
    echo ">> Starting ${test_label}..." | tee -a "$OUTPUT_FILE"
    # Run the sysbench command passed as arguments and capture the output.
    output=$("$@" 2>&1)
    # Extract the last 5 lines of output (assumed to be the summary).
    summary=$(echo "$output" | tail -n 5)
    echo "$summary" | tee -a "$OUTPUT_FILE"
    echo ">> Completed ${test_label}." | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
}

# Check if sysbench is installed.
if ! command -v sysbench >/dev/null 2>&1; then
    echo "Error: sysbench is not installed. Please install sysbench and try again." >&2
    exit 1
fi

##############################
# CPU Benchmark (Single Core)
##############################
run_benchmark "CPU Benchmark (Single Core)" sysbench cpu --cpu-max-prime=20000 --threads=1 run

#############################
# CPU Benchmark (All Cores)
#############################
NUM_THREADS=$(nproc)
run_benchmark "CPU Benchmark (All Cores with ${NUM_THREADS} Threads)" sysbench cpu --cpu-max-prime=20000 --threads="$NUM_THREADS" run

########################
# Memory Benchmark Test
########################
run_benchmark "Memory Benchmark" sysbench memory --memory-total-size=10G run

#############################
# File I/O Benchmark Test
#############################
echo ">> Starting File I/O Benchmark..." | tee -a "$OUTPUT_FILE"
echo ">> Preparing test files..." | tee -a "$OUTPUT_FILE"
prepare_out=$(sysbench fileio --file-total-size=1G prepare 2>&1)
# (Optionally, you can omit or further summarize the prepare phase.)
echo ">> Running File I/O test..." | tee -a "$OUTPUT_FILE"
fio_run_out=$(sysbench fileio --file-total-size=1G run 2>&1)
echo ">> Cleaning up test files..." | tee -a "$OUTPUT_FILE"
cleanup_out=$(sysbench fileio --file-total-size=1G cleanup 2>&1)
# Capture only the summary from the 'run' phase.
fio_summary=$(echo "$fio_run_out" | tail -n 5)
echo "$fio_summary" | tee -a "$OUTPUT_FILE"
echo ">> Completed File I/O Benchmark." | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

########################
# Threads Benchmark Test
########################
run_benchmark "Threads Benchmark" sysbench threads run

########################
# Mutex Benchmark Test
########################
run_benchmark "Mutex Benchmark" sysbench mutex run

echo "========================================" | tee -a "$OUTPUT_FILE"
echo "Benchmarking complete. Summary saved in: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
