#!/bin/bash

# Number of concurrent requests
CONCURRENT_REQUESTS=10

# Path to the trigger-event.sh script
TRIGGER_SCRIPT="./trigger-event.sh"

# Check if trigger-event.sh exists and is executable
if [ ! -x "$TRIGGER_SCRIPT" ]; then
    echo "Error: $TRIGGER_SCRIPT not found or not executable. Please ensure it exists and has execute permissions."
    exit 1
fi

echo "Starting $CONCURRENT_REQUESTS parallel requests using $TRIGGER_SCRIPT ..."

# Loop to trigger the event in parallel
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    # Call trigger-event.sh in the background
    $TRIGGER_SCRIPT &
done

# Wait for all background processes to finish
wait

echo "All requests completed."