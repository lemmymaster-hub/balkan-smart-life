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

Lokalne komande imaju prednost nad udaljenim modelom. Tako osnovno upravljanje
aplikacijom ostaje brzo, predvidivo i dostupno čak i kada AI server ne radi.

## Pokretanje klijenta

Sigurni backend endpoint se predaje kroz compile-time konfiguraciju:

```powershell
flutter run --dart-define=BSL_AI_ENDPOINT=https://api.example.com/v1/ask
```

Backend mora prihvatiti Firebase ID token kroz `Authorization: Bearer ...`.

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
  "answer": "Najbliži verifikovani parking je ...",
  "city": "Sarajevo",
  "grounded": true,
  "sources": [
    {
      "title": "Službeni podaci operatera",
      "url": "https://example.com/source"
    }
  ],
  "request_id": "request-123",
  "action": {
    "type": "open_parking",
    "label": "Otvori Parkiraj.ba",
    "parameters": {
      "city": "Sarajevo",
      "query": "bolnica",
      "select_nearest": true
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

`grounded` smije biti `true` samo kada je odgovor stvarno zasnovan na
navedenim izvorima. U svim ostalim slučajevima UI prikazuje upozorenje da
važnu informaciju treba dodatno provjeriti.

## Sigurnosna pravila

- `NVIDIA_API_KEY` postoji samo u backend secret storeu.
- Backend provjerava Firebase token, primjenjuje rate limiting i ograničava
  dužinu pitanja.
- Backend čuva `NVIDIA_API_KEY` u secret storeu i poziva NVIDIA
  OpenAI-compatible/NIM endpoint.
- Internet pretraga se obavlja na backendu i vraća citirane izvore; Flutter ne
  daje modelu nekontrolisan pristup internetu.
- Upit se filtrira po izabranom gradu; nema tihog vraćanja Sarajeva za druge
  gradove.
- Izvori i vrijeme ažuriranja moraju se čuvati uz RAG dokumente.
- Otvaranje modula i pretraga mogu biti automatski. Navigacija, rezervacija,
  kupovina i plaćanje moraju imati eksplicitnu potvrdu korisnika.
