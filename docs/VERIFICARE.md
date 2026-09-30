# Verificare — Lunar Lander · Vlad v2.0.0

## Teste automate

`bash scripts/test.sh`: **32 teste, 0 eșecuri**, 29 septembrie 2026, Xcode complet pe Apple Silicon.

- Inerție orizontală și cădere liberă; forță/masă/accelerație; consum și epuizare a combustibilului.
- Comenzi fine fără prag inițial și creștere limitată a puterii mari; frânare graduală.
- Impulsuri finite, inclusiv repetarea note-on fără note-off; oprirea tuturor motoarelor și amortizării fără anularea inerției.
- Coliziuni rapide detectate prin eșantionare pe traiectorie, lovirea carenei și limitele contactului.
- Contact ferm cu suspensie pe fiecare pistă. Toate pistele ×1, ×3 și ×5 din sectoarele 1 și 12 sunt atinse de un pilot automat **doar în teste**, prin cele șase intrări normale și răspunsul real al motoarelor. Jocul nu conține acest pilot automat.
- Parsare MIDI, running status, clape simultane, eliberări independente, moduri relative, salvare și migrare de profil.
- Mesajele CC ale celor șase encodere MPK mini IV, precizie 0,1%, Mod independent de dials/paduri, pickup zero pentru encodere absolute după pauză.
- Costul unei vieți la accident, punctaj o singură dată, realimentare și progresie.
- Traiectorii identice la 30/60/75/120/144 cadre pe secundă; simularea nu invalidează întregul model SwiftUI la fiecare pas.

## Verificare interactivă

În aplicația nativă au fost verificate lansarea, puterea continuă de 11% prin glisor, impulsul lateral, frânarea Pad 7 prin tasta 7, pauza cu eliberarea motoarelor și confirmarea reluării cu scăderea unei vieți.

Aterizare efectivă pe ×1 la **2,40 m/s**, cu 206 kg combustibil și **756 puncte**. Suspensia a stabilizat nava, iar trecerea în sectorul 2 a păstrat scorul și a realimentat la 250 kg. Captura din `images/aterizare.png` provine din această sesiune.

AKAI este conectat și detectat. Profilul folosește portul DAW pentru encodere și portul MIDI pentru clape/paduri. Reproducerea mesajelor în teste nu înlocuiește verificarea fizică a tuturor comenzilor de către utilizator.

Randarea folosește noduri persistente, cameră netezită și simulare separată la 120 Hz. Automatizarea capturilor produce uneori blocaje SpriteKit („no drawables”); aceste intervale nu susțin o afirmație despre FPS-ul normal. Nu publicăm un FPS garantat.

## Distribuție

Build release arm64 pentru macOS 13+, semnare ad-hoc verificată cu `codesign`. Fără biblioteci externe, server sau cont. DMG-ul include aplicația, scurtătura Applications și ghidul HTML autonom; ZIP-ul include aplicația. SHA-256 este publicat alături de arhive. Am verificat semnătura aplicațiilor extrase din ambele arhive, checksum-ul DMG și SHA-256 pentru ZIP/DMG. Copia extrasă din ZIP pornește prin LaunchServices și rămâne activă. Verificarea automatizată a clicului din Finder s-a blocat; nu este raportată ca reușită.

Nu există notarizare Apple. Prima deschidere a unei copii descărcate poate necesita excepția Open Anyway pentru acea aplicație. Nu s-a verificat instalarea pe un Mac separat, curat, fără instrumente de dezvoltare, sau fiecare versiune macOS suportată.
