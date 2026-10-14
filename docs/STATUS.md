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

Superati 30 test unitari e 4 test di interfaccia, oltre alla validazione del contratto JSON sul servizio condiviso. IPA e firma esterna restano soggette ai controlli di consegna e dispositivo. Checklist dispositivo: `docs/PROVA-0.3.md` nel repository GitHub. Aggiornare tramite Signulous senza disinstallare, preservando identità e dati locali.

Build definitiva riuscita: 34 test iOS senza errori, contratto condiviso valido, archive riuscito. IPA scaricata e verificata per SHA-256, versione 0.3.0 build 5, bundle invariato, piattaforma iPhoneOS e arm64. Riepilogo reale: 25.324 byte in 2,372 s dal runner; non una misura dell'iPhone. SHA-256 IPA: `5d5676bcfe3d975e36c658e6dc22357e7bcc1ed0764e4b40511126358f6fc9e2`.
