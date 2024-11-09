#!/bin/bash

# Default values
DEFAULT_CONCURRENT_REQUESTS=5
DEFAULT_DURATION_SECONDS=20

# Assign command-line arguments to variables, or use default values if not provided
CONCURRENT_REQUESTS=${1:-$DEFAULT_CONCURRENT_REQUESTS}
DURATION_SECONDS=${2:-$DEFAULT_DURATION_SECONDS}

# Path to the trigger-event.sh script
TRIGGER_SCRIPT="./trigger-event.sh"

# Check if trigger-event.sh exists and is executable
if [ ! -x "$TRIGGER_SCRIPT" ]; then
    echo "Error: $TRIGGER_SCRIPT not found or not executable. Please ensure it exists and has execute permissions."
    exit 1
fi

echo "Starting $CONCURRENT_REQUESTS parallel requests every iteration for $DURATION_SECONDS seconds using $TRIGGER_SCRIPT ..."

# Get the current time and calculate the end time
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION_SECONDS))

# Loop to keep sending requests until the duration ends
while [ $(date +%s) -lt $END_TIME ]; do
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        # Call trigger-event.sh in the background
        $TRIGGER_SCRIPT &
    done

    # Wait for all background processes to finish in this iteration
    wait
done

echo "Load test completed. Ran for $DURATION_SECONDS seconds with $CONCURRENT_REQUESTS concurrent requests per iteration."