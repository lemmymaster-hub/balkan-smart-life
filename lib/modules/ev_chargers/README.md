# EL Punjači

Modul prikazuje `amenity=charging_station` podatke iz OpenStreetMapa za
trenutni ili izabrani BSL grad. OSM ostaje osnovni izvor, a Firestore služi kao
provjereni sloj za ispravke i deaktivaciju zastarjelih zapisa.

## Firestore verifikacije

Kolekcija se zove `ev_charger_verifications`. Preporučeni ID dokumenta jednak
je BSL ID-u OSM objekta, na primjer `osm_node_6167066542`. Može se koristiti i
drugi ID dokumenta ako polje `chargerId` sadrži taj BSL ID.

Minimalni potvrđeni dokument:

```json
{
  "chargerId": "osm_node_6167066542",
  "city": "Sarajevo",
  "verified": true,
  "isActive": true,
  "verifiedAt": "Firestore Timestamp"
}
```

Podržane opcionalne ispravke su `name`, `address`, `operatorName`, `access`,
`openingHours`, `feeStatus`, `priceLabel`, `note`, `capacity` i `connectors`.
`feeStatus` može biti `free`, `paid` ili `unknown`. Jedan connector može imati
polja `type`, `count` i `powerKw`.

Dokument bez `verified: true` ne mijenja OSM podatak. Potvrđeni dokument sa
`isActive: false` uklanja punjač iz prikaza.

Klijentska aplikacija treba imati samo pravo čitanja ove kolekcije. Primjer
pravila za aplikaciju u kojoj su korisnici prijavljeni:

```text
match /ev_charger_verifications/{chargerId} {
  allow read: if request.auth != null;
  allow write: if false;
}
```

Verifikacije se upisuju kroz Firebase Console ili pouzdani administratorski
alat, ne iz mobilne aplikacije.
