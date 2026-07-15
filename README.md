# BSL – Balkan Smart Life

BSL (Balkan Smart Life) je modularna Smart City platforma koja objedinjuje
svakodnevne gradske i lokalne usluge u jednoj Flutter aplikaciji prilagođenoj
gradovima i opštinama u regionu.

## Trenutne funkcionalnosti

### Korisnički račun

- Firebase registracija i prijava
- trajna korisnička sesija
- korisnički profil i odjava

### Vremenska prognoza

- trenutno vrijeme i sedmodnevna prognoza
- izbor i pamćenje grada
- Open-Meteo integracija

### Parkiraj.ba

- prikaz aktivnih parkinga iz Cloud Firestore baze
- Google mapa sa prilagođenim BSL markerima
- stanje zauzetosti i detalji parkinga
- pretraga parkinga i adresa
- pomjeranje i fokusiranje mape na rezultat

### Modularna struktura

- odvojeni moduli, modeli i servisni slojevi
- zajednički BSL dizajn sistem
- arhitektura pripremljena za dodavanje novih Smart City usluga

BSL Mesh je zasebna aplikacija za komunikaciju i pomoć u kriznim situacijama i
nije dio ovog repozitorija.

## Tehnologije

- Flutter i Dart
- Firebase Authentication
- Cloud Firestore
- Google Maps SDK for Android
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
- API restriction: samo **Maps SDK for Android**

Debug i produkcijski build ne trebaju dijeliti isti ključ. Za release build
koristi zaseban ključ ograničen release certifikatom.

Pretraga adresa koristi sistemski geocoder na Androidu i iOS-u, pa aplikaciji
nije potreban javno ugrađen Google Places REST ključ.

## Razvoj

Aktivna razvojna grana i izvor istine je `main`. Nove funkcionalnosti trebaju
se razvijati u kratkotrajnim granama i vraćati u `main` nakon provjere.

Planirani moduli uključuju gradski prevoz, taxi, turističke informacije,
lokalne vijesti, digitalni novčanik, prijavu problema, nagrade i AI asistenta.

## Autor

Mile Vujasin

[GitHub profil](https://github.com/lemmymaster-hub)
