#!/usr/bin/env python3
"""Appends banner localization rows to translations.csv with CRLF line endings."""

import os

csv_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'translations.csv')

new_rows = [
    (
        "mp_banner_join_title",
        "Join this game with Your Phone or Tablet",
        "Připoj se ke hře telefonem nebo tabletem",
        "Mit Telefon oder Tablet beitreten",
        "Únete con tu teléfono o tablet",
        "Rejoins la partie avec ton téléphone ou ta tablette",
        "Entre no jogo com seu celular ou tablet",
        "Tham gia trò chơi bằng điện thoại hoặc máy tính bảng",
        "Telefon veya tabletle katıl",
        "Unisciti al gioco con il telefono o il tablet",
        "Dołącz do gry telefonem lub tabletem",
        "Gå med med din telefon eller surfplatta",
        "Bli med med telefon eller nettbrett",
        "Meedoen met je telefoon of tablet",
        "Приєднуйся до гри з телефону або планшету",
        "Liity peliin puhelimella tai tabletilla",
        "Meld dig til spillet med din telefon eller tablet",
        "Csatlakozz a játékhoz telefonnal vagy tablettel",
        "Alătură-te cu telefonul sau tableta",
        "Μπες στο παιχνίδι με το τηλέφωνο ή το tablet σου",
        "Pripoj sa ku hre telefónom alebo tabletom",
        "הצטרף למשחק עם הטלפון או הטאבלט שלך",
    ),
    (
        "mp_banner_step_1",
        "1. Open Learning Maze on your phone or tablet.",
        "1. Otevři Learning Maze na svém telefonu nebo tabletu.",
        "1. Öffne Learning Maze auf deinem Telefon oder Tablet.",
        "1. Abre Learning Maze en tu teléfono o tablet.",
        "1. Ouvre Learning Maze sur ton téléphone ou ta tablette.",
        "1. Abra o Learning Maze no celular ou tablet.",
        "1. Mở Learning Maze trên điện thoại hoặc máy tính bảng.",
        "1. Learning Maze'i telefon veya tabletinde aç.",
        "1. Apri Learning Maze sul tuo telefono o tablet.",
        "1. Otwórz Learning Maze na telefonie lub tablecie.",
        "1. Öppna Learning Maze på din telefon eller surfplatta.",
        "1. Åpne Learning Maze på telefonen eller nettbrettet.",
        "1. Open Learning Maze op je telefoon of tablet.",
        "1. Відкрий Learning Maze на телефоні або планшеті.",
        "1. Avaa Learning Maze puhelimella tai tabletilla.",
        "1. Åbn Learning Maze på din telefon eller tablet.",
        "1. Nyisd meg a Learning Maze-t a telefonon vagy tableten.",
        "1. Deschide Learning Maze pe telefon sau tabletă.",
        "1. Άνοιξε το Learning Maze στο τηλέφωνό σου ή στο tablet σου.",
        "1. Otvor Learning Maze na telefóne alebo tablete.",
        "1. פתח את Learning Maze בטלפון או בטאבלט שלך.",
    ),
    (
        "mp_banner_step_2",
        "2. Check you are connected to the same WiFi/network.",
        "2. Ujisti se, že jsi připojen ke stejné Wi-Fi/síti.",
        "2. Stelle sicher, dass du mit demselben WLAN/Netzwerk verbunden bist.",
        "2. Asegúrate de estar conectado al mismo WiFi/red.",
        "2. Vérifie que tu es connecté au même WiFi/réseau.",
        "2. Verifique se está conectado ao mesmo WiFi/rede.",
        "2. Kiểm tra kết nối cùng WiFi/mạng.",
        "2. Aynı WiFi/ağa bağlı olduğundan emin ol.",
        "2. Assicurati di essere connesso allo stesso WiFi/rete.",
        "2. Upewnij się, że jesteś podłączony do tej samej sieci Wi-Fi.",
        "2. Kontrollera att du är ansluten till samma WiFi/nätverk.",
        "2. Sjekk at du er koblet til samme WiFi/nettverk.",
        "2. Controleer of je verbonden bent met hetzelfde WiFi/netwerk.",
        "2. Переконайся, що підключений до тієї ж Wi-Fi/мережі.",
        "2. Tarkista, että olet yhteydessä samaan WiFi-verkkoon.",
        "2. Tjek at du er forbundet til det samme WiFi/netværk.",
        "2. Ellenőrizd, hogy ugyanahhoz a WiFi-hálózathoz csatlakoztál.",
        "2. Verificați că sunteți conectat la același WiFi/rețea.",
        "2. Βεβαιώσου ότι είσαι συνδεδεμένος στο ίδιο WiFi/δίκτυο.",
        "2. Uisti sa, že si pripojený k rovnakej Wi-Fi/sieti.",
        "2. בדוק שאתה מחובר לאותו WiFi/רשת.",
    ),
    (
        "mp_banner_step_3",
        "3. Tap the green Play Together card.",
        "3. Klepni na zelenou kartu Hrát spolu.",
        "3. Tippe auf die grüne Karte Zusammen spielen.",
        "3. Toca la tarjeta verde Jugar juntos.",
        "3. Appuie sur la carte verte Jouer ensemble.",
        "3. Toque no cartão verde Jogar juntos.",
        "3. Nhấn vào thẻ Chơi cùng nhau màu xanh.",
        "3. Yeşil Birlikte oyna kartına dokun.",
        "3. Tocca la scheda verde Gioca insieme.",
        "3. Dotknij zielonej karty Graj razem.",
        "3. Tryck på det gröna kortet Spela tillsammans.",
        "3. Trykk på det grønne kortet Spill sammen.",
        "3. Tik op de groene kaart Samen spelen.",
        "3. Натисни зелену картку Грати разом.",
        "3. Napauta vihreää Pelaa yhdessä -korttia.",
        "3. Tryk på det grønne kort Spil sammen.",
        "3. Érintsd meg a zöld Játssz együtt kártyát.",
        "3. Atinge cardul verde Joacă împreună.",
        "3. Πάτησε την πράσινη κάρτα Παίξτε μαζί.",
        "3. Ťukni na zelenú kartu Hrať spolu.",
        "3. הקש על הכרטיס הירוק שחקו יחד.",
    ),
    (
        "mp_banner_step_4",
        '4. Choose your player avatar and click "Join".',
        '4. Zvol si avatar hráče a klikni na "Připojit se".',
        '4. Wähle deinen Spieler-Avatar und klicke auf "Beitreten".',
        '4. Elige tu avatar y haz clic en "Unirse".',
        '4. Choisis ton avatar et clique sur "Rejoindre".',
        '4. Escolha seu avatar e clique em "Entrar".',
        '4. Chọn avatar và nhấn "Tham gia".',
        '4. Oyuncu avatarını seç ve "Katıl" düğmesine tıkla.',
        '4. Scegli il tuo avatar e clicca su "Partecipa".',
        '4. Wybierz awatar i kliknij "Dołącz".',
        '4. Välj din avatar och klicka på "Gå med".',
        '4. Velg avatar og klikk på "Bli med".',
        '4. Kies je avatar en klik op "Meedoen".',
        '4. Вибери аватар і натисни "Приєднатися".',
        '4. Valitse avatar ja napsauta "Liity".',
        '4. Vælg din avatar og klik på "Deltag".',
        '4. Válaszd ki az avatarját és kattints a "Csatlakozás" gombra.',
        '4. Alege avatarul și fă clic pe "Alătură-te".',
        '4. Επίλεξε το avatar σου και πάτησε "Συμμετοχή".',
        '4. Vyber avatara a klikni na "Pripojiť sa".',
        '4. בחר את האווטר שלך ולחץ על "הצטרף".',
    ),
    (
        "mp_banner_step_5",
        "5. Use your device as the controller for this screen.",
        "5. Použij svůj telefon jako ovladač pro tuto obrazovku.",
        "5. Verwende dein Gerät als Controller für diesen Bildschirm.",
        "5. Usa tu dispositivo como control para esta pantalla.",
        "5. Utilise ton appareil comme manette pour cet écran.",
        "5. Use seu dispositivo como controle para esta tela.",
        "5. Dùng thiết bị của bạn làm bộ điều khiển cho màn hình này.",
        "5. Cihazını bu ekran için kumanda olarak kullan.",
        "5. Usa il tuo dispositivo come controller per questo schermo.",
        "5. Użyj urządzenia jako kontrolera do tego ekranu.",
        "5. Använd din enhet som kontroll för den här skärmen.",
        "5. Bruk enheten din som kontroller for denne skjermen.",
        "5. Gebruik je apparaat als controller voor dit scherm.",
        "5. Використовуй пристрій як контролер для цього екрана.",
        "5. Käytä laitettasi tämän näytön ohjaimena.",
        "5. Brug din enhed som controller til denne skærm.",
        "5. Használd az eszközödet vezérlőként ezen a képernyőn.",
        "5. Folosește dispozitivul ca controler pentru acest ecran.",
        "5. Χρησιμοποίησε τη συσκευή σου ως χειριστήριο για αυτή την οθόνη.",
        "5. Použi svoje zariadenie ako ovládač pre túto obrazovku.",
        "5. השתמש במכשיר שלך כבקר עבור המסך הזה.",
    ),
    (
        "mp_banner_qr_title",
        "Don't have the app yet?",
        "Ještě nemáš aplikaci?",
        "Noch keine App?",
        "¿Aún no tienes la app?",
        "Tu n'as pas encore l'appli ?",
        "Ainda não tem o app?",
        "Chưa có ứng dụng?",
        "Uygulama yok mu?",
        "Non hai ancora l'app?",
        "Nie masz jeszcze aplikacji?",
        "Har du inte appen än?",
        "Har du ikke appen ennå?",
        "App nog niet?",
        "Ще немає застосунку?",
        "Ei sovellusta vielä?",
        "Har du ikke appen endnu?",
        "Nincs még meg az alkalmazás?",
        "Nu ai aplicația?",
        "Δεν έχεις ακόμα την εφαρμογή;",
        "Ešte nemáš aplikáciu?",
        "עדיין אין לך את האפליקציה?",
    ),
]


def csv_escape(val: str) -> str:
    """Wrap in quotes if the value contains a comma or double-quote."""
    if ',' in val or '"' in val or '\n' in val:
        return '"' + val.replace('"', '""') + '"'
    return val


def make_row(fields) -> str:
    return ','.join(csv_escape(f) for f in fields)


with open(csv_path, 'rb') as f:
    content = f.read()

# Strip trailing blank line / whitespace bytes
content = content.rstrip(b'\r\n')

lines_to_add = []
for row in new_rows:
    lines_to_add.append(make_row(row).encode('utf-8'))

appended = content + b'\r\n' + b'\r\n'.join(lines_to_add) + b'\r\n'

with open(csv_path, 'wb') as f:
    f.write(appended)

print(f"Done. Added {len(new_rows)} rows to {csv_path}")
