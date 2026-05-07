import csv

LANGS = ["en","cs","de","es","fr","pt","vi","tr","it","pl","sv","nb","nl","uk","fi","da","hu","ro","el","sk","he"]

t1 = {
    "en": "1. Install the \"Learning Maze\" app on your phone or tablet.",
    "cs": "1. Nainstaluj \"Learning Maze\" na telefon nebo tablet.",
    "de": "1. Installiere die \"Learning Maze\"-App auf deinem Handy oder Tablet.",
    "es": "1. Instala la app \"Learning Maze\" en tu teléfono o tableta.",
    "fr": "1. Installe l'application \"Learning Maze\" sur ton téléphone ou tablette.",
    "pt": "1. Instale o app \"Learning Maze\" no seu telefone ou tablet.",
    "vi": "1. Cài đặt ứng dụng \"Learning Maze\" trên điện thoại hoặc máy tính bảng của bạn.",
    "tr": "1. \"Learning Maze\" uygulamasını telefonunuza veya tabletinize yükleyin.",
    "it": "1. Installa l'app \"Learning Maze\" sul tuo telefono o tablet.",
    "pl": "1. Zainstaluj aplikację \"Learning Maze\" na swoim telefonie lub tablecie.",
    "sv": "1. Installera appen \"Learning Maze\" på din telefon eller surfplatta.",
    "nb": "1. Installer appen \"Learning Maze\" på telefonen eller nettbrettet ditt.",
    "nl": "1. Installeer de app \"Learning Maze\" op uw telefoon of tablet.",
    "uk": "1. Встановіть програму \"Learning Maze\" на телефон або планшет.",
    "fi": "1. Asenna \"Learning Maze\" -sovellus puhelimeesi tai tablettiisi.",
    "da": "1. Installer appen \"Learning Maze\" på din telefon eller tablet.",
    "hu": "1. Telepítsd a \"Learning Maze\" alkalmazást a telefonodra vagy táblagépedre.",
    "ro": "1. Instalați aplicația \"Learning Maze\" pe telefon sau tabletă.",
    "el": "1. Εγκαταστήστε την εφαρμογή \"Learning Maze\" στο τηλέφωνο ή το tablet σας.",
    "sk": "1. Nainštaluj \"Learning Maze\" na telefón alebo tablet.",
    "he": "1. התקן את אפליקציית \"Learning Maze\" בטלפון או בטאבלט שלך."
}

t2 = {
    "en": "2. Make sure you are connected to the same Wi-Fi as this device%s.",
    "cs": "2. Ujisti se, že jsi připojen ke stejné Wi-Fi jako toto zařízení%s.",
    "de": "2. Stelle sicher, dass du mit demselben WLAN wie dieses Gerät verbunden bist%s.",
    "es": "2. Asegúrate de estar conectado al mismo Wi-Fi que este dispositivo%s.",
    "fr": "2. Assure-toi d'être connecté au même Wi-Fi que cet appareil%s.",
    "pt": "2. Certifique-se de estar conectado ao mesmo Wi-Fi que este dispositivo%s.",
    "vi": "2. Đảm bảo bạn được kết nối với cùng Wi-Fi như thiết bị này%s.",
    "tr": "2. Bu cihazla aynı Wi-Fi ağına bağlı olduğunuzdan emin olun%s.",
    "it": "2. Assicurati di essere connesso allo stesso Wi-Fi di questo dispositivo%s.",
    "pl": "2. Upewnij się, że jesteś podłączony do tego samego Wi-Fi co to urządzenie%s.",
    "sv": "2. Se till att du är ansluten till samma Wi-Fi som den här enheten%s.",
    "nb": "2. Sørg for at du er koblet til samme Wi-Fi som denne enheten%s.",
    "nl": "2. Zorg ervoor dat je verbonden bent met dezelfde wifi als dit apparaat%s.",
    "uk": "2. Переконайтеся, що ви підключені до того ж Wi-Fi, що й цей пристрій%s.",
    "fi": "2. Varmista, että olet yhdistetty samaan Wi-Fi-verkkoon kuin tämä laite%s.",
    "da": "2. Sørg for at du er forbundet til det samme Wi-Fi som denne enhed%s.",
    "hu": "2. Győződj meg róla, hogy ugyanahhoz a Wi-Fi-hez csatlakozol, mint ez az eszköz%s.",
    "ro": "2. Asigură-te că ești conectat la același Wi-Fi ca acest dispozitiv%s.",
    "el": "2. Βεβαιωθείτε ότι είστε συνδεδεμένοι στο ίδιο Wi-Fi με αυτήν τη συσκευή%s.",
    "sk": "2. Uisti sa, že si pripojený k rovnakej Wi-Fi ako toto zariadenie%s.",
    "he": "2. ודא שאתה מחובר לאותו Wi-Fi כמו מכשיר זה%s."
}

t3 = {
    "en": "3. Open the app and tap this card when it appears:",
    "cs": "3. Otevři aplikaci a klepni na tuto kartu, jakmile se objeví:",
    "de": "3. Öffne die App und tippe auf diese Karte, wenn sie erscheint:",
    "es": "3. Abre la app y toca esta tarjeta cuando aparezca:",
    "fr": "3. Ouvre l'application et touche cette carte quand elle apparaît :",
    "pt": "3. Abra o app e toque neste cartão quando ele aparecer:",
    "vi": "3. Mở ứng dụng và chạm vào thẻ này khi nó xuất hiện:",
    "tr": "3. Uygulamayı açın ve göründüğünde bu karta dokunun:",
    "it": "3. Apri l'app e tocca questa scheda quando appare:",
    "pl": "3. Otwórz aplikację i dotknij tej karty, gdy się pojawi:",
    "sv": "3. Öppna appen och tryck på det här kortet när det visas:",
    "nb": "3. Åpne appen og trykk på dette kortet når det dukker opp:",
    "nl": "3. Open de app en tik op deze kaart wanneer deze verschijnt:",
    "uk": "3. Відкрийте додаток і торкніться цієї картки, коли вона з'явиться:",
    "fi": "3. Avaa sovellus ja napauta tätä korttia, kun se ilmestyy:",
    "da": "3. Åbn appen og tryk på dette kort, når det vises:",
    "hu": "3. Nyisd meg az alkalmazást, és koppints erre a kártyára, amikor megjelenik:",
    "ro": "3. Deschide aplicația și atinge acest card când apare:",
    "el": "3. Ανοίξτε την εφαρμογή και πατήστε αυτήν την κάρτα όταν εμφανιστεί:",
    "sk": "3. Otvor aplikáciu a ťukni na túto kartu, keď sa objaví:",
    "he": "3. פתח את האפליקציה והקש על כרטיס זה כשהוא מופיע:"
}

with open('data/translations.csv', 'a', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(["mp_join_step_phone"] + [t1[l] for l in LANGS])
    writer.writerow(["mp_join_step_wifi"] + [t2[l] for l in LANGS])
    writer.writerow(["mp_join_step_open_card"] + [t3[l] for l in LANGS])

print("Done.")
