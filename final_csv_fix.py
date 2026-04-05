import csv

with open('data/translations.csv', 'r', encoding='utf-8') as f:
    rows = list(csv.reader(f))

header = rows[0]
num_cols = len(header)
keys_found = set()
unique_rows = []

# Translation for lang_greek key in el column (last column)
greek_translations = {
    'el': 'Ελληνικά'
}

for row in rows:
    # Basic cleanup: strip quotes from content
    clean_row = [cell.strip().strip('"') for cell in row]
    
    # Ensure column count
    while len(clean_row) < num_cols:
        clean_row.append(clean_row[1] if len(clean_row) > 1 else "")
    
    # Specific fix: lang_greek should have Ελληνικά in the 'el' column
    if clean_row[0] == 'lang_greek':
        # The 'el' column is index 19 (20th column)
        if len(clean_row) >= 20:
             clean_row[19] = 'Ελληνικά'
    
    # Duplication check
    key = clean_row[0]
    if key in keys_found and key != "":
        continue
    keys_found.add(key)
    unique_rows.append(clean_row)

with open('data/translations.csv', 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
    writer.writerows(unique_rows)
