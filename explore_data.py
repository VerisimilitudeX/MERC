import pandas as pd
import re

# Function to parse the directory listing
def parse_directory_listing(content):
    data = []
    for line in content.split('\n'):
        if line.strip():
            parts = re.split(r'\s+', line.strip(), maxsplit=4)
            if len(parts) >= 4:
                item_type = parts[0].strip('[]')
                name = parts[1]
                last_modified = f"{parts[2]} {parts[3]}"
                size = parts[4] if len(parts) > 4 else '-'
                description = parts[5] if len(parts) > 5 else ''
                data.append({
                    'Type': item_type,
                    'Name': name,
                    'Last Modified': last_modified,
                    'Size': size,
                    'Description': description
                })
    return data

# The content of the directory listing
content = """
[ICO] Name Last modified Size Description
[PARENTDIR] Parent Directory - 
[DIR] 007MCL/ 2016-07-29 17:00 - 
[DIR] 1CLL/ 2016-07-29 17:12 - 
[DIR] 3CLL/ 2016-07-29 17:15 - 
[DIR] 5.1/ 2016-08-16 10:15 - 
[DIR] 5.2/ 2016-08-16 10:15 - 
[DIR] 10CLL/ 2016-07-29 17:01 - 
# ... (rest of the content)
"""

# Parse the directory listing
parsed_data = parse_directory_listing(content)

# Create a pandas DataFrame
df = pd.DataFrame(parsed_data)

# Display the first few rows of the DataFrame
print(df.head())

# Display basic information about the DataFrame
print(df.info())

# Display summary statistics
print(df.describe(include='all'))