# Revisione grafica 0.3.1 build 8 — 14 ottobre 2026

Richiesta: riferimento visivo di Nas, correzione del tremolio e del lag durante l’overscroll, aggiunta eventi raggiungibile, palette dei turni originale moderatamente più satura e una sola IPA finale.

Implementati: tab bar sempre espansa, titoli inline e toolbar stabile; ricerca attività nel contenuto; nessun pull-to-refresh nelle quattro sezioni. Calendario eager separato dalla List, griglia e menu divisi in componenti, margine inferiore per liberare i comandi. Dashboard con settimana e schede compatte, righe allineate a sinistra, tipografia di sistema; Finanza più compatta con andamento giornaliero su asse numerico, importi raggruppati e budget negativo verificabile. Testo grande e temi ispezionati sui due formati.

Build di consegna: run https://github.com/azeroualit-cloud/LifeOS/actions/runs/38567922673 . Build riuscita: 31 test unitari e 12 esecuzioni UI sui due simulatori, tutti senza errori. Contratto API condiviso e archive iPhone riusciti. IPA scaricata e verificata: versione 0.3.1 build 8, bundle com.nas.lifeos.probe, piattaforma iPhoneOS e arm64. SHA-256: 8fef697f684ee25082c433fdbc980ac290b7aa75fdf5d058df88590a7ac161c7. Artefatto 11897507875, disponibile fino al 21 ottobre. La build 6 aveva già superato 31 test unitari, 9 UI principali e 3 UI compatti; le build 7/8 correggono soltanto le etichette del grafico. Nessuna installazione intermedia richiesta all’utente.

Scorrimento e comandi verificati nei simulatori; fluidità e vibrazioni sul telefono fisico restano da confermare. Prova mirata: docs/PROVA-0.3.1.md nel repository GitHub. La revisione non distribuisce modifiche al Worker e non muta dati reali nei test UI.

---

# Life OS nativa — 14 ottobre 2026

La richiesta corrente autorizza un'unica fonte dati per app e sito, sincronizzazione più rapida e revisione grafica completa. Sostituisce la precedente limitazione alla sola copia di test. Nessun nuovo servizio a pagamento.

## Dati e sincronizzazione

Sito e gateway nativo usano ora lo stesso D1 `liquidita-4-prova`. Il nome storico dell'endpoint nativo contiene ancora `native-test`, ma le operazioni interessano i dati reali. Vecchia copia e backup precedente alla riconciliazione sono archivi, non fonti attive. Il codice del Worker originale del sito e il suo accesso Cloudflare sono rimasti invariati.

La riconciliazione ha conservato le modifiche del sito e trasferito sette record, applicato una cancellazione verificata e ignorato una differenza di solo timestamp. Controllati vincoli, precondizioni e idempotenza. Unificazione verificata: https://github.com/azeroualit-cloud/LifeOS/actions/runs/38544717558

Il refresh ordinario passa da sei letture a due concorrenti: dati Life e panoramica finanziaria. Analisi completa caricata separatamente quando serve. Dopo una scrittura si aggiorna soltanto l'ambito interessato, senza refresh preliminare e duplicato. Polling ogni 30 secondi mentre l'app è attiva, aggiornamento al rientro e manuale. Sul sito occorre aggiornare la pagina: nessun push in tempo reale.

Letture con un solo tentativo aggiuntivo per errori transitori; scritture non idempotenti senza reinvio automatico. Cache disponibile durante attesa o errore. Le nuove spese e operazioni Extra supportate conservano UUID e stato confermato su disco prima dell'invio: un refresh fallito non autorizza un doppio addebito. Modifiche ad attività, eventi e movimenti esistenti richiedono rete. Nessuna risoluzione automatica di modifiche contemporanee allo stesso elemento.

Accesso nativo con password esistente; sessione nel Portachiavi, esclusa dal backup JSON. I timeout sono gestiti con recupero e cache; l'assenza assoluta di futuri timeout non è dimostrabile. Tempi sul telefono e conservazione della sessione dopo firma Signulous richiedono verifica reale.

## App integrata e grafica

Una sola IPA, stesso bundle ID `com.nas.lifeos.probe`, versione 0.3.0 build 5. Quattro sezioni: Dashboard, Attività, Calendario e Finanza con Movimenti ed Extra. Gestione turni, routine, categorie, eventi e ricorrenze, budget, grafici, ricorrenti, quote e collegamenti finanziari. HealthKit escluso.

Compilazione con SDK Apple recente, componenti SwiftUI, barra Liquid Glass quando disponibile, schede, palette pervinca, temi di sistema, SF Symbols e testo dinamico. Revisionati screenshot reali del simulatore nei due temi, tastiera e calendario a sei settimane. Corretti comandi sovrapposti, gestione categorie nascosta dalla barra e leggibilità delle cifre del calendario.

Demo isolata, archivio reale conservato separatamente; migrazione della coda SQLite precedente. Importazione JSON con picker UIKit, lettura coordinata e alternativa Incolla JSON: il blocco segnalato sul dispositivo resta da verificare lì. Non usare l'importazione per sostituire il database condiviso.

## Verifica e consegna

La versione precedente 0.2.1 è stata installata e l'utente ha confermato accesso ai dati e operazioni. I test automatici comprendono modelli, coda persistente, retry, scopi del refresh, autenticazione e interfaccia. La build definitiva e il controllo del contratto API reale sono nel run: https://github.com/azeroualit-cloud/LifeOS/actions/runs/38548668497

Esito definitivo e IPA vanno verificati nel run prima di dichiarare la consegna completata. Checklist dispositivo: `docs/PROVA-0.3.md` nel repository GitHub. Aggiornare tramite Signulous senza disinstallare, preservando identità e dati locali.

Consegna verificata: run 38548668497 riuscito, 34 test e contratto condiviso superati, IPA 0.3.0 build 5 arm64 scaricata e hash verificato. Artefatto 11886162086. Documentazione GitHub aggiornata nel commit 3f9e4e5d2cce05d91b7ece1f974e22651a71415f.
