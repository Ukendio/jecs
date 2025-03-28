import os

LCOV_FILE = "coverage.out"
OUTPUT_DIR = "coverage"

os.makedirs(OUTPUT_DIR, exist_ok=True)

def parse_lcov(content):
    """Parses LCOV data from a single string."""
    files = {}
    current_file = None

    for line in content.splitlines():
        if line.startswith("SF:"):
            current_file = line[3:].strip()
            files[current_file] = {"coverage": {}, "functions": []}
        elif line.startswith("DA:") and current_file:
            parts = line[3:].split(",")
            line_num = int(parts[0])
            execution_count = int(parts[1])
            files[current_file]["coverage"][line_num] = execution_count
        elif line.startswith("FN:") and current_file:
            parts = line[3:].split(",")
            line_num = int(parts[0])
            function_name = parts[1].strip()
            files[current_file]["functions"].append({"name": function_name, "line": line_num, "hits": 0})
        elif line.startswith("FNDA:") and current_file:
            parts = line[5:].split(",")
            hit_count = int(parts[0])
            function_name = parts[1].strip()
            for func in files[current_file]["functions"]:
                if func["name"] == function_name:
                    func["hits"] = hit_count
                    break

    return files

def read_source_file(filepath):
    """Reads source file content if available."""
    if not os.path.exists(filepath):
        return []

    with open(filepath, "r", encoding="utf-8") as f:
        return f.readlines()

def generate_file_html(filepath, coverage_data, functions_data):
    """Generates an HTML file for a specific source file."""
    filename = os.path.basename(filepath)
    source_code = read_source_file(filepath)
    html_path = os.path.join(OUTPUT_DIR, f"{filename}.html")

    total_hits = sum(func["hits"] for func in functions_data)
    max_hits = max((func["hits"] for func in functions_data), default=0)

    total_functions = len(functions_data)
    covered_functions = sum(1 for func in functions_data if func["hits"] > 0)
    function_coverage_percent = (covered_functions / total_functions * 100) if total_functions > 0 else 0

    lines = [
        "<html><head>",
        '<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.0/css/bootstrap.min.css">',
        '<script src="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.0/js/bootstrap.bundle.min.js"></script>',
        "<style>",
        "body { font-family: monospace; font-size: 16px; }",
        ".zero-hits { background-color: #fcc; font-weight: bold; color: red; }",  # Red for functions with 0 hits
        ".nonzero-hits { color: green; font-weight: bold; }",  # Green for nonzero hit functions
        ".low-hits { background-color: #ffe6b3; }",  # Yellow for low-hit functions
        ".high-hits { background-color: #cfc; }",  # Green for high-hit functions
        "th, td { padding: 0px; font-size: 12px; }",
        "table.table { font-size: 14px; border-collapse: collapse; }",
        "table.table th, table.table td { padding: 1px; font-size: 12px; line-height: 1.2; }",
        "table.table tr { height: auto; }",
        "</style></head><body>",
        f'<h1 class="text-center">{filename} Coverage</h1>',
        f'<h2>Total Execution Hits: {total_hits}</h2>',
        f'<h2>Function Coverage Overview: {function_coverage_percent:.2f}%</h2>',

        '<button class="btn btn-primary mb-2" type="button" data-bs-toggle="collapse" data-bs-target="#funcTable">'
        'Toggle Function Coverage</button>',

        '<div class="collapse show" id="funcTable">',
        '<h2>Function Coverage:</h2><table class="table table-bordered"><thead><tr><th>Function</th><th>Hits</th></tr></thead><tbody>'
    ]

    longest_name = max((len(func["name"]) for func in functions_data), default=0)

    for func in functions_data:
        hit_color = "red" if func["hits"] == 0 else "green"
        lines.append(
            f'<tr><td style="padding: 1px; min-width: {longest_name}ch;">{func["name"]}</td>'
            f'<td style="padding: 1px; color: {hit_color}; font-weight: bold;">{func["hits"]}</td></tr>'
        )

    lines.append('</tbody></table></div>')  # Close collapsible div

    lines.append('<h2>Source Code:</h2><table class="table table-bordered"><thead><tr><th>Line</th><th>Hits</th><th>Code</th></tr></thead><tbody>')

    for i, line in enumerate(source_code, start=1):
        stripped_line = line.strip()
        class_name = "text-muted"
        if not stripped_line or stripped_line.startswith("end") or stripped_line.startswith("--"):
            count_display = "<span class='text-muted'>N/A</span>"
            lines.append(f'<tr><td>{i}</td><td>{count_display}</td><td>{line.strip()}</td>></tr>')
        else:
            count = coverage_data.get(i, 0)
            class_name = "zero-hits" if count == 0 else "low-hits" if count < max_hits * 0.3 else "high-hits"
            count_display = f'{count}'
            marked_text = f'<span class={class_name}>{line.strip()}</span>'
            lines.append(f'<tr><td>{i}</td><td>{count_display}</td><td>{marked_text}</td></tr>')

    lines.append("</tbody></table></body></html>")

    with open(html_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

def generate_index(files):
    """Generates an index.html summarizing the coverage."""
    index_html = [
        "<html><head>",
        '<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.0/css/bootstrap.min.css">',
        "</head><body>",
        '<h1 class="text-center">Coverage Report</h1>',
        '<table class="table table-striped table-bordered"><thead><tr><th>File</th><th>Total Hits</th><th>Functions</th></tr></thead><tbody>'
    ]

    for filepath, data in files.items():
        filename = os.path.basename(filepath)
        total_hits = sum(func["hits"] for func in data["functions"])
        total_functions = len(data["functions"])

        index_html.append(f'<tr><td><a href="{filename}.html">{filename}</a></td><td>{total_hits}</td><td>{total_functions}</td></tr>')

    index_html.append("</tbody></table></body></html>")

    with open(os.path.join(OUTPUT_DIR, "index.html"), "w", encoding="utf-8") as f:
        f.write("\n".join(index_html))

with open(LCOV_FILE, "r", encoding="utf-8") as f:
    lcov_content = f.read()

files_data = parse_lcov(lcov_content)

for file_path, data in files_data.items():
    generate_file_html(file_path, data["coverage"], data["functions"])

generate_index(files_data)

print(f"Coverage report generated in {OUTPUT_DIR}/index.html")
