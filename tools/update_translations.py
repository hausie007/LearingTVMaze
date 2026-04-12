import csv
import sys

def main():
    file_path = "data/translations.csv"
    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)

    header = rows[0]
    
    # Dictionary of lang codes to column index
    lang_indices = {lang: i for i, lang in enumerate(header) if i > 0}
    
    # mode_letters updates (approximate translations for "Letters")
    # en,cs,de,es,fr,pt,vi,tr,it,pl,sv,nb,nl,uk,fi,da,hu,ro,el
    letters_dict = {
        "en": "Letters", "cs": "Písmena", "de": "Buchstaben", "es": "Letras",
        "fr": "Lettres", "pt": "Letras", "vi": "Chữ cái", "tr": "Harfler",
        "it": "Lettere", "pl": "Litery", "sv": "Bokstäver", "nb": "Bokstaver",
        "nl": "Letters", "uk": "Літери", "fi": "Kirjaimet", "da": "Bogstaver",
        "hu": "Betűk", "ro": "Litere", "el": "Γράμματα"
    }

    desc_numbers_dict = {lang: "Counting up the numbers from one" for lang in lang_indices}
    desc_numbers_dict['cs'] = "Počítání čísel od jedničky"
    desc_numbers_dict['de'] = "Die Zahlen von eins an aufwärts zählen"

    desc_letters_dict = {lang: "Letters of the alphabet" for lang in lang_indices}
    desc_letters_dict['cs'] = "Písmena abecedy"
    desc_letters_dict['de'] = "Buchstaben des Alphabets"

    desc_words_dict = {lang: "Collect letters to form words" for lang in lang_indices}
    desc_words_dict['cs'] = "Sbírej písmena a skládej slova"
    desc_words_dict['de'] = "Sammle Buchstaben, um Wörter zu bilden"

    desc_maze_dict = {lang: "Just explore the maze" for lang in lang_indices}
    desc_maze_dict['cs'] = "Jen prozkoumej bludiště"
    desc_maze_dict['de'] = "Einfach das Labyrinth erkunden"

    # Find and update mode_letters
    for row in rows:
        if row[0] == "mode_letters":
            for lang, val in letters_dict.items():
                if lang in lang_indices:
                    row[lang_indices[lang]] = val

    # Append new rows
    def create_row(key, val_dict):
        new_row = [key] + [""] * (len(header) - 1)
        for lang, idx in lang_indices.items():
            new_row[idx] = val_dict.get(lang, val_dict['en'])
        return new_row

    rows.append(create_row("desc_numbers", desc_numbers_dict))
    rows.append(create_row("desc_letters", desc_letters_dict))
    rows.append(create_row("desc_words", desc_words_dict))
    rows.append(create_row("desc_maze", desc_maze_dict))

    with open(file_path, "w", encoding="utf-8", newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

if __name__ == "__main__":
    main()
