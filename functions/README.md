# BSL AI backend

Firebase Functions v2 backend za `Pitaj BSL`. Flutter aplikacija nikada ne
kontaktira NVIDIA API direktno i nikada ne sadrži NVIDIA ključ.

## Zaštita

- Firebase ID token je obavezan.
- Firebase App Check je podrazumijevano obavezan.
- NVIDIA ključ je Cloud Secret Manager secret.
- Firestore transakcija ograničava pozive po korisniku.
- Model može vratiti samo četiri dozvoljene BSL akcije.
- Backend ponovo validira svaki odgovor modela.
- GPS koordinate se ne šalju NVIDIA modelu. Model dobija samo informaciju da
  li je lokacija dostupna; stvarni najbliži rezultat računa Flutter modul.
- Promptovi i GPS koordinate se ne zapisuju u log.
- `grounded` ostaje `false` dok ne bude ugrađen provjeren RAG/internet sloj.

U postojeća Firestore pravila spoji sadržaj
`firestore-ai-rules.snippet`. Mobilni klijent ne smije čitati ni mijenjati
`bsl_ai_rate_limits`; Admin SDK u Cloud Functionu pravila zaobilazi. Nemoj
zamijeniti postojeći rules fajl samim isječkom jer bi to moglo pokvariti
parkinge, punjače i druge kolekcije.

## Lokalna priprema

```powershell
cd functions
npm install
npm run check
npm test
cd ..
```

Kopiraj `.firebaserc.example` u `.firebaserc` i upiši stvarni Firebase project
ID. `.firebaserc` može biti verzionisan jer project ID nije tajna, ali nemoj
unositi servisni account ili API ključ u repozitorij.

## NVIDIA secret

Ne upisuj ključ u `.env`, Dart, `local.properties`, `firebase.json` ili GitHub
secret koji se kasnije kopira u aplikaciju.

```powershell
firebase login
firebase use YOUR_FIREBASE_PROJECT_ID
firebase functions:secrets:set NVIDIA_API_KEY
```

Firebase CLI će sigurno zatražiti vrijednost ključa i spremiti je u Google
Cloud Secret Manager.

Podrazumijevani model je `qwen/qwen3-next-80b-a3b-instruct` jer je prikladniji
za višejezične instrukcije i strukturisano planiranje od Llama 3.3 modela,
koji službeno ne navodi BHS jezike. Model se može promijeniti kroz
`NVIDIA_MODEL` bez izmjene Flutter aplikacije, ali svaka promjena zahtijeva
ponovno pokretanje BSL AI evaluacijskih upita.

## App Check

1. Firebase Console → App Check.
2. Registruj Android aplikaciju `ba.balkansmartlife.app`.
3. Produkcija koristi Play Integrity.
4. Debug build ispisuje debug token u `flutter run`/Logcat izlazu.
5. Taj token dodaj u Firebase Console → App Check → Manage debug tokens.
6. Debug token nikada ne stavljaj u Git.

Za lokalni Functions emulator možeš privremeno postaviti
`BSL_REQUIRE_APP_CHECK=false` u lokalni `functions/.env.local`. Taj fajl je
ignorisan. Produkcijski deploy mora ostati na `true`.

## Deploy

Cloud Functions deploy zahtijeva Firebase **Blaze** plan, iako postoje
besplatne mjesečne kvote. Prije deploya obavezno postavi Google Cloud budget
alert; rate limiting smanjuje zloupotrebu, ali budžetski alert nije automatski
limit potrošnje.

```powershell
firebase deploy --only functions:bslAiAsk
```

Nakon deploya CLI ispisuje HTTPS URL. Aplikaciju pokreni sa:

```powershell
flutter run --dart-define=BSL_AI_ENDPOINT=https://europe-west1-YOUR_PROJECT_ID.cloudfunctions.net/bslAiAsk
```

Za release build koristi isti `--dart-define`, ali endpoint postavi kroz
zaštićeni CI/CD build proces.

## Evaluacija preciznosti

Model se ne proglašava preciznim na osnovu nekoliko ručnih pokušaja. Nakon
deploya pokreni BHS evaluacijski skup:

```powershell
$env:BSL_AI_ENDPOINT = "https://europe-west1-YOUR_PROJECT_ID.cloudfunctions.net/bslAiAsk"
$env:FIREBASE_ID_TOKEN = "privremeni-testni-token"
$env:FIREBASE_APP_CHECK_TOKEN = "privremeni-app-check-token"
cd functions
npm run eval
```

Tokeni su kratkotrajni i ne smiju se zapisivati u fajl ili commit. Novi moduli
i nove vrste pitanja moraju dobiti evaluacijske slučajeve prije produkcije.

## Važno ograničenje

NVIDIA model povećava razumijevanje prirodnog jezika, ali sam po sebi ne zna
stvarno stanje parkinga, punjača, saobraćaja ni cijena. Za pouzdane odgovore
moraju se naknadno dodati BSL tools/RAG izvori. Do tada model samo planira
dozvoljenu akciju, a postojeći BSL moduli računaju stvarni rezultat.
