#!/bin/bash

################################################################################
# regression.sh
# Simple CI/regression runner for the ariane testbench.
################################################################################

################################################################################
# FUNCTIONS
################################################################################

# ci_simulate <TEST> <TOP>
# Run a single test via `make simulate` and print a short status line with timing.
ci_simulate () {
  start_time=$(date +%s)
  # Print a timestamped, colored status message (yellow) without newline
  echo -n -e " $(date +%x\ %H:%M:%S) - \033[1;33mSIMULATING $1\033[0m"
  # Run the make simulate target quietly. STDERR/STDOUT are redirected to /dev/null
  make -s simulate TOP=sc_soc_tb TEST=$1 DEBUG=0 GUI=0 > /dev/null 2>&1
  end_time=$(date +%s)
  time_diff=$((end_time - start_time))
  # Print Done in green with elapsed time
  echo -e "\033[1G\033[1;32mDone!\033[0m ($time_diff seconds)   \033[21G - \033[1;33mSIMULATING $1\033[0m"
}

################################################################################
# CLEANUP
################################################################################

# Start a timer for the cleanup step
start_time=$(date +%s)
clear
make LOGO
# Inform the user we're cleaning temporary files (colored yellow)
echo -n -e " $(date +%x\ %H:%M:%S) - \033[1;33mCLEANING UP TEMPORARY FILES\033[0m"
# Use the project's Makefile to perform a full clean. Output is suppressed.
make -s clean_full > /dev/null 2>&1
end_time=$(date +%s)
time_diff=$((end_time - start_time))
echo -e "\033[1G\033[1;32mDone!\033[0m ($time_diff seconds)   \033[21G - \033[1;33mCLEANING UP TEMPORARY FILES\033[0m"

################################################################################
# SUBMODULE SETUP
################################################################################

start_time=$(date +%s)
echo -n -e " $(date +%x\ %H:%M:%S) - \033[1;33mSETTING UP SUBMODULES\033[0m"
git submodule update --init --depth 1
end_time=$(date +%s)
time_diff=$((end_time - start_time))
echo -e "\033[1G\033[1;32mDone!\033[0m ($time_diff seconds)   \033[21G - \033[1;33mSETTING UP SUBMODULES\033[0m"

################################################################################
# ENVIRONMENT BUILD SC-SOC
################################################################################

start_time=$(date +%s)
echo -n -e " $(date +%x\ %H:%M:%S) - \033[1;33mSETTING UP ENVIRONMENT FOR SC-SOC\033[0m"
make __ENV_BUILD__ TOP=sc_soc_tb > /dev/null 2>&1
end_time=$(date +%s)
time_diff=$((end_time - start_time))
echo -e "\033[1G\033[1;32mDone!\033[0m ($time_diff seconds)   \033[21G - \033[1;33mSETTING UP ENVIRONMENT FOR SC-SOC\033[0m"

################################################################################
# SIMULATE SC-SOC
################################################################################

ci_simulate nop.S

ci_simulate hello.c
ci_simulate loop.c
ci_simulate lsu.c
ci_simulate printf.c
ci_simulate uart.c

################################################################################
# COLLECT & PRINT
################################################################################

# Prepare a temporary file to gather issues
rm -rf temp_ci_issues
touch temp_ci_issues

# Extract common failure/warning markers from logs into the temp file
grep -s -r "TEST FAILED" ./log >> temp_ci_issues
grep -s -r "ERROR:" ./log >> temp_ci_issues
grep -s -r "Fatal:" ./log >> temp_ci_issues

echo -e ""
echo -e "\033[1;36m___________________________ CI REPORT ___________________________\033[0m"
# Print lists of passed/failed/warnings/errors found in log files
grep -s -r "TEST PASSED" ./log
grep -s -r "TEST FAILED" ./log
grep -s -r "WARNING:" ./log
grep -s -r "ERROR:" ./log
grep -s -r "Fatal:" ./log

echo -e "\n"
echo -e "\033[1;36m____________________________ SUMMARY ____________________________\033[0m"
echo -n "PASS    : "

# Print counts for each category (PASS/FAIL/WARNING/ERROR/Fatal)
grep -s -r "TEST PASSED" ./log | wc -l
echo -n "FAIL    : "
grep -s -r "TEST FAILED" ./log | wc -l
echo -n "WARNING : "
grep -s -r "WARNING:" ./log | wc -l
echo -n "ERROR   : "
grep -s -r "ERROR:" ./log | wc -l
echo -n "Fatal   : "
grep -s -r "Fatal:" ./log | wc -l
echo -e ""

# Move the collected issues into the log directory for inspection
mv temp_ci_issues ./log/ci_issues.log
