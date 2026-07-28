# BSL – Balkan Smart Life

BSL (Balkan Smart Life) je modularna Smart City platforma koja objedinjuje
svakodnevne gradske i lokalne usluge u jednoj Flutter aplikaciji prilagođenoj
gradovima i opštinama u regionu.

## Trenutne funkcionalnosti

### Korisnički račun

- Firebase registracija i prijava
- trajna korisnička sesija
- korisnički profil i odjava

### Početni ekran

- promjena rasporeda modula dugim pritiskom i prevlačenjem
- lokalno pamćenje rasporeda odvojeno za svakog prijavljenog korisnika
- automatsko dodavanje novih modula bez gubitka korisničkog rasporeda
- vraćanje početnog rasporeda iz režima uređivanja

### Vremenska prognoza

- trenutno vrijeme i sedmodnevna prognoza
- izbor i pamćenje grada
- Open-Meteo integracija

### Parkiraj.ba

- prikaz aktivnih parkinga iz Cloud Firestore baze
- Google mapa sa prilagođenim BSL markerima i trenutnom lokacijom
- stanje zauzetosti i detalji parkinga
- pretraga parkinga i adresa
- pomjeranje i fokusiranje mape na rezultat
- turn-by-turn navigacija unutar postojećeg Parkiraj.ba ekrana
- BSL dark mapa, parking markeri i zaglavlje ostaju vidljivi tokom navigacije
- navigacijske informacije zamjenjuju podatke u istoj donjoj parking kartici
- road-snapped praćenje, glasovne upute i automatski proračun nove rute
- broj u zaglavlju prikazuje mapirane parkinge i dopunjava grad iz koordinata

### EL Punjači

- OSM punjači za sve aktivne BSL gradove
- Firestore verifikacija i ispravke podataka
- pretraga punjača, adresa i gradova
- BSL markeri prema statusu cijene punjenja
- ugrađena turn-by-turn navigacija od trenutne lokacije do punjača
- BHS glasovne upute, road-snapped ruta i rotirajući BSL automobil na dark mapi
- lokalno, trajno praćenje procijenjenog punjenja kada je poznata snaga priključka
- read-only Firestore kanal za buduće stvarne sesijske podatke operatora
- jasno razdvajanje procjene od operatorovog mjerenja; plaćanje još nije uključeno

### BSL Novčanik Demo

- interni investicijski UI/UX prototip bez stvarne naplate
- više maskiranih demo kartica i izbor kartice za svako plaćanje
- simulirani unos kartice, tokenizacija i 3-D Secure potvrda
- demo plaćanje BSL usluga, QR plaćanje i NFC "prisloni telefon" tok
- stvarna sistemska biometrijska potvrda identiteta prije demo plaćanja
- lokalna istorija simuliranih transakcija po korisniku
- puni broj kartice i CVV se ne čuvaju u modelu, Firestoreu ili lokalnoj pohrani

### Pitaj BSL

- lokalne sigurne komande za parking, EL punjače, vrijeme i novčanik
- GPS zahtjevi koriste stvarne koordinate umjesto geokodiranja izraza
  `moja lokacija`
- Firebase Functions v2 backend za složenije NVIDIA NIM upite
- Firebase Auth, App Check, Secret Manager i Firestore rate limiting
- stroga allow-lista akcija; model ne može pokrenuti plaćanje ili proizvoljnu
  aplikacijsku rutu
- bez lažnih citata: odgovori ostaju neprovjereni dok se ne doda stvarni
  RAG/internet izvor

### Modularna struktura

- odvojeni moduli, modeli i servisni slojevi
- zajednički BSL dizajn sistem
- arhitektura pripremljena za dodavanje novih Smart City usluga

BSL Mesh je zasebna aplikacija za komunikaciju i pomoć u kriznim situacijama i
nije dio ovog repozitorija.

## Tehnologije

- Flutter i Dart
- Firebase Authentication
- Firebase App Check i Cloud Functions
- Cloud Firestore
- NVIDIA NIM API kroz sigurni backend
- Google Navigation for Flutter i Navigation SDK for Android
- sistemski Android/iOS geocoder
- Open-Meteo API
- Git i GitHub

## Lokalno pokretanje

1. Instaliraj Flutter verziju koja podržava Dart `^3.12.0`.
2. Pokreni `flutter pub get`.
3. U datoteku `android/local.properties` dodaj lokalni Google Maps ključ:

   ```properties
   MAPS_API_KEY=ovdje_unesi_svoj_kljuc
   ```

4. Pokreni aplikaciju pomoću `flutter run`.

`android/local.properties` je ignorisan u Gitu. Ne upisuj stvarni ključ u
`AndroidManifest.xml`, Dart kod, README ili drugu praćenu datoteku.

## Google Maps konfiguracija

Android Maps ključ treba imati sljedeća ograničenja:

- application restriction: **Android apps**
- package name: `ba.balkansmartlife.app`
- SHA-1 certifikata kojim se potpisuje odgovarajući build
- API restrictions: **Navigation SDK** i **Maps SDK for Android**

U istom Google Cloud projektu moraju biti uključeni Navigation SDK i billing.
Navigation SDK zamjenjuje direktnu Maps SDK zavisnost u aplikaciji, ali isti
ograničeni Android ključ autorizuje prikaz mape i navigaciju.

Navigacija zahtijeva Android API 24 ili noviji, Google Play Services i preciznu
lokaciju. Pri prvom pokretanju korisnik mora prihvatiti Google uslove za
navigaciju. Rutu, glasovne upute, road snapping, rerutiranje i prateću kameru
izvršava nativni Google Navigation SDK, dok aplikacija zadržava vlastiti BSL
interfejs i isključuje ugrađeno Google navigacijsko zaglavlje i podnožje.
Android aplikacija prije inicijalizacije bira `bs`, `hr` ili `sr` locale
telefona, a za druge jezike koristi `bs-BA`, i taj BHS locale prosljeđuje SDK-u
prije pokretanja navigacijske sesije. Dostupnost konkretnog glasa zavisi od
Google govornih resursa instaliranih na uređaju.

Navigation SDK 7.7.0 koristi Android Gradle Plugin 8.13.2 i Gradle 8.13.
Ove verzije su namjerno zaključane jer AGP 9 odbija njegove zasebne Cronet
biblioteke koje trenutno dijele isti Android namespace.

Debug i produkcijski build ne trebaju dijeliti isti ključ. Za release build
koristi zaseban ključ ograničen release certifikatom.

Pretraga adresa koristi sistemski geocoder na Androidu i iOS-u, pa aplikaciji
nije potreban javno ugrađen Google Places REST ključ.

Prije produkcijske objave u pravne napomene aplikacije treba dodati službene
`NOTICE.txt` i `LICENSES.txt` datoteke iz korištene Navigation SDK distribucije.

## Razvoj

Aktivna razvojna grana i izvor istine je `main`. Nove funkcionalnosti trebaju
se razvijati u kratkotrajnim granama i vraćati u `main` nakon provjere.

Planirani moduli uključuju gradski prevoz, taxi, turističke informacije,
lokalne vijesti, produkcijsku payment integraciju novčanika, prijavu problema,
nagrade i AI asistenta.

## Autor

Mile Vujasin

[GitHub profil](https://github.com/lemmymaster-hub)
