# Life OS per iPhone

App SwiftUI integrata: Dashboard, Attività, Calendario e Finanza. Stesso bundle ID `com.nas.lifeos.probe` per aggiornare l’installazione precedente. Versione 0.3.1, build 8.

## Dati condivisi

Il sito `lifeos.a-zeroual-it.workers.dev` e il gateway app `lifeos-native-test.a-zeroual-it.workers.dev` puntano entrambi al D1 principale `liquidita-4-prova`. Il nome storico del gateway non indica più una copia attiva. Il sito mantiene il codice 11.63 e Cloudflare Access; l’app usa il gateway protetto dalla password dedicata. La vecchia copia e il backup prima dell’unificazione restano archivi separati.

Le modifiche della copia sono state confrontate e riconciliate con controlli sulle righe e backup. Non distribuire nuovamente il vecchio workflow che creava il server di prova: è stato archiviato. Credenziali esclusivamente nei secret GitHub Actions; mai nell’IPA o nei sorgenti pubblici.

## Sincronizzazione

- Un aggiornamento normale legge `getLifeData` e `getFinanceOverview`, una volta ciascuno. Il piano Extra arriva già nel riepilogo finanziario.
- Una modifica alle attività aggiorna soltanto Life OS; una modifica finanziaria aggiorna la finanza. I grafici e l’analisi completa si caricano separatamente quando si apre Finanza.
- Le nuove spese e gli Extra vengono salvati prima dell’invio e mantengono lo stesso UUID. La conferma è persistita prima del successivo aggiornamento; un riavvio non causa un nuovo addebito.
- Le letture interrotte da timeout o errore transitorio hanno un solo nuovo tentativo. Le scritture non hanno retry automatico alla cieca.
- Primo piano: controllo automatico circa ogni 30 secondi, oltre a Sincronizza nelle Impostazioni e nel menu contestuale dell’ingranaggio. Nessuna sincronizzazione continua in background o push.
- Consultazione offline dei dati memorizzati. Coda persistente per nuove spese ed Extra; le altre modifiche richiedono connessione.
- Accesso nativo con cookie nel Portachiavi. La password e il cookie non entrano nei backup JSON.

## Interfaccia e build

Componenti Apple con SDK recente, barra inferiore sempre espansa, titoli fissi e schede compatte. Palette originale dei turni adattata ai due temi, settimana in Dashboard, calendario eager con etichette VoiceOver e comandi sopra la barra inferiore. La ricerca è nel contenuto della lista; nessun pull-to-refresh nelle quattro schede principali. Compatibilità minima iOS 17; alcune presentazioni dipendono dalla versione iOS.

`python3 scripts/package.py` prepara il pacchetto e il workflow. GitHub Actions seleziona Xcode 26 o successivo già installato, esegue test unitari e UI su iPhone 17 Pro e iPhone SE di terza generazione, esporta schermate della sola demo e crea una IPA per iPhone senza firma. Signulous deve firmarla come aggiornamento della stessa app.

Le schermate dei test usano una cartella temporanea e dati simulati: nessun dato personale viene pubblicato negli artefatti. Il Worker, i dump D1 e le credenziali non fanno parte del pacchetto nativo.

Stato ed evidenze correnti: `STATUS.md`. Procedura per il dispositivo: `PROVA-0.3.1.md`. HealthKit resta escluso.
