#!/bin/bash

# Declare an associative array to store source and destination
declare -A file_mapping

# Function to copy files
copy_files() {
    local source="$1"
    local destination="$2"

    # Check if source file exists
    if [[ -f "$source" ]]; then
        # Copy source to destination
        # cp "$source" "$destination"
        echo "Copied: $source -> $destination"
    else
        echo "Source file not found: $source"
    fi
}

# Load the configuration file and parse it line by line
if [[ -f "config.csv" ]]; then
    while IFS=',' read -r task source destination; do
        echo "running $task "
        copy_files "$source" "$destination"
        
        # Modify $task to ensure it's a valid array key
        # Remove spaces and problematic characters
        task=${task//[^a-zA-Z0-9_]/_}

        # Append source and destination to the associative array
        file_mapping["$task"]=$source:$destination
    done < "config.csv"

    # Print the associative array for reference
    for key in "${!file_mapping[@]}"; do
        echo "Task: $key, Source-Destination: ${file_mapping[$key]}"
    done
else
    echo "Configuration file 'config.csv' not found."
    exit 1
fi
