# Pitaj BSL

`Pitaj BSL` je kompaktni AI ulaz na početnom ekranu. Flutter klijent ne
kontaktira NVIDIA API direktno i ne sadrži NVIDIA ključ.

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
  "locale": "bs"
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
  "request_id": "request-123"
}
```

`grounded` smije biti `true` samo kada je odgovor stvarno zasnovan na
navedenim izvorima. U svim ostalim slučajevima UI prikazuje upozorenje da
važnu informaciju treba dodatno provjeriti.

## Sigurnosna pravila

- `NVIDIA_API_KEY` postoji samo u backend secret storeu.
- Backend provjerava Firebase token, primjenjuje rate limiting i ograničava
  dužinu pitanja.
- Upit se filtrira po izabranom gradu; nema tihog vraćanja Sarajeva za druge
  gradove.
- Izvori i vrijeme ažuriranja moraju se čuvati uz RAG dokumente.
