#!/bin/bash

# Default duration in seconds
DEFAULT_DURATION=10

# Default maximum number of outstanding requests
DEFAULT_MAX_REQUESTS=20

# Get the duration and max requests from the command-line arguments
DURATION=${1:-$DEFAULT_DURATION}
MAX_REQUESTS=${2:-$DEFAULT_MAX_REQUESTS}

# Get the current time
START_TIME=$(date +%s)

# Function to generate a random payload
generate_payload() {
  echo "{\"id\":$RANDOM,\"payload\":\"data-$RANDOM\"}"
}

# Loop to send requests for the specified duration
while [ $(( $(date +%s) - START_TIME )) -lt $DURATION ]; do
  # Generate a random payload
  PAYLOAD=$(generate_payload)

  # Call the send-event.sh script with the payload in the background
  ./send-event.sh "$PAYLOAD" &

  # Limit the number of concurrent requests
  while [ $(jobs | wc -l) -ge $MAX_REQUESTS ]; do
    sleep 0.1  # Wait for some jobs to complete
  done
done

# Wait for all background processes to finish
wait

echo "Finished sending events for $DURATION seconds with a maximum of $MAX_REQUESTS concurrent requests."