import csv

def main():
    file_path = "data/translations.csv"
    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)

    header = rows[0]
    lang_indices = {lang: i for i, lang in enumerate(header) if i > 0}

    # Short English bases
    desc_letters = {lang: "In alphabetical order" for lang in lang_indices}
    desc_letters['cs'] = "V abecedním pořadí"
    desc_letters['de'] = "In alphabetischer Reihenfolge"
    desc_letters['es'] = "En orden alfabético"
    desc_letters['fr'] = "Par ordre alphabétique"
    
    for row in rows:
        if row[0] == "desc_letters":
            for lang, val in desc_letters.items():
                if lang in lang_indices: row[lang_indices[lang]] = val

    with open(file_path, "w", encoding="utf-8", newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

if __name__ == "__main__":
    main()
