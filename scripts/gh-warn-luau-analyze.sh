while IFS="" read -r line || [ -n "$line" ]; do

    echo "$line"

    # Check if the line contains the error format
    if [[ "$line" == *"TypeError:"* ]]; then
        # Extract the file name and line number using string manipulation
        file_line="${line%%:*}"             # Get the part before the first colon
        message="${line#*: TypeError: }"    # Get the message after "TypeError: "

        # Extract the file and line number
        file="${file_line%(*}"               # Get the file name (everything before the '(')
        location="${file_line#*()}";         # Get the part inside parentheses (line and column)
        line_number="${location%%,*}";       # Extract the line number
        column_number="${location#*,}";      # Extract the column number

        # Generate GitHub Actions warning
        echo "::warning file=${file},line=${line_number},col=${column_number}::${message}"
    fi
done
