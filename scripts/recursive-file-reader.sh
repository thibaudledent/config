#!/bin/bash

# Default values
MAX_LINES=100
TRUNCATE=false

# Show usage
show_usage() {
    echo "Usage: $0 [-t] [-l lines] <path>"
    echo "Options:"
    echo "  -t          Truncate files longer than max lines"
    echo "  -l lines    Set maximum number of lines (default: 100)"
    exit 1
}

# Parse command line options
while getopts "tl:h" opt; do
    case $opt in
        t)
            TRUNCATE=true
            ;;
        l)
            MAX_LINES=$OPTARG
            ;;
        h)
            show_usage
            ;;
        \?)
            show_usage
            ;;
    esac
done

# Shift to get the path argument
shift $((OPTIND-1))

# Check if path argument is provided
if [ $# -ne 1 ]; then
    show_usage
fi

# Check if path exists
if [ ! -d "$1" ]; then
    echo "Error: Path '$1' doesn't exist or is not a directory"
    exit 1
fi

# Function to display file content with optional truncation
display_file() {
    local file="$1"
    local line_count=$(wc -l < "$file")
    
    if [ "$TRUNCATE" = true ] && [ $line_count -gt $MAX_LINES ]; then
        # Calculate how many lines to show at start and end
        local half_max=$((MAX_LINES/2))
        echo -e "\n=== $file (truncated, total lines: $line_count) ==="
        # Show first half of MAX_LINES
        head -n $half_max "$file"
        echo -e "\n[...]\n"
        # Show last half of MAX_LINES
        tail -n $half_max "$file"
    else
        echo -e "\n=== $file ==="
        cat "$file"
    fi
    echo -e "\n"
}

# Process files
process_files() {
    # Using find with -not -path to exclude hidden files and directories
    find "$1" -type f \
        -not -path '*/\.*/*' \
        -not -name '.*' \
        | while read -r file; do
        if [ -r "$file" ]; then
            display_file "$file"
        else
            echo "Cannot read file: $file"
        fi
    done
}

# Call the function with the provided path
process_files "$1"
