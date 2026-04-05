import csv

new_langs = ['hu', 'ro']
translations = {
    'app_title': ['Tanuló Labirintus', 'Labirintul de Învățare'],
    'play': ['Játék', 'Joacă'],
    'settings': ['Beállítások', 'Setări'],
    'settings_title': ['Beállítások', 'Setări'],
    'setting_mode': ['Játékmód:', 'Mod Joc:'],
    'setting_diff': ['Nehézség:', 'Dificultate:'],
    'setting_lang': ['Nyelv:', 'Limbă:'],
    'setting_theme': ['Téma:', 'Temă:'],
    'setting_voice': ['Hangsegítség:', 'Sugestii Vocale:'],
    'save_return': ['Vissza', 'Înapoia'],
    'on': ['Be', 'Pornit'],
    'off': ['Ki', 'Oprit'],
    'mode_normal': ['Csak labirintus', 'Doar labirint'],
    'mode_numbers': ['Számok', 'Numere'],
    'mode_letters': ['Betűk', 'Litere'],
    'mode_words': ['Szavak', 'Cuvinte'],
    'diff_very_easy': ['Nagyon könnyű', 'Foarte ușor'],
    'diff_easy': ['Könnyű', 'Ușor'],
    'diff_medium': ['Közepes', 'Mediu'],
    'diff_hard': ['Nehéz', 'Greu'],
    'diff_very_hard': ['Nagyon nehéz', 'Foarte greu'],
    'diff_insane': ['Őrült', 'Nebunesc'],
    'diff_unbelievable': ['Hihetetlen', 'Incredibil'],
    'lang_auto': ['Auto', 'Auto'],
    'lang_english': ['Angol', 'Engleză'],
    'lang_czech': ['Cseh', 'Cehă'],
    'lang_german': ['Német', 'Germană'],
    'lang_spanish': ['Spanyol', 'Spaniolă'],
    'lang_french': ['Francia', 'Franceză'],
    'lang_portuguese': ['Portugál', 'Portugheză'],
    'lang_vietnamese': ['Vietnámi', 'Vietnameză'],
    'lang_turkish': ['Török', 'Turcă'],
    'lang_italian': ['Olasz', 'Italiană'],
    'lang_polish': ['Lengyel', 'Poloneză'],
    'lang_swedish': ['Svéd', 'Suedeză'],
    'lang_norwegian': ['Norvég', 'Norvegiană'],
    'lang_dutch': ['Holland', 'Holandeză'],
    'lang_ukrainian': ['Ukrán', 'Ucraineană'],
    'lang_finnish': ['Finn', 'Finlandeză'],
    'lang_danish': ['Dán', 'Daneză'],
    'lang_hungarian': ['Magyar', 'Maghiară'],
    'lang_romanian': ['Román', 'Română'],
    'you_win': ['⭐ MEGCSINÁLTAD! ⭐', '⭐ AI REUȘIT! ⭐'],
    'next_round': ['Következő labirintus!', 'Următorul labirint!'],
    'that_was_easy': ['Ez könnyű volt!', 'A fost ușor!'],
    'main_menu': ['Főmenü', 'Meniu Principal'],
    'try_normal': ['Csak labirintus', 'Doar labirint'],
    'try_numbers': ['Számokkal', 'Cu numere'],
    'try_alphabet': ['Betűkkel', 'Cu litere'],
    'try_words': ['Szavakkal', 'Cu cuvinte'],
    'score_time': ['Idő: %s', 'Timp: %s'],
    'score_steps': ['%d lépés', '%d pași'],
    'quit_confirm': ['Már mész is?', 'Pleci deja?'],
    'yes': ['Igen', 'Da'],
    'no': ['Nem', 'Nu'],
    'chaser_suggestion_off': ['Üldöző nélkül', 'Fără urmăritor'],
    'chaser_suggestion_on': ['Üldözővel', 'Cu urmăritor'],
    'chaser_suggestion_fast': ['Gyorsabb üldöző', 'Urmăritor mai rapid'],
    'tts_missing': ['⚠ Hang nincs telepítve', '⚠ Voce neinstalată'],
    'tts_ready': ['✓ Hang kész', '✓ Voce pregătită'],
    'checking_tts': ['Hang ellenőrzése...', 'Verificare voce...'],
    'setting_chaser': ['Üldöző:', 'Urmăritor:'],
    'gotcha': ['Elkapva!', 'Te-am prins!'],
    'try_again_desc': ['Ne aggódj, próbáld újra!', 'Nu-ți face griji, mai încearcă!'],
    'try_again': ['Új játék', 'Joacă din nou'],
    'challenge_pp': ['Kicsit nehezebb?', 'Puțin mai greu?'],
    'challenge_mm': ['Kicsit könnyebb?', 'Puțin mai ușor?'],
    'chaser_off': ['Ki', 'Oprit'],
    'chaser_slow': ['Lassú', 'Lent'],
    'chaser_medium': ['Közepes', 'Mediu'],
    'chaser_fast': ['Gyors', 'Rapid'],
    'chaser_turbo': ['Turbó!', 'Turbo!'],
    'help': ['Súgó', 'Ajutor'],
    'help_slide_1_text': ['"Üdvözöljük a Tanuló Labirintusban!\nMinden nagy kaland egyetlen lépéssel kezdődik. Tanuljuk meg együtt, hogyan fedezhetjük fel ezt a világot."', '"Bun venit în Labirintul de Învățare!\nFiecare aventură mare începe cu un singur pas. Hai să învățăm cum să explorăm această lume împreună."'],
    'help_slide_2_text': ['"Ez te vagy!\nUtazásod mindig a bal alsó sarokban kezdődik. Használd a nyilakat vagy a D-padot, hogy lépésről lépésre haladj."', '"Acesta ești tu!\nCălătoria ta începe întotdeauna în colțul din stânga jos. Folosește săgețile sau D-pad-ul pentru a te deplasa pas cu pas."'],
    'help_slide_3_text': ['"A célod a fénylő kijárat,\namely mindig a jobb felső sarokban vár rád. Érd el, és a győzelem a tiéd!"', '"Scopul tău este ieșirea strălucitoare,\ncare te așteaptă mereu în colțul din dreapta sus. Ajungi la ea, și victoria este a ta!"'],
    'help_slide_4_text': ['"Útközben számokat, betűket vagy szavakat találhatsz.\nGyűjtsd össze mindet, hogy valami újat tanulj!"', '"Pe drum poți găsi numere, litere sau cuvinte.\nAdună-le pe toate pentru a învăța ceva nou!"'],
    'help_slide_5_text': ['"De ne maradj túl sokáig!\nNéha egy barátságos üldöző van a sarkadban. Maradj óvatosan előtted, és érj célba először."', '"Dar nu sta prea mult!\nUneori, un urmăritor prietenos este chiar în spatele tău. Rămâi cu atenție în față și ajungi primul la sosire."'],
    'help_slide_6_text': ['"Tedd a játékot a sajátoddá.\nA Beállításokban megváltoztathatod a nehézséget, választhatsz új témát vagy próbálhatsz ki különböző játékmódokat. Jó szórakozást!"', '"Personalizează jocul.\nÎn Setări poți schimba dificultatea, alege o temă nouă sau încerca diferite moduri de joc. Distracție plăcută!"'],
    'help_slide_maze_text': ['"Falak és utak labirintusában vagy.\nA kihívás az, hogy navigálj a kanyargós folyosókon, hogy megtaláld a kijáratot."', '"Ești într-un labirint de pereți și căi.\nProvocarea este să navighezi prin coridoarele întortocheate pentru a găsi calea de ieșire."']
}

with open('data/translations.csv', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    rows = list(reader)

header = rows[0]
header.extend(new_langs)

new_rows = [header]
for row in rows[1:]:
    if not row: continue
    key = row[0]
    if key in translations:
        row.extend(translations[key])
    else:
        row.extend([row[1], row[1]])
    new_rows.append(row)

final_rows = []
for row in new_rows:
    final_rows.append(row)
    if row[0] == 'lang_danish':
        final_rows.append(['lang_hungarian', 'Hungarian', 'Maďarština', 'Ungarisch', 'Húngaro', 'Hongrois', 'Húngaro', 'Tiếng Hungary', 'Macarca', 'Ungherese', 'Węgierski', 'Ungerska', 'Ungarsk', 'Hongaars', 'Ukrán', 'Unkari', 'Ungarsk'] + translations['lang_hungarian'])
        final_rows.append(['lang_romanian', 'Romanian', 'Rumunština', 'Rumänisch', 'Rumano', 'Roumain', 'Romeno', 'Tiếng Rumani', 'Rumence', 'Rumeno', 'Rumuński', 'Rumänska', 'Rumensk', 'Roemeens', 'Román', 'Romania', 'Rumænsk'] + translations['lang_romanian'])

with open('data/translations.csv', 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
    writer.writerows(final_rows)
