# Lunar Lander · Vlad — v2.0.0

Înlocuiește complet jocul anterior cu un Lunar Lander nativ, offline, în română. Adresa repository-ului și pagina ultimei versiuni rămân aceleași.

## Descarcă și joacă

- **Mac Apple Silicon, macOS 13+**. Alege DMG-ul, deschide-l și trage Lunar Lander Vlad în Applications.
- ZIP-ul conține aceeași aplicație, fără instalator sau dependențe.
- [Instalare ilustrată](https://github.com/atomicpig/proiectul-de-fizica-al-lui-vlad/blob/main/docs/INSTALARE.md).

## Jocul nou

- Relief lunar original, trei piste ×1 / ×3 / ×5, sectoare progresive, trei vieți și record local.
- K1–K6 dozează independent motoarele. K8 reglează precizia până la 0,1% pe pas lent.
- Pad 1–6: impulsuri la 160% timp de 0,24 s. Pad 7: frânare de 0,55 s. Pad 8: toate motoarele la zero.
- Inerție și gravitație lunară, combustibil consumat de fiecare propulsor, suspensie pe ambele picioare. Contact ferm acceptat până la 6 m/s vertical și 3 m/s lateral.
- Cameră automată, zoom K7, hartă, instrumente, sunete și alternative complete prin mouse și tastatură.
- Import automat al asocierilor AKAI din jocul anterior; padurile primesc noile funcții. Scorul nou este separat.

## Verificări și limite

32 de teste automate trec, inclusiv aterizări pe toate cele trei piste prin comenzi normale, profiluri MIDI, impulsuri finite, oprire de urgență și traiectorii identice la frecvențe diferite de randare. În aplicație a fost verificată o aterizare la 2,4 m/s, acordarea scorului și trecerea în sectorul următor.

Semnătura este **ad-hoc, fără notarizare Apple**. La prima deschidere poate fi necesar **System Settings → Privacy & Security → Open Anyway**, apoi **Open**. Vezi [instrucțiunile Apple](https://support.apple.com/en-au/102445). Nu este nevoie de Terminal sau de dezactivarea protecțiilor.

Controllerul conectat este detectat, iar mesajele specifice MPK mini IV sunt acoperite de teste. Noua funcție a fiecărui pad nu a fost apăsată fizic de un operator în această verificare; asocierea poate fi verificată sau schimbată din ecranul AKAI. Alte modele/preseturi pot necesita reasociere. Compatibilitatea a fost verificată local pe Apple Silicon; nu a fost testat separat un Mac curat cu fiecare versiune macOS suportată. Detalii în [raportul de verificare](https://github.com/atomicpig/proiectul-de-fizica-al-lui-vlad/blob/main/docs/VERIFICARE.md).
