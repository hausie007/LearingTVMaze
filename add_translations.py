import csv

LANGS = ["en","cs","de","es","fr","pt","vi","tr","it","pl","sv","nb","nl","uk","fi","da","hu","ro","el","sk","he"]

# mp_join_step_combined_1
t1 = {
    "en": "1. Install \"Learning Maze\" and connect to %s",
    "cs": "1. Nainstaluj \"Learning Maze\" a připoj se k %s",
    "de": "1. Installiere \"Learning Maze\" und verbinde mit %s",
    "es": "1. Instala \"Learning Maze\" y conéctate a %s",
    "fr": "1. Installe \"Learning Maze\" et connecte-toi à %s",
    "pt": "1. Instale \"Learning Maze\" e conecte-se a %s",
    "vi": "1. Cài đặt \"Learning Maze\" và kết nối với %s",
    "tr": "1. \"Learning Maze\"i yükle ve %s ağına bağlan",
    "it": "1. Installa \"Learning Maze\" e connettiti a %s",
    "pl": "1. Zainstaluj \"Learning Maze\" i połącz się z %s",
    "sv": "1. Installera \"Learning Maze\" och anslut till %s",
    "nb": "1. Installer \"Learning Maze\" og koble til %s",
    "nl": "1. Installeer \"Learning Maze\" en verbind met %s",
    "uk": "1. Установи \"Learning Maze\" та підключись до %s",
    "fi": "1. Asenna \"Learning Maze\" ja yhdistä verkkoon %s",
    "da": "1. Installer \"Learning Maze\" og opret forbindelse til %s",
    "hu": "1. Telepítsd a \"Learning Maze\"-t és csatlakozz ehhez: %s",
    "ro": "1. Instalează \"Learning Maze\" și conectează-te la %s",
    "el": "1. Εγκατάστησε το \"Learning Maze\" και συνδέσου στο %s",
    "sk": "1. Nainštaluj \"Learning Maze\" a pripoj sa k %s",
    "he": "1. התקן את \"Learning Maze\" והתחבר אל %s"
}

# mp_join_step_combined_2
# format: 2. Open the app, tap the teal [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"Join Game"[/color][/b] card, and select your player.

join_games = {
    "en": "Join Game", "cs": "Připojit se ke hře", "de": "Spiel beitreten", "es": "Unirse al juego",
    "fr": "Rejoindre la partie", "pt": "Entrar no jogo", "vi": "Tham gia trò chơi", "tr": "Oyuna katıl",
    "it": "Partecipa al gioco", "pl": "Dołącz do gry", "sv": "Gå med i spelet", "nb": "Bli med i spillet",
    "nl": "Meedoen aan spel", "uk": "Приєднатися до гри", "fi": "Liity peliin", "da": "Deltag i spillet",
    "hu": "Csatlakozás a játékhoz", "ro": "Intră în joc", "el": "Συμμετοχή στο παιχνίδι", "sk": "Pripojiť sa k hre",
    "he": "הצטרף למשחק"
}

t2 = {}
for lang, jg in join_games.items():
    if lang == "cs":
        t2[lang] = f'2. Otevři aplikaci, klepni na tyrkysovou kartu [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]„{jg}“[/color][/b] a vyber hráče.'
    elif lang == "de":
        t2[lang] = f'2. Öffne die App, tippe auf die blaugrüne Karte [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]„{jg}“[/color][/b] und wähle deinen Spieler.'
    elif lang == "es":
        t2[lang] = f'2. Abre la app, toca la tarjeta verde azulado [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] y selecciona tu jugador.'
    elif lang == "fr":
        t2[lang] = f'2. Ouvre l’application, touche la carte sarcelle [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]« {jg} »[/color][/b] et choisis ton joueur.'
    elif lang == "pt":
        t2[lang] = f'2. Abra o app, toque no cartão azul-petróleo [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] e escolha seu jogador.'
    elif lang == "vi":
        t2[lang] = f'2. Mở ứng dụng, chạm vào thẻ màu mòng két [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] và chọn người chơi.'
    elif lang == "tr":
        t2[lang] = f'2. Uygulamayı aç, deniz mavisi [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] kartına dokun ve oyuncunu seç.'
    elif lang == "it":
        t2[lang] = f'2. Apri l\'app, tocca la scheda color ottanio [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] e seleziona il tuo giocatore.'
    elif lang == "pl":
        t2[lang] = f'2. Otwórz aplikację, dotknij morskiej karty [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]„{jg}”[/color][/b] i wybierz gracza.'
    elif lang == "sv":
        t2[lang] = f'2. Öppna appen, tryck på det blågröna kortet [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] och välj din spelare.'
    elif lang == "nb":
        t2[lang] = f'2. Åpne appen, trykk på det blågrønne kortet [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] og velg spilleren din.'
    elif lang == "nl":
        t2[lang] = f'2. Open de app, tik op de blauwgroene kaart [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] en kies je speler.'
    elif lang == "uk":
        t2[lang] = f'2. Відкрий застосунок, натисни бірюзову картку [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]«{jg}»[/color][/b] та обери гравця.'
    elif lang == "fi":
        t2[lang] = f'2. Avaa sovellus, napauta sinivihreää korttia [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] ja valitse pelaaja.'
    elif lang == "da":
        t2[lang] = f'2. Åbn appen, tryk på det blågrønne kort [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] og vælg din spiller.'
    elif lang == "hu":
        t2[lang] = f'2. Nyisd meg az alkalmazást, koppints a pávakék kártyára [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] és válaszd ki a játékosod.'
    elif lang == "ro":
        t2[lang] = f'2. Deschide aplicația, atinge cardul turcoaz [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] și alege-ți jucătorul.'
    elif lang == "el":
        t2[lang] = f'2. Άνοιξε την εφαρμογή, πάτησε το πετρόλ [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] και διάλεξε τον παίκτη σου.'
    elif lang == "sk":
        t2[lang] = f'2. Otvor aplikáciu, ťukni na tyrkysovú kartu [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]„{jg}“[/color][/b] a vyber hráča.'
    elif lang == "he":
        t2[lang] = f'2. פתח את האפליקציה, הקש על הכרטיס בצבע טורקיז [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] ובחר את השחקן שלך.'
    else:
        t2[lang] = f'2. Open the app, tap the teal [img=36]res://images/icons/i_join_game.png[/img] [b][color=#%s]"{jg}"[/color][/b] card, and select your player.'

with open('data/translations.csv', 'a', newline='') as f:
    writer = csv.writer(f)
    row1 = ["mp_join_step_combined_1"] + [t1[l] for l in LANGS]
    row2 = ["mp_join_step_combined_2"] + [t2[l] for l in LANGS]
    writer.writerow(row1)
    writer.writerow(row2)

print("Done appending translations.")
