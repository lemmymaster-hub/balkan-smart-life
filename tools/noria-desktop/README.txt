NORIA DESKTOP 0.1.1 — Windows 10/11 x64

NADOGRADNJA SA 0.1
Zatvori prethodni NoriaDesktop.exe i zamijeni ga EXE fajlom iz update ZIP-a
u ISTOM raspakovanom programskom folderu. Zadrži runtime i apks foldere.
Ne briši %LOCALAPPDATA%\NoriaDesktop: preuzeti Android i podaci ostaju tu.
Ponovo pokreni program: u naslovu treba da piše 0.1.1.
Ako je priprema već završena, odmah odaberi Pokreni Android.
Nova verzija ispravlja čekanje komandnih procesa sa pozadinskim serverom,
provjerava prisutnost emulatora prije ADB upita i bilježi tačnu komandu kod
timeouta. Dnevnik se čuva u %LOCALAPPDATA%\NoriaDesktop\noria-desktop.log.
Ako i dalje ne radi, klikni Provjeri sistem pa Kopiraj dnevnik i pošalji tekst.

1. Raspakuj CIJELI ZIP u svoj folder. Pokreni NoriaDesktop.exe.
2. Odaberi „Pripremi Android”. Internet je potreban za prvo preuzimanje
   Android alata i sistemske slike (nekoliko GB). Potrebno je najmanje 18 GB
   slobodnog prostora na disku na kojem je Windows korisnički profil.
3. U terminalu pročitaj Google licence. Unesi y samo ako prihvataš uslove.
   Aplikacija ne prihvata licence umjesto tebe. Zatvaranje/odbijanje licenci
   može prekinuti pripremu; pripremu možeš pokrenuti ponovo.
4. Odaberi „Pokreni Android”. Ako ubrzanje nije dostupno, odaberi
   „Windows funkcije”, uključi „Windows Hypervisor Platform” i restartuj PC.
   BIOS virtuelizacija takođe mora biti uključena. Ne isključuj sigurnosne
   funkcije Windowsa. Ako sistem traži administratora, koristi svoj Windows nalog.
5. Kada se Android pokrene, odaberi „Instaliraj BSL i NRN”.
6. BSL ili NRN otvaraš odgovarajućim dugmetom. Klik miša radi kao dodir,
   povlačenje kao prevlačenje, a tastatura unosi tekst u odabrano polje.
   Android se prikazuje u zasebnom prozoru. Uvećaj taj prozor preko Windowsa.
   Noria launcher ne ugrađuje ekran emulatora u svoj prozor.

ZA TVOJ RAČUNAR
Android 15 Google APIs x86_64, ekran 1920x1080, 160 DPI,
4096 MB RAM-a, dva procesorska jezgra. BSL i NRN dijele jedan Android sistem.
Ako je ekran crn ili grafika ne radi, zaustavi Android pa odaberi softverski
prikaz i ponovo pokreni. Prvo pokretanje može trajati nekoliko minuta.

APLIKACIJE
U folderu apks su BSL 1.0.0 release i NRN Mesh Pilot 1.3.0 debug,
napravljeni 31.10.2026. za ARM i x86_64. NRN sadrži komandni centar
i offline planer. Dugme „Instaliraj drugi APK” omogućava instalacije i
nadogradnje. Nadogradnja čuva podatke ako su paket i potpis kompatibilni.
Ne briši aplikaciju radi nadogradnje: brisanje uklanja njene lokalne podatke.
Kod greške UPDATE_INCOMPATIBLE potreban je isti potpis, a ne prisilno brisanje.

PODACI I PRIVATNOST
Android podaci ostaju u %LOCALAPPDATA%\NoriaDesktop.
Android alati se instaliraju u izdvojeni SDK; postojeći Android Studio se ne mijenja.
Launcher ne šalje telemetriju. Google Android komponente i instalirane aplikacije
imaju vlastite mrežne zahtjeve i uslove. Nakon pripreme internet je potreban
za online funkcije aplikacija. Za gašenje koristi „Zaustavi Android”. Zatvaranje
launchera ostavlja Android prozor otvoren. Ne pokreći više Noria launchera odjednom.

OGRANIČENJA PRVE VERZIJE
Ovo je brendirani Windows launcher postojećeg Android Emulatora, a ne novi
emulator razvijen od nule. Windows EXE, provjere komandne logike i otvaranje
interfejsa provjereni su u Windows CI okruženju. Pokretanje Androida na tvom
računaru i rad BSL/NRN u njemu zahtijevaju lokalni test.
Bluetooth, Wi-Fi Direct, Nearby Connections, GPS i LoRa nisu potvrđeni i
ne treba računati da emulator automatski koristi radio-hardver računara.
Široki ekran ne mijenja sam po sebi raspored NRN interfejsa. Nije dodato
automatsko ažuriranje EXE-a: novu verziju dobijaš zamjenom programskog foldera,
dok Android podaci ostaju u korisničkom profilu. EXE nije potpisan komercijalnim
Windows certifikatom; Windows može prikazati upozorenje izdavača.

LICENCE
Noria logo i boje preuzeti iz Noria-web repozitorija, commit
4480485a9876bb9e13c233aa53d01788fff89ec6.
Microsoft OpenJDK 21 se isporučuje uz originalni LICENSE/legal folder
(GPLv2 sa Classpath izuzetkom). Android alati i Google APIs slika preuzimaju
se direktno od Googlea po uslovima koje korisnik prihvati tokom pripreme.
Android / Google / Microsoft su oznake njihovih vlasnika.

IZVORI
https://developer.android.com/studio/command-line/sdkmanager
https://developer.android.com/studio/run/emulator-commandline
https://developer.android.com/studio/run/emulator-acceleration

