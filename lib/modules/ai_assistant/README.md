# Pitaj BSL

`Pitaj BSL` je komandni i informativni sloj BSL aplikacije. Flutter klijent ne
kontaktira NVIDIA API direktno i ne sadrži NVIDIA ključ.

## Trenutno funkcionalno

Česte komande se lokalno prepoznaju bez AI tokena i bez zavisnosti od
backenda:

- otvaranje Parkiraj.ba i pretraga lokacije ili najbližeg parkinga;
- otvaranje EL Punjača i pretraga lokacije ili najbližeg punjača;
- otvaranje vremenske prognoze za grad naveden u pitanju;
- otvaranje BSL novčanika tek nakon dodira korisnika.

Primjer:

```text
Pronađi mi parking u blizini bolnice
  -> open_parking(city: Sarajevo, query: bolnica, select_nearest: true)
  -> Parkiraj.ba pretražuje bolnicu i označava najbliži mapirani parking
```

Za zahtjev koji izričito spominje korisnikovu lokaciju ne šalje se tekst
`moja lokacija` geokoderu:

```text
Nađi mi EL punjač blizu moje lokacije
  -> open_ev_chargers(
       city: grad određen iz GPS-a,
       query: null,
       select_nearest: true,
       use_current_location: true
     )
  -> EL Punjači računa udaljenost od stvarnih GPS koordinata
```

Ako GPS nije dostupan, aplikacija ne smije tiho koristiti centar grada i
glumiti precizan rezultat. Korisniku se prikazuje da mora omogućiti lokaciju.

Lokalne komande imaju prednost nad udaljenim modelom. Tako osnovno upravljanje
aplikacijom ostaje brzo, predvidivo i dostupno čak i kada AI server ne radi.
NVIDIA model obrađuje složenije upite koje lokalni sigurni resolver ne
prepoznaje.

## Pokretanje klijenta

Sigurni backend endpoint se predaje kroz compile-time konfiguraciju:

```powershell
flutter run --dart-define=BSL_AI_ENDPOINT=https://europe-west1-YOUR_PROJECT_ID.cloudfunctions.net/bslAiAsk
```

Backend mora prihvatiti Firebase ID token kroz `Authorization: Bearer ...`.
Klijent šalje i Firebase App Check token kroz `X-Firebase-AppCheck`.

Zahtjev:

```json
{
  "question": "Gdje je najbliži parking?",
  "city": "Sarajevo",
  "locale": "bs",
  "context": {
    "city": "Sarajevo",
    "locale": "bs",
    "location": {
      "latitude": 43.8563,
      "longitude": 18.4131
    },
    "supported_actions": [
      "open_parking",
      "open_ev_chargers",
      "open_weather",
      "open_wallet"
    ]
  }
}
```

Odgovor:

```json
{
  "answer": "Otvaram Parkiraj.ba i tražim parking kod bolnice.",
  "city": "Sarajevo",
  "grounded": false,
  "sources": [],
  "request_id": "request-123",
  "action": {
    "type": "open_parking",
    "label": "Otvori Parkiraj.ba",
    "parameters": {
      "city": "Sarajevo",
      "query": "bolnica",
      "select_nearest": true,
      "use_current_location": false
    }
  }
}
```

Flutter izvršava samo akcije iz ugrađene allow-liste. Nepoznata akcija ili
proizvoljna ruta iz AI odgovora se odbacuje. Dodavanje nove akcije zahtijeva:

1. novi `BslAiActionType`;
2. eksplicitnu sigurnosnu politiku automatskog ili potvrđenog izvršavanja;
3. executor u `HomeScreen` ili odgovarajućem modulu;
4. test parsera, JSON ugovora i izvršavanja.

Trenutni NVIDIA backend nije RAG niti internet pretraživač. Zato backend
prisilno vraća `grounded: false` i prazne izvore čak i kada model pokuša
izmisliti citat. `grounded` smije postati `true` tek kada se doda stvarni
provjereni izvor podataka.

## Sigurnosna pravila

- `NVIDIA_API_KEY` postoji samo u backend secret storeu.
- Backend provjerava Firebase ID token i App Check, primjenjuje Firestore
  rate limiting i ograničava dužinu pitanja.
- Backend čuva `NVIDIA_API_KEY` u secret storeu i poziva NVIDIA
  OpenAI-compatible/NIM endpoint.
- Precizne GPS koordinate ostaju u BSL aplikaciji. NVIDIA dobija samo podatak
  da li je lokacija dostupna.
- Internet pretraga još nije uključena. Kada bude dodana, radiće samo kroz
  backend alat sa provjerljivim izvorima i ograničenim domenima.
- Upit se filtrira po izabranom gradu; nema tihog vraćanja Sarajeva za druge
  gradove.
- Izvori i vrijeme ažuriranja moraju se čuvati uz RAG dokumente.
- Otvaranje modula i pretraga mogu biti automatski. Navigacija, rezervacija,
  kupovina i plaćanje moraju imati eksplicitnu potvrdu korisnika.

Implementacija, App Check i deploy koraci nalaze se u
[`functions/README.md`](../../../functions/README.md).
