import csv

with open('data/translations.csv', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    rows = list(reader)

header = rows[0]
# Remove duplicates while preserving order
seen = set()
new_header = []
for h in header:
    if h not in seen:
        new_header.append(h)
        seen.add(h)

new_rows = [new_header]
expected_len = len(new_header)

for row in rows[1:]:
    if not row: continue
    # If row is too long due to previous bug, trim it
    new_rows.append(row[:expected_len])

with open('data/translations.csv', 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
    writer.writerows(new_rows)
