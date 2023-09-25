#!/bin/bash

# Function to copy files
copy_files() {
    local source="$1"
    local destination="$2"
    
    # Check if source file exists
    if [[ -f "$source" ]]; then
        # Copy source to destination
        cp "$source" "$destination"
        echo "Copied: $source -> $destination"
    else
        echo "Source file not found: $source"
    fi
}

# Load the configuration file
if [[ -f "config.conf" ]]; then
    . "config.conf"
else
    echo "Configuration file 'config.conf' not found."
    exit 1
fi

# Loop through sections in the configuration file
for section in $(cat "config.conf" | grep -E "^\[.*\]$"); do
    section="${section#[}"
    section="${section%]}"
    
    # Read source and destination from the section
    source="${section}_source"
    destination="${section}_destination"
    
    # Check if both source and destination are defined
    if [[ -v "$source" && -v "$destination" ]]; then
        copy_files "${!source}" "${!destination}"
    else
        echo "Missing source or destination in section: $section"
    fi
done
