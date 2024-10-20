# Read the input file line by line
while IFS= read -r line; do
    # Use regex to capture file name, line number, column number, and message
    if [[ $line =~ ^(.+)\(([0-9]+),([0-9]+)\):\ (.+)$ ]]; then
        file="${BASH_REMATCH[1]}"
        line_number="${BASH_REMATCH[2]}"
        column_number="${BASH_REMATCH[3]}"
        message="${BASH_REMATCH[4]}"

        # Format output for GitHub Actions
        echo "::warning file=$file,line=$line_number,col=$column_number::${message}"
    fi
done < "$1"