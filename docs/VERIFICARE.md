# Verificarea versiunii 1.0.0

## Teste automate

`bash scripts/test.sh`: **34 de teste XCTest, zero erori** pe Mac Apple Silicon.

- Inerție, cădere liberă comparată cu soluția analitică și independența accelerației gravitaționale față de masă.
- Relația forță–masă–accelerație, consumul combustibilului, ultimul impuls cu rezervor aproape gol și motoare opuse.
- Frânare graduală, stabilizare prin cuplu, rezistența aerului și conservarea energiei în cazul fără propulsie/rezistență.
- Pragurile de aterizare (6 m/s vertical, 3 m/s lateral, 15°), trenul, platforma și detectarea contactului la viteze mari. Contactul pe lateral sau cu trenul retras rămâne o prăbușire.
- Toate cele șase misiuni terminate printr-un pilot automat exclusiv de test, care folosește doar comenzile normale de propulsie. Acesta nu este inclus ca funcție de joc.
- Control analogic independent al celor șase motoare, inclusiv valori fracționare.
- Note MIDI fragmentate, running status, eliberări, mesaje simultane, canale/porturi diferite, pitch, SysEx ignorat și potențiometre relative.
- Eliberarea independentă a comenzilor din surse diferite, resetarea lor la pauză/deconectare, salvarea și migrarea profilului.
- Profil automat care păstrează asocierile manuale și redarea mesajelor reale K1–K8 capturate pe portul DAW.
- Integrare MIDI → puterea motoarelor → fizica navei fără clape ținute; independența celor șase motoare, oprirea la pauză, oprirea de urgență și resetarea experimentelor din laborator.
- Răspuns în primul pas la reglajele mici, creștere graduală la comenzi mari, potențiometre independente de Mod, temperarea accelerației encoderelor și aceeași traiectorie la 30/60/75/120/144 cadre pe secundă.
- Cele șase misiuni sunt parcurse și prin GameModel, folosind puterile independente cu noua creștere progresivă. Actualizarea telemetriei nu mai invalidează întregul panou de control la fiecare cadru.
- Export CSV cu unități SI, număr stabil de coloane și separator zecimal independent de limba sistemului.

## Verificări locale

- Aplicația arm64 a fost compilată în modul Release, semnată ad-hoc și deschisă ca aplicație macOS.
- Executabilul declară macOS 13.0 ca versiune minimă și folosește numai biblioteci de sistem.
- Interfața a fost inspectată prin captură și arbore de accesibilitate: scenă de zbor, telemetrie, șase cursoare de motor, comenzi și indicator AKAI.
- MPK mini IV a fost detectat prin CoreMIDI: porturile MIDI, DAW și Software.
- Utilizatorul a rotit fizic toate cele opt potențiometre. Captura a confirmat canalul 1, CC 24–31, pe **MPK mini IV DAW Port**, cu valori relative two's complement (de exemplu 1 pentru creștere și 127 pentru scădere). Profilul automat și testul de regresie folosesc aceste mesaje.
- Profilul salvat al padurilor a fost păstrat în timpul actualizării schemei de control.
- Probă interactivă în aplicație, cu mouse și tastatură: motorul invers la 15%, oprirea motoarelor, continuare prin inerție și aterizare pe picioare la 5,10 m/s. Utilizatorul a confirmat că noul răspuns al zborului este mai bun.
- Profilarea locală a identificat actualizări SwiftUI costisitoare. Instrumentele de bord au fost separate de comenzi, etichetele folosesc AppKit, săgețile reutilizează geometria, iar scena poate desena până la 120 cadre/s în funcție de ecran. Acest plafon nu este o garanție de performanță pe orice Mac.
- Pachetele ZIP și DMG includ aplicația precompilată; DMG-ul include și ghidul HTML offline. Sunt generate sume SHA-256.

## Limite declarate

- Nu a fost disponibil un al doilea Mac fără instrumente de dezvoltare pentru un test complet de instalare.
- Versiunea macOS minimă este verificată în metadatele executabilului; rularea pe macOS 13 nu a fost testată separat.
- Aplicația nu este notarizată Apple. Fluxul Open Anyway este documentat conform instrucțiunilor Apple; politicile Mac-urilor administrate pot bloca acest flux.
- Capturarea celor opt potențiometre nu echivalează cu verificarea fizică exhaustivă a fiecărei clape, rotițe, combinații de butoane sau versiuni de firmware.
- Modelul educativ folosește sol plan, corp rigid simplificat și gravitație uniformă locală. Nu simulează orbite sau aerodinamică completă.
