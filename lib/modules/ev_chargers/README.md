# EL Punjači

Modul prikazuje `amenity=charging_station` podatke iz OpenStreetMapa za
trenutni ili izabrani BSL grad. OSM ostaje osnovni izvor, a Firestore služi kao
provjereni sloj za ispravke i deaktivaciju zastarjelih zapisa.

## Firestore verifikacije

Mobilni klijent odmah učitava zadnji provjereni BiH OSM snapshot iz APK-a,
zatim bira noviji uspješno osvježeni snapshot sa uređaja i u pozadini ga
osvježava jednim ograničenim državnim upitom. Uspješan odgovor se čuva do 30
dana, pa ponovno pokretanje aplikacije ne vraća korisnika na stariji APK
snapshot. Koristi
aktivne `lz4.overpass-api.de`, `overpass-api.de` i `overpass.private.coffee`
endpoint-e, uz rok od 20 sekundi po pokušaju. Time ekran više ne čeka serijski
na ugašeni Mail.ru endpoint, ne šalje četiri paralelna zahtjeva i ostaje
upotrebljiv kada su javni Overpass serveri privremeno preopterećeni.

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

## Praćenje punjenja bez BSL plaćanja

Modul podržava dva strogo odvojena izvora podataka:

1. `BSL PROCJENA` radi odmah na punjačima za koje OSM ili Firestore sadrži
   potvrđenu snagu priključka. Korisnik prvo sam pokreće fizičko punjenje, a
   zatim u BSL-u bira **Prati punjenje**. Aplikacija prikazuje trajanje i
   matematičku procjenu energije `nazivna snaga × vrijeme`. Ova vrijednost nije
   očitanje mjerača i ne pokreće niti zaustavlja fizički punjač.
2. `OPERATOR • UŽIVO` je read-only kanal spreman za buduću partnersku
   integraciju. Pouzdani backend operatorove podatke upisuje u dokument
   `ev_active_charging_sessions/{firebaseUid}`; mobilna aplikacija ih samo čita.

Lokalna procjena se čuva po Firebase korisniku kroz `SharedPreferences`, pa se
nastavlja prikazivati nakon ponovnog pokretanja aplikacije. Plaćanje, novčanik i
komande fizičkom punjaču nisu dio ove implementacije.

Primjer live dokumenta koji backend može održavati:

```json
{
  "sessionId": "operator-session-123",
  "chargerId": "osm_node_13704011824",
  "chargerName": "Motion eGO",
  "city": "Sarajevo",
  "connectorLabel": "CCS2",
  "providerName": "Partnerski operator",
  "status": "charging",
  "startedAt": "Firestore Timestamp",
  "updatedAt": "Firestore Timestamp",
  "powerKw": 47.2,
  "energyKwh": 11.8,
  "batteryPercent": 54
}
```

Podržani statusi su `preparing`, `charging`, `paused`, `completed` i `failed`.
`batteryPercent` je opcionalan jer ga većina punjača ne dostavlja. Vrijednosti
`powerKw`, `energyKwh` i status smije upisivati samo pouzdani backend koji ih je
dobio od operatora/OCPP/OCPI sistema.

Preporučena minimalna pravila:

```text
match /ev_active_charging_sessions/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if false;
}
```

Dok operator ne izda API/OCPI pristup, dokument se ne smije popunjavati
izmišljenim "live" vrijednostima. Za takve punjače koristi se samo jasno
označena BSL procjena.

## Put do stvarnih podataka operatora

Javne stranice potvrđuju da e-GO, Charge&GO i UNISCharge već raspolažu
statusom i podacima sesije, ali ne objavljuju anoniman API kojim bi mobilni
klijent smio čitati korisnikovu sesiju. Produkcijska integracija zato ide
isključivo preko BSL backenda i partnerskih vjerodajnica operatora:

- e-GO mreža i snage: <https://e-go.ba/en/e-go-charger/>
- e-GO mogućnosti aplikacije: <https://play.google.com/store/apps/details?id=ba.ego.emobility.app>
- Charge&GO praćenje sesije: <https://chargego.rs/en/chargegoapp/>
- UNISCharge praćenje i upravljanje: <https://unistelekom.ba/en/unischarge-platform-for-monitoring-and-managing-the-charging-of-electric-vehicles/>
- OCPI standard za real-time sesije: <https://evroaming.org/ocpi/>

Operatorski token, ako ga BSL dobije, ostaje u server-side Secret Manageru.
Ne smije biti ugrađen u Flutter aplikaciju, `local.properties` niti Firestore
dokument koji klijent može čitati.
