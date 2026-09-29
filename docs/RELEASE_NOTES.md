# Proiectul de fizică al lui Vlad — v1.0.0

Joc offline, în română, pentru Mac Apple Silicon (M1 sau mai nou), macOS 13+.

## Instalare simplă

Descarcă fișierul **macOS-arm64.dmg** din Assets, deschide-l și trage aplicația în **Applications**. Există și varianta ZIP. Nu ai nevoie de Terminal, Xcode sau software muzical.

Aplicația este semnată local, ad-hoc, fără notarizare Apple. Dacă macOS o blochează la prima deschidere: **System Settings → Privacy & Security → Open Anyway**, apoi confirmă. Nu dezactiva protecțiile macOS. [Ghid ilustrat](https://github.com/atomicpig/proiectul-de-fizica-al-lui-vlad/blob/main/docs/INSTALARE.md).

## Inclus

- Șase misiuni, laborator, grafice, vectori de forță și export CSV.
- K1–K6 controlează direct și independent puterea celor șase motoare. Mișcările lente au pași de 0,5%; butoanele ± de pe ecran permit reglaje de 0,1%.
- Motoare mai ușor de dozat, creștere progresivă la salturi mari de putere, comenzi mici aplicate în următorul pas al simulării și cameră cu tranziții line.
- Profil automat pentru MPK mini IV, inclusiv potențiometrele relative de pe portul DAW. Asistent pentru asocieri personalizate.
- Toate comenzile au alternative de tastatură sau mouse. X / Pad 8 oprește motoarele.
- Aterizări mai permisive: 6 m/s vertical, 3 m/s lateral, maximum 15°, cu trenul coborât. Picioarele amortizează vizual contactul.
- Progres și profil MIDI salvate local; fără cont sau conexiune la internet.

## Verificare și limite

34 de teste automate trec: fizică, MIDI, integrarea comenzilor, consistența între frecvențe de afișare și parcurgerea tuturor misiunilor prin comenzile progresive. Toate cele opt potențiometre au fost capturate pe controllerul fizic. O aterizare la 5,10 m/s a fost verificată interactiv.

Nu a fost testată separat instalarea pe un al doilea Mac fără instrumente de dezvoltare sau rularea pe macOS 13. Nu toate combinațiile fizice de clape, paduri și rotițe au fost verificate exhaustiv. Mac-urile administrate pot interzice aplicații nenotarizate. Modelul fizic este educativ și simplificat. [Detalii de verificare](https://github.com/atomicpig/proiectul-de-fizica-al-lui-vlad/blob/main/docs/VERIFICARE.md).

Licență MIT. Sumele de control ale pachetelor sunt în `SHA256SUMS.txt`.
