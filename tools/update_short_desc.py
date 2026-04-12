import csv

def main():
    file_path = "data/translations.csv"
    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)

    header = rows[0]
    lang_indices = {lang: i for i, lang in enumerate(header) if i > 0}

    # Short English bases
    desc_numbers = {lang: "Count from 1" for lang in lang_indices}
    desc_numbers['cs'] = "Počítání dětí"  # actually "Počítání od jedničky" is better
    desc_numbers['cs'] = "Počítej od jedničky"
    desc_numbers['de'] = "Zähle ab eins"

    desc_letters = {lang: "Learn the letters" for lang in lang_indices}
    desc_letters['cs'] = "Písmena abecedy"
    desc_letters['de'] = "Lerne Buchstaben"

    desc_words = {lang: "Spell the words" for lang in lang_indices}
    desc_words['cs'] = "Skládej slova z písmen"
    desc_words['de'] = "Bilde Wörter"

    desc_maze = {lang: "Explore the maze" for lang in lang_indices}
    desc_maze['cs'] = "Jen se proběhni"
    desc_maze['de'] = "Erkunde das Labyrinth"

    for row in rows:
        if row[0] == "desc_numbers":
            for lang, val in desc_numbers.items():
                if lang in lang_indices: row[lang_indices[lang]] = val
        elif row[0] == "desc_letters":
            for lang, val in desc_letters.items():
                if lang in lang_indices: row[lang_indices[lang]] = val
        elif row[0] == "desc_words":
            for lang, val in desc_words.items():
                if lang in lang_indices: row[lang_indices[lang]] = val
        elif row[0] == "desc_maze":
            for lang, val in desc_maze.items():
                if lang in lang_indices: row[lang_indices[lang]] = val

    with open(file_path, "w", encoding="utf-8", newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

if __name__ == "__main__":
    main()
