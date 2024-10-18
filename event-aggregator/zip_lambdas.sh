#!/bin/bash

lambda_files=(
    "event_data_producer.py"
)

zip_lambda() {
    local python_file="$1"
    local zip_file="${python_file%.py}.zip"

    echo "Zipping $python_file into $zip_file..."

    zip -j $zip_file $python_file
}

for python_file in "${lambda_files[@]}"; do
    if [ -f "$python_file" ]; then
        zip_lambda "$python_file"
    else
        echo "Error: $python_file not found!"
    fi
done

echo "All lambda functions have been zipped!"