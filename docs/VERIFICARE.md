# Verificare — Lunar Lander · Vlad v2.0.0

## Teste automate

`bash scripts/test.sh`: **34 teste, 0 eșecuri**, 30 septembrie 2026, Xcode complet pe Apple Silicon.

- Inerție orizontală și cădere liberă; forță/masă/accelerație; consum și epuizare a combustibilului.
- Comenzi fine și putere maximă aplicate la următorul pas fizic, fără rampă de pornire; frânare graduală.
- Impulsuri finite, inclusiv repetarea note-on fără note-off; oprirea tuturor motoarelor și amortizării fără anularea inerției.
- Coliziuni rapide detectate prin eșantionare pe traiectorie, lovirea carenei și limitele contactului.
- Contact ferm cu suspensie pe fiecare pistă. Toate pistele ×1, ×3 și ×5 din sectoarele 1 și 12 sunt atinse de un pilot automat **doar în teste**, prin cele șase intrări normale și răspunsul real al motoarelor. Jocul nu conține acest pilot automat.
- Parsare MIDI, running status, clape simultane, eliberări independente, moduri relative, salvare și migrare de profil.
- Mesajele CC ale celor șase encodere MPK mini IV, precizie 0,1%, Mod independent de dials/paduri, pickup zero pentru encodere absolute după pauză.
- Costul unei vieți la accident, punctaj o singură dată, realimentare și progresie.
- Traiectorii identice la 30/60/75/120/144 cadre pe secundă; simularea nu invalidează întregul model SwiftUI la fiecare pas.

## Verificare interactivă

În aplicația nativă au fost verificate lansarea, puterea continuă de 11% prin glisor, impulsul lateral, frânarea Pad 7 prin tasta 7, pauza cu eliberarea motoarelor și confirmarea reluării cu scăderea unei vieți.

Aterizare efectivă pe ×1 la **2,40 m/s**, cu 206 kg combustibil și **756 puncte**. Suspensia a stabilizat nava, iar trecerea în sectorul 2 a păstrat scorul și a realimentat la 250 kg. Această aterizare a fost verificată înaintea înlocuirii randării; fizica de contact este aceeași.

AKAI este conectat și detectat. Profilul folosește portul DAW pentru encodere și portul MIDI pentru clape/paduri. Reproducerea mesajelor în teste nu înlocuiește verificarea fizică a tuturor comenzilor de către utilizator.

## Fluiditate și stabilitate

Cockpitul activ folosește AppKit cu poziții fixe și CoreGraphics/CoreText. Valorile numerice nu declanșează recalcularea layoutului SwiftUI. Ceasul fizic rulează și în modul de urmărire a mouse-ului. Audio este pregătit și controlat pe un fir separat; comenzile motoarelor nu așteaptă pornirea sunetului.

- Test automat: zborul avansează în `RunLoop.Mode.eventTracking`, inclusiv în timp ce sunt schimbate modurile.
- Test automat: 600 de cadre desenate în contexte bitmap, cu puteri, impulsuri și ecrane diferite, fără suprafață Metal.
- Benchmark în aplicația release: 20 s cu schimbări de mod și impulsuri la intervale repetate. Simularea finală: **19,92 s**. După pornire, interval mediu între redesenări **8,33 ms**, percentila 95 aproximativ **9,8–11,2 ms**; costul desenării sub **1,1 ms** la percentila 95. Un cadru de pornire a durat 164 ms în timpul rulării simultane a testelor. Acestea sunt măsurători locale, nu o garanție pentru fiecare Mac sau pentru rata de afișare a monitorului.
- Clickurile reale pe precizie și amortizare au fost verificate în timpul zborului. Utilizatorul a confirmat: „Smooth and responsive now”.

Pentru reproducerea benchmarkului, după compilare:

```sh
"dist/Lunar Lander Vlad.app/Contents/MacOS/VladLander" --performance-log --render-benchmark
```

Acest mod de diagnostic schimbă automat controalele și închide aplicația după 20 s. Nu îl folosi în timpul unui zbor pe care dorești să-l păstrezi.

## Distribuție

Build release arm64 pentru macOS 13+, semnare ad-hoc verificată cu `codesign`. Fără biblioteci externe, server sau cont. DMG-ul include aplicația, scurtătura Applications și ghidul HTML autonom; ZIP-ul include aplicația. SHA-256 este publicat alături de arhive. Am verificat semnătura aplicațiilor extrase din ambele arhive, checksum-ul DMG și SHA-256 pentru ZIP/DMG. Copia extrasă din ZIP pornește prin LaunchServices și rămâne activă. Verificarea automatizată a clicului din Finder s-a blocat; nu este raportată ca reușită.

Nu există notarizare Apple. Prima deschidere a unei copii descărcate poate necesita excepția Open Anyway pentru acea aplicație. Nu s-a verificat instalarea pe un Mac separat, curat, fără instrumente de dezvoltare, sau fiecare versiune macOS suportată.
