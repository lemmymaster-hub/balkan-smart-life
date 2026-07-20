# BSL Novčanik Demo

Ovaj modul je interni UI/UX prototip za BSL tim i prezentacije investitorima.
Ne povezuje se s bankom, payment providerom, trgovcem, QR terminalom ili NFC
terminalom i ne izvršava stvarnu naplatu.

## Demo funkcionalnosti

- početna testna Visa kartica i testna istorija transakcija
- unos više demo kartica i izbor zadane kartice
- simulirani 3-D Secure kod `123456`
- stvarna sistemska provjera registrovane biometrije prije svakog plaćanja
- izbor kartice za svako pojedinačno plaćanje
- demo plaćanja parkinga, EL punjača, taxi vožnje i računa
- simulacija QR plaćanja kod trgovca i na parking aparatu
- simulacija NFC toka "prisloni telefon"
- lokalno pamćenje maskiranih demo kartica i demo transakcija po korisniku
- vraćanje početnog demo stanja iz menija

## Sigurnosna granica

Forma služi samo za demonstraciju budućeg toka. Koristi Visa testni broj
`4242 4242 4242 4242` ili Mastercard testni broj
`5555 5555 5555 4444`, datum `12/30`, CVV `123` i demo 3-D Secure kod
`123456`. Forma odbija druge brojeve, a na ekranu je jasno upozorenje da se ne
unosi stvarna kartica.

Nakon potvrde forma kontroleru predaje samo:

- naziv kartice
- ime vlasnika
- posljednje četiri cifre
- tip kartice
- mjesec i godinu isteka

Puni broj kartice, CVV, telefon, email i OTP se ne upisuju u
`SharedPreferences`, Firestore niti model kartice. U produkciji te podatke mora
obrađivati certificirani hosted/SDK prozor payment providera, a BSL dobija samo
token i maskirane metapodatke.

Biometrijsku provjeru izvršava operativni sistem pomoću `local_auth`. BSL dobija
samo rezultat uspjeh/neuspjeh i nikada nema pristup slici otiska ili
biometrijskom predlošku. Uključena je opcija `biometricOnly`, pa PIN, šara ili
lozinka ne zamjenjuju biometriju u ovom toku.

## Produkcijska integracija

Za stvarno kartično ili NFC plaćanje potrebni su ugovoreni payment provider,
server-side tokenizacija, 3-D Secure, PCI DSS odgovornosti, backend potvrda
iznosa i digitalni račun. Pravi NFC tok dodatno zahtijeva podržani EMV token,
Android HCE/Secure Element integraciju i certifikaciju payment partnera.

Trenutna biometrija je stvarna lokalna potvrda identiteta, ali još nije
kriptografski vezana za bankarsku transakciju. Produkcijska verzija mora spojiti
uspješnu biometriju sa jednokratnim backend zahtjevom i providerovom potvrdom.

Demo kod se ne smije samo "uključiti" u produkciji. Prije javne objave treba
zamijeniti lokalne simulatore pravim backend ugovorima i ukloniti testne
podatke.
