#!/bin/bash

# Function to copy files
copy_files() {
    local source="$1"
    local destination="$2"
    
    # Check if source file exists
    if [[ -f "$source" ]]; then
        # Copy source to destination
        #cp "$source" "$destination"
        echo "Copied: $source -> $destination"
    else
        echo "Source file not found: $source"
    fi
}

# Load the configuration file and parse it line by line
if [[ -f "service.csv" ]]; then
    while IFS=',' read -r task source destination; do
		echo "running $task "
        copy_files "$source" "$destination"
    done < "./service.csv"
else
    echo "Configuration file 'config.csv' not found."
    exit 1
fi
