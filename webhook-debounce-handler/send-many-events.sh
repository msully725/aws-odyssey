#!/bin/bash

# Default maximum number of outstanding requests
DEFAULT_MAX_REQUESTS=20
DEFAULT_DURATION=60
DEFAULT_ID_CEILING=10

# Get the duration, max requests, and ID ceiling from the command-line arguments
DURATION=${1:-$DEFAULT_DURATION}
MAX_REQUESTS=${2:-$DEFAULT_MAX_REQUESTS}
ID_CEILING=${3:-$DEFAULT_ID_CEILING}

# Get the current time
START_TIME=$(date +%s)

# Function to generate a random payload with an ID ceiling
generate_payload() {
  RANDOM_ID=$(( ( RANDOM % ID_CEILING ) + 1 ))
  echo "{\"Id\":\"$RANDOM_ID\",\"payload\":\"data-$RANDOM_ID\"}"
}

# Loop to send requests for the specified duration
while [ $(( $(date +%s) - START_TIME )) -lt $DURATION ]; do
  # Generate a random payload
  PAYLOAD=$(generate_payload)

  # Call the send-event.sh script with the payload in the background
  ./send-event.sh "$PAYLOAD" &

  # Limit the number of outstanding requests
  while [ $(jobs | wc -l) -ge $MAX_REQUESTS ]; do
    sleep 0.1
  done
done

# Wait for all background jobs to finish
wait