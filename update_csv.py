import csv

new_langs = ['sv', 'no', 'nl']
translations = {
    'app_title': ['Lärande Labyrint', 'Læring Labyrint', 'Leerdoolhof'],
    'play': ['Spela', 'Spill', 'Spelen'],
    'settings': ['Inställningar', 'Innstillinger', 'Instellingen'],
    'settings_title': ['Inställningar', 'Innstillinger', 'Instellingen'],
    'setting_mode': ['Spelläge:', 'Spillmodus:', 'Spelmodus:'],
    'setting_diff': ['Svårighetsgrad:', 'Vanskelighetsgrad:', 'Moeilijkheidsgraad:'],
    'setting_lang': ['Språk:', 'Språk:', 'Taal:'],
    'setting_theme': ['Tema:', 'Tema:', 'Thema:'],
    'setting_voice': ['Röstanvisningar:', 'Talehint:', 'Gesproken hints:'],
    'save_return': ['Bakåt', 'Tilbake', 'Terug'],
    'on': ['På', 'På', 'Aan'],
    'off': ['Av', 'Av', 'Uit'],
    'mode_normal': ['Bara labyrint', 'Bare labyrint', 'Alleen doolhof'],
    'mode_numbers': ['Siffror', 'Tall', 'Getallen'],
    'mode_letters': ['Bokstäver', 'Bokstaver', 'Letters'],
    'mode_words': ['Ord', 'Ord', 'Woorden'],
    'diff_very_easy': ['Mycket lätt', 'Veldig lett', 'Zeer makkelijk'],
    'diff_easy': ['Lätt', 'Lett', 'Makkelijk'],
    'diff_medium': ['Medel', 'Middels', 'Gemiddeld'],
    'diff_hard': ['Svårt', 'Vanskelig', 'Moeilijk'],
    'diff_very_hard': ['Mycket svårt', 'Veldig vanskelig', 'Zeer moeilijk'],
    'diff_insane': ['Galet', 'Vanvittig', 'Krankzinnig'],
    'diff_unbelievable': ['Otroligt', 'Utrolig', 'Ongelooflijk'],
    'lang_auto': ['Automatisk', 'Automatisk', 'Automatisch'],
    'lang_english': ['Engelska', 'Engelsk', 'Engels'],
    'lang_czech': ['Tjeckiska', 'Tsjekkisk', 'Tsjechisch'],
    'lang_german': ['Tyska', 'Tysk', 'Duits'],
    'lang_spanish': ['Spanska', 'Spansk', 'Spaans'],
    'lang_french': ['Franska', 'Fransk', 'Frans'],
    'lang_portuguese': ['Portugisiska', 'Portugisisk', 'Portugees'],
    'lang_vietnamese': ['Vietnamesiska', 'Vietnamesisk', 'Vietnamees'],
    'lang_turkish': ['Turkiska', 'Tyrkisk', 'Turks'],
    'lang_italian': ['Italienska', 'Italiensk', 'Italiaans'],
    'lang_polish': ['Polska', 'Polsk', 'Pools'],
    'lang_swedish': ['Svenska', 'Svensk', 'Zweeds'],
    'lang_norwegian': ['Norska', 'Norsk', 'Noors'],
    'lang_dutch': ['Nederländska', 'Nederlandsk', 'Nederlands'],
    'you_win': ['⭐ DU KLARADE DET! ⭐', '⭐ DU KLARTE DET! ⭐', '⭐ JE HEBT HET GEDAAN! ⭐'],
    'next_round': ['Nästa labyrint!', 'Neste labyrint!', 'Volgende doolhof!'],
    'that_was_easy': ['Lätt som en plätt!', 'Enkel som bare det!', 'Eitje!'],
    'main_menu': ['Huvudmeny', 'Hovedmeny', 'Hoofdmenu'],
    'try_normal': ['Bara labyrint', 'Bare labyrint', 'Alleen doolhof'],
    'try_numbers': ['Med siffror', 'Med tall', 'Met getallen'],
    'try_alphabet': ['Med bokstäver', 'Med bokstaver', 'Met letters'],
    'try_words': ['Med ord', 'Med ord', 'Met woorden'],
    'score_time': ['Tid: %s', 'Tid: %s', 'Tijd: %s'],
    'score_steps': ['%d steg', '%d steg', '%d stappen'],
    'quit_confirm': ['Vill du gå redan?', 'Vil du dra allerede?', 'Wil je nu al weg?'],
    'yes': ['Ja', 'Ja', 'Ja'],
    'no': ['Nej', 'Nei', 'Nee'],
    'chaser_suggestion_off': ['Utan jagare', 'Uten jager', 'Zonder tikkertje'],
    'chaser_suggestion_on': ['Med jagare', 'Med jager', 'Met tikkertje'],
    'chaser_suggestion_fast': ['Snabbare jagare', 'Raskere jager', 'Snellere tikkertje'],
    'tts_missing': ['⚠ Rösten saknas', '⚠ Stemme ikke installert', '⚠ Stem niet geïnstalleerd'],
    'tts_ready': ['✓ Rösten är installerad', '✓ Stemme installert', '✓ Stem geïnstalleerd'],
    'checking_tts': ['Kontrollerar röst...', 'Sjekker stemme...', 'Stem beschikbaarheid controleren...'],
    'setting_chaser': ['Jagare:', 'Jager:', 'Tikkertje:'],
    'gotcha': ['Fångad!', 'Tatt!', 'Hebbes!'],
    'try_again_desc': ['Oroa dig inte, försök igen!', 'Ikke bekymre deg, prøv igjen!', 'Maak je geen zorgen, probeer het nog eens!'],
    'try_again': ['Spela igen', 'Spill igjen', 'Opnieuw spelen'],
    'challenge_pp': ['Lite svårare?', 'Litt vanskeligere?', 'Iets moeilijker?'],
    'challenge_mm': ['Lite lättare?', 'Litt lettere?', 'Iets makkelijker?'],
    'chaser_off': ['Av', 'Av', 'Uit'],
    'chaser_slow': ['Långsamt', 'Sakte', 'Langzaam'],
    'chaser_medium': ['Medel', 'Middels', 'Gemiddeld'],
    'chaser_fast': ['Snabbt', 'Rask', 'Snel'],
    'chaser_turbo': ['Turbo!', 'Turbo!', 'Turbo!'],
    'help': ['Hjälp', 'Hjelp', 'Help'],
    'help_slide_1_text': ['"Välkommen till Lärande Labyrint!\nVarje stort äventyr börjar med ett enda steg. Låt oss lära oss hur vi utforskar den här världen tillsammans."', '"Velkommen til Læring Labyrint!\nHvert store eventyr begynner med ett enkelt skritt. La oss lære hvordan vi utforsker denne verden sammen."', '"Welkom bij het Leerdoolhof!\nElk groot avontuur begint met een enkele stap. Laten we leren hoe we deze wereld samen kunnen verkennen."'],
    'help_slide_2_text': ['"Det här är du!\nDin resa börjar alltid i det nedre vänstra hörnet. Använd pilarna eller styrkorset för att flytta steg för steg."', '"Dette er deg!\nReisen din begynner alltid i det nedre venstre hjørnet. Bruk pilene eller D-paden for å flytte steg for steg."', '"Dit ben jij!\nJe reis begint altijd in de linkerbenedenhoek. Gebruik de pijltjes of het D-pad om stap voor stap te bewegen."'],
    'help_slide_3_text': ['"Ditt mål är den lysande utgången,\nsom alltid väntar på dig i det övre högra hörnet. Nå den, och segern är din!"', '"Destinasjonen din er den glødende utgangen,\nsom alltid venter på deg i øvre høyre hjørne. Nå den, og seieren er din!"', '"Je bestemming is de gloeiende uitgang,\ndie altijd op je wacht in de rechterbovenhoek. Bereik hem en de overwinning is voor jou!"'],
    'help_slide_4_text': ['"Längs vägen kan du upptäcka siffror, bokstäver eller ord.\nSamla dem alla för att lära dig något nytt!"', '"Underveis kan du oppdage tall, bokstaver eller ord.\nSamle dem alle for å lære noe nytt!"', '"Onderweg ontdek je misschien cijfers, letters of woorden.\nVerzamel ze allemaal om iets nieuws te leren!"'],
    'help_slide_5_text': ['"Men dröj inte kvar för länge!\nIbland är en vänlig jagare precis bakom dig. Håll dig försiktigt före och nå målet först."', '"Men ikke bli værende for lenge!\nNoen ganger er en vennlig jager rett bak deg. Hold deg forsiktig foran og nå målet først."', '"Maar blijf niet te lang hangen!\nSoms zit er een vriendelijk tikkertje vlak achter je. Blijf hem voorzichtig voor en bereik als eerste de finish."'],
    'help_slide_6_text': ['"Gör spelet till ditt eget.\nI Inställningar kan du ändra svårighetsgrad, välja ett nytt tema eller prova olika spellägen. Ha så kul!"', '"Gjør spillet til ditt eget.\nI Innstillinger kan du endre vanskelighetsgrad, velge et nytt tema eller prøve forskjellige spillmoduser. Ha det gøy!"', '"Maak het spel van jou.\nIn de Instellingen kun je de moeilijkheidsgraad aanpassen, een nieuw thema kiezen of verschillende spelmodi proberen. Veel plezier!"'],
    'help_slide_maze_text': ['"Du är i en labyrint av väggar och stigar.\nUtmaningen är att navigera genom de slingrande korridorerna för att hitta vägen ut."', '"Du er i en labyrint av vegger og stigar.\nUtfordringen er å navigere gjennom de svingete korridorene for att finna veien ut."', '"Je bent in een doolhof van muren en paden.\nDe uitdaging is om door de kronkelende gangen te navigeren om de weg naar buiten te vinden."']
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
        # Fallback to English if not provided (shouldn't happen for core keys)
        row.extend([row[1], row[1], row[1]])
    new_rows.append(row)

# Add missing keys if any
existing_keys = [r[0] for r in new_rows]
for k, v in translations.items():
    if k not in existing_keys:
        # We need to build a full row with and then add our new translations
        # Since we don't have translations for other languages, we'll use English
        # This is for lang_swedish, lang_norwegian, lang_dutch which might be missing from original
        default_val = v[0] # Swedish as a base if we have it, else we'd need more logic
        # Actually it's better to find where to insert them. 
        # Locating lang_polish (row 35 in original)
        pass

# Refined approach: insert the new lang_* keys after lang_polish
final_rows = []
for row in new_rows:
    final_rows.append(row)
    if row[0] == 'lang_polish':
        final_rows.append(['lang_swedish', 'Swedish', 'Švédština', 'Schwedisch', 'Sueco', 'Suédois', 'Sueco', 'Tiếng Thụy Điển', 'İsveççe', 'Svedese', 'Szwedzki'] + translations['lang_swedish'])
        final_rows.append(['lang_norwegian', 'Norwegian', 'Norština', 'Norwegisch', 'Noruego', 'Norvégien', 'Norueguês', 'Tiếng Na Uy', 'Norveççe', 'Norvegese', 'Norweski'] + translations['lang_norwegian'])
        final_rows.append(['lang_dutch', 'Dutch', 'Nizozemština', 'Niederländisch', 'Holandés', 'Néerlandais', 'Holandês', 'Tiếng Hà Lan', 'Hollandaca', 'Olandese', 'Holenderski'] + translations['lang_dutch'])

with open('data/translations.csv', 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
    writer.writerows(final_rows)
