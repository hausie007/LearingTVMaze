import csv

new_langs = ['uk', 'fi', 'da']
translations = {
    'app_title': ['Навчальний Лабіринт', 'Oppimislabyrintti', 'Lærende Labyrint'],
    'play': ['Грати', 'Pelaa', 'Spil'],
    'settings': ['Налаштування', 'Asetukset', 'Indstillinger'],
    'settings_title': ['Налаштування', 'Asetukset', 'Indstillinger'],
    'setting_mode': ['Режим гри:', 'Pelitila:', 'Spiltilstand:'],
    'setting_diff': ['Складність:', 'Vaikeustaso:', 'Sværhedsgrad:'],
    'setting_lang': ['Мова:', 'Kieli:', 'Sprog:'],
    'setting_theme': ['Тема:', 'Teema:', 'Tema:'],
    'setting_voice': ['Голосові підказки:', 'Äänivinkit:', 'Stemme-hints:'],
    'save_return': ['Назад', 'Takaisin', 'Tilbage'],
    'on': ['Увімк.', 'Päällä', 'Til'],
    'off': ['Вимк.', 'Pois', 'Fra'],
    'mode_normal': ['Лише лабіринт', 'Vain labyrintti', 'Kun labyrint'],
    'mode_numbers': ['Цифри', 'Numerot', 'Tal'],
    'mode_letters': ['Літери', 'Kirjaimet', 'Bogstaver'],
    'mode_words': ['Слова', 'Sanat', 'Ord'],
    'diff_very_easy': ['Дуже легко', 'Erittäin helppo', 'Meget let'],
    'diff_easy': ['Легко', 'Helppo', 'Let'],
    'diff_medium': ['Середньо', 'Keskitaso', 'Middel'],
    'diff_hard': ['Важко', 'Vaikea', 'Svær'],
    'diff_very_hard': ['Дуже важко', 'Erittäin vaikea', 'Meget svær'],
    'diff_insane': ['Божевільно', 'Mieletön', 'Vanvittig'],
    'diff_unbelievable': ['Неймовірно', 'Uskomaton', 'Utrolig'],
    'lang_auto': ['Авто', 'Automaattinen', 'Auto'],
    'lang_english': ['Англійська', 'Englanti', 'Engelsk'],
    'lang_czech': ['Чеська', 'Tšekki', 'Tjekkisk'],
    'lang_german': ['Німецька', 'Saksa', 'Tysk'],
    'lang_spanish': ['Іспанська', 'Espanja', 'Spansk'],
    'lang_french': ['Французька', 'Ranska', 'Frans'],
    'lang_portuguese': ['Португальська', 'Portugali', 'Portugisisk'],
    'lang_vietnamese': ['В\'єтнамська', 'Vietnam', 'Vietnamesisk'],
    'lang_turkish': ['Турецька', 'Turkki', 'Tyrkisk'],
    'lang_italian': ['Італійська', 'Italia', 'Italiensk'],
    'lang_polish': ['Польська', 'Puola', 'Polsk'],
    'lang_swedish': ['Шведська', 'Ruotsi', 'Svensk'],
    'lang_norwegian': ['Норвезька', 'Norja', 'Norsk'],
    'lang_dutch': ['Нідерландська', 'Hollanti', 'Hollandsk'],
    'lang_ukrainian': ['Українська', 'Ukraina', 'Ukrainsk'],
    'lang_finnish': ['Фінська', 'Suomi', 'Finsk'],
    'lang_danish': ['Данська', 'Tanska', 'Dansk'],
    'you_win': ['⭐ ТИ ЦЕ ЗРОБИВ! ⭐', '⭐ ONNISTUIT! ⭐', '⭐ DU GJORDE DET! ⭐'],
    'next_round': ['Наступний лабіринт!', 'Seuraava labyrintti!', 'Næste labyrint!'],
    'that_was_easy': ['Це було легко!', 'Helppo nakki!', 'Det var nemt!'],
    'main_menu': ['Головне меню', 'Päävalikko', 'Hovedmenu'],
    'try_normal': ['Лише лабіринт', 'Vain labyrintti', 'Kun labyrint'],
    'try_numbers': ['З цифрами', 'Numeroilla', 'Med tal'],
    'try_alphabet': ['З літерами', 'Kirjaimilla', 'Med bogstaver'],
    'try_words': ['Зі словами', 'Sanoilla', 'Med ord'],
    'score_time': ['Час: %s', 'Aika: %s', 'Tid: %s'],
    'score_steps': ['%d кроків', '%d askelta', '%d trin'],
    'quit_confirm': ['Вже йдеш?', 'Lähetkö jo?', 'Vil du gå allerede?'],
    'yes': ['Так', 'Kyllä', 'Ja'],
    'no': ['Ні', 'Ei', 'Nej'],
    'chaser_suggestion_off': ['Без переслідувача', 'Ilman jahtaajaa', 'Uden jager'],
    'chaser_suggestion_on': ['З переслідувачем', 'Jahtaajan kanssa', 'Med jager'],
    'chaser_suggestion_fast': ['Швидший переслідувач', 'Nopeampi jahtaaja', 'Hurtigere jager'],
    'tts_missing': ['⚠ Голос не встановлено', '⚠ Ääntä ei ole asennettu', '⚠ Stemme ikke installeret'],
    'tts_ready': ['✓ Голос встановлено', '✓ Ääni asennettu', '✓ Stemme installeret'],
    'checking_tts': ['Перевірка голосу...', 'Haetaan ääntä...', 'Tjekker stemme...'],
    'setting_chaser': ['Переслідувач:', 'Jahtaaja:', 'Jager:'],
    'gotcha': ['Спіймав!', 'Käpätty!', 'Fanget!'],
    'try_again_desc': ['Не хвилюйся, спробуй ще раз!', 'Älä huoli, yritä uudelleen!', 'Bare rolig, prøv igen!'],
    'try_again': ['Грати знову', 'Pelaa uudelleen', 'Spil igen'],
    'challenge_pp': ['Трохи важче?', 'Hieman vaikeampi?', 'Lidt sværere?'],
    'challenge_mm': ['Трохи легше?', 'Hieman helpompi?', 'Lidt lettere?'],
    'chaser_off': ['Вимк.', 'Pois', 'Fra'],
    'chaser_slow': ['Повільно', 'Hidas', 'Langsom'],
    'chaser_medium': ['Середньо', 'Keskitaso', 'Middel'],
    'chaser_fast': ['Швидко', 'Nopea', 'Hurtig'],
    'chaser_turbo': ['Турбо!', 'Turbo!', 'Turbo!'],
    'help': ['Допомога', 'Ohje', 'Hjælp'],
    'help_slide_1_text': ['"Ласкаво просимо до Навчального Лабіринту!\nКожна велика пригода починається з одного кроку. Давайте навчимося досліджувати цей світ разом."', '"Tervetuloa Oppimislabyrinttiin!\nJokainen suuri seikkailu alkaa yhdestä askeleesta. Opitaan yhdessä, miten tätä maailmaa tutkitaan."', '"Velkommen til Lærende Labyrint!\nHvert store eventyr begynder med et enkelt skridt. Lad os lære hvordan vi udforsker denne verden sammen."'],
    'help_slide_2_text': ['"Це ти!\nТвоя подорож завжди починається в нижньому лівому куті. Використовуй стрілки або D-pad, щоб рухатися крок за кроком."', '"Tämä olet sinä!\nMatkasi alkaa aina vasemmasta alakulmasta. Käytä nuolia tai ohjaimia liikkuaksesi askel askeleelta."', '"Dette er dig!\nDin rejse begynder altid i det nederste venstre hjørne. Brug pilene eller D-paden for at flytte trin for trin."'],
    'help_slide_3_text': ['"Твоя ціль - вихід, що світиться,\nякий завжди чекає на тебе у верхньому правому куті. Дійди до нього, і перемога твоя!"', '"Kohteesi on hohtava uloskäynti,\njoka odottaa sinua aina oikeassa yläkulmassa. Saavuta se, ja voitto on sinun!"', '"Dit mål er den glødende udgang,\nsom altid venter på dig i det øverste højre hjørne. Nå den, og sejren er din!"'],
    'help_slide_4_text': ['"Дорогою ти можеш знайти цифри, літери або слова.\nЗбери їх усі, щоб дізнатися щось нове!"', '"Matkan varrella voit löytää numeroita, kirjaimia tai sanoja.\nKerää ne kaikki oppiaksesi jotain uutta!"', '"Undervejs kan du finde tal, bogstaver eller ord.\nSaml dem alle for at lære noget nyt!"'],
    'help_slide_5_text': ['"Але не затримуйся занадто довго!\nІноді прямо за тобою йде переслідувач. Будь попереду та дійди до фінішу першим."', '"Mutta älä viivy liian kauan!\nJoskus ystävällinen jahtaaja on aivan perässäsi. Pysy varovasti edellä ja saavuta maali ensin."', '"Men bliv ikke for længe!\nNogle gange er en venlig jager lige bag dig. Hold dig forsigtigt foran og nå målet først."'],
    'help_slide_6_text': ['"Зроби гру своєю власною.\nУ Налаштуваннях ти можеш змінити складність, вибрати нову тему або спробувати різні режими гри. Розважайся!"', '"Tee pelistä omannäköisesi.\nAsetuksissa voit muuttaa vaikeustasoa, valita uuden teeman tai kokeilla eri pelitiloja. Pidä hauskaa!"', '"Gør spillet til dit eget.\nI Indstillinger kan du ændre sværhedsgrad, vælge et nyt tema eller prøve forskellige spiltilstande. Hav det sjovt!"'],
    'help_slide_maze_text': ['"Ти в лабіринті стін та шляхів.\nТвоє завдання - пройти крізь звивисті коридори та знайти вихід."', '"Olet seinien ja polkujen labyrintissä.\nHaasteena on navigoida mutkaisten käytävien läpi löytääksesi tien ulos."', '"Du er i en labyrint af vægge og stier.\nUdfordringen er at navigere gennem de snoede korridorer for at finde vej ud."']
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
        # Append existing translations if possible, else English
        row.extend(translations[key])
    else:
        # Fallback to English
        row.extend([row[1], row[1], row[1]])
    new_rows.append(row)

# Insert the new lang_* keys after lang_dutch (Wait, I added dutch in last turn)
# Let's find lang_dutch and insert others after it
final_rows = []
for row in new_rows:
    final_rows.append(row)
    if row[0] == 'lang_dutch':
        final_rows.append(['lang_ukrainian', 'Ukrainian', 'Ukrajinština', 'Ukrainisch', 'Ucraniano', 'Ukrainien', 'Ucraniano', 'Tiếng Ukraina', 'Ukraynaca', 'Ucraino', 'Ukraiński', 'Ukrainska', 'Ukrainsk', 'Oekraïens'] + translations['lang_ukrainian'])
        final_rows.append(['lang_finnish', 'Finnish', 'Finština', 'Finnisch', 'Finlandés', 'Finnois', 'Finlandês', 'Tiếng Phần Lan', 'Fince', 'Finlandese', 'Fiński', 'Finska', 'Finsk', 'Fins'] + translations['lang_finnish'])
        final_rows.append(['lang_danish', 'Danish', 'Dánština', 'Dänisch', 'Danés', 'Danois', 'Dinamarquês', 'Tiếng Đan Mạch', 'Danimarkaca', 'Danese', 'Duński', 'Danska', 'Dansk', 'Deens'] + translations['lang_danish'])

with open('data/translations.csv', 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
    writer.writerows(final_rows)
