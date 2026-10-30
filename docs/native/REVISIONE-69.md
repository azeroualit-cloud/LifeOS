# Life OS 0.10.8 build 69 — Dashboard

## Intervento

La scheda Peso e calorie è un’anteprima: titolo, ultimo peso in kg, TDEE in kcal/giorno e mini grafico storico senza assi, date, legenda, previsione o testo esplicativo. Le barre storiche sono grigio di sistema e quella di oggi usa l’accento; gli angoli inferiori restano squadrati. Il tap apre il dettaglio esistente con grafici, stime, simulazioni e impostazioni. Il riepilogo VoiceOver identifica esplicitamente i due valori e i dati demo. In modalità testo accessibile il contenuto si dispone verticalmente. Il bordo temporale comprende tutto il giorno corrente, evitando di tagliare la sua barra.

Gli impegni mantengono l’orizzonte settimanale, raggruppati per giorno con un’intestazione unica. Stessa primitiva NativeChecklistRow e stesso NativeCheckmark già presenti nelle liste: cerchio per completare, titolo per aprire l’editor, orario sotto il titolo quando disponibile. Nessuna card per gli impegni. Spaziature esistenti: 8 punti sotto la data, 4 punti sopra e sotto le righe, 24 punti fra gruppi; divisori allineati ai titoli.

Il completamento usa setEventOccurrence con identificatore e giorno dell’occorrenza. Il salvataggio locale è persistente e la sincronizzazione usa la coda esistente. L’evento completato scompare dai prossimi impegni; rimane recuperabile dal Calendario. Le altre occorrenze della stessa serie restano aperte. Nessuna modifica a API, database o Cloudflare per questa revisione.

## Verifiche

Parser Swift sui file modificati e controllo design system superati. Il parser Tree-sitter ha un limite preesistente su TasksScreen.swift, invariato e già presente nel commit di partenza; la compilazione Apple verifica il sorgente effettivo.

Aggiunto test nativo di completamento offline, riapertura archivio, isolamento dell’occorrenza e riapertura dello stato. Aggiunta prova UI del raggruppamento di 12 impegni in 5 giorni, margine, bersagli tattili, completamento senza aprire l’editor e apertura separata di un altro impegno. Verifiche della scheda Salute nei due temi e con testo accessibile, su simulatore principale e compatto. Esito finale: 192 unitari e 25 esecuzioni UI passati (2 mirate, 6 regressioni principali, 17 compatte; 19 metodi UI distinti). [Run Apple](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41079215196). Il test della lista completa verifica la riga come pulsante accessibile, con titolo esatto, bersaglio minimo e apertura dell’editor. Le catture comprendono l’intera anteprima Salute nei due temi e con testo accessibile.

Il codice dell’app è identico alla revisione `56547f9cd89e744688e8f5f6ad9d9e6d34d38de8`, già verificata nelle cinque prove UI iniziali; il commit finale `6d3fcb9437e6da92072498a0ec76bb720870c32d` aggiorna il test alla semantica delle righe condivise e l’inquadratura delle catture. La suite finale verifica nuovamente i flussi interessati e comprende tutte le prove compatte previste.

## IPA

[Scarica LifeOS-69.ipa](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.8-build69/LifeOS-69.ipa). Versione 0.10.8 build 69. File pubblico scaricato e verificato: checksum del rilascio, CRC ZIP, identificatore `com.nas.lifeos.probe`, widget `com.nas.lifeos.probe.quickactions`, piattaforma iPhoneOS, Mach-O arm64 di app e widget e schema URL lifeos. Dimensione 1.399.229 byte. SHA-256: `27e2a7fce0f37db66402bf9cde8af1f7f158961c981ed1479456cb95b278812d`.

La firma Signulous e l’uso su telefono fisico restano da verificare. Aggiornare senza disinstallare l’app per conservare archivio e connessione.
