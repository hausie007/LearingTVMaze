import csv

with open('data/translations.csv', 'r', encoding='utf-8') as f:
    rows = list(csv.reader(f))

new_rows = []
for row in rows:
    new_row = []
    for cell in row:
        # Strip leading and trailing double-quotes if they exist as a pair
        # Actually, let's just strip any leading/trailing quotes from the content
        clean = cell.strip()
        if clean.startswith('"') and clean.endswith('"') and len(clean) >= 2:
            clean = clean[1:-1]
        
        # Also handle potential tripling or excessive quoting
        # Standardize: no start/end double quotes for the content itself
        new_row.append(clean)
    new_rows.append(new_row)

with open('data/translations.csv', 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
    writer.writerows(new_rows)
