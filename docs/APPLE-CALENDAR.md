# Turni Life OS → Calendario Apple

Implementazione del 23 ottobre 2026, con codice nuovo separato dal template backend. Webapp e sorgenti dell’app iPhone 0.9.0 build 52 preparati; **backend non distribuito, IPA 52 non compilata, abbonamento Apple non ancora attivato**. La build 51 resta l’ultima IPA verificata.

## Uso previsto

1. Nel Calendario Life OS scegli il mese e usa **Dipingi turni**.
2. Premi **Pubblica turni del mese**. Solo il mese visualizzato passa dalle bozze al calendario pubblicato. Un mese vuoto cancella i turni precedentemente pubblicati per quel mese.
3. Alla prima pubblicazione usa **Collega Calendario Apple**. Se l’apertura automatica non è disponibile, nella webapp copia il link riservato e inseriscilo in Calendario Apple → Calendari → Aggiungi calendario → Aggiungi calendario in abbonamento. Scegli iCloud per ritrovarlo sugli altri dispositivi.
4. Le correzioni e le cancellazioni si fanno in Life OS, poi si ripubblica il mese. Apple legge il calendario periodicamente: la conferma di Life OS indica che il server ha pubblicato, non che Apple abbia già aggiornato.

Collegare **una sola volta**, dalla webapp oppure dall’app iPhone: entrambe usano lo stesso D1 e lo stesso calendario. Gli altri appuntamenti si gestiscono direttamente in Calendario Apple, le attività in Promemoria. Il calendario in abbonamento è in sola lettura.

Il calendario Life OS ora mostra soltanto i turni, senza creazione di eventi, e si apre dalla Dashboard. La navigazione contiene solo Dashboard e Finanza. Le pagine Attività e i controlli delle abitudini sono stati rimossi; vecchi dati conservati nel database e nei backup. Questa modifica **non** trasferisce automaticamente i contenuti storici ad Apple. Dashboard e misurazioni manuali peso/calorie: [DASHBOARD-SALUTE.md](DASHBOARD-SALUTE.md). HealthKit non è integrato.

## Contratto e dati

- Orari esistenti: mattina 06–14, pomeriggio 14–22, notte 22–06 del giorno successivo; ferie e riposo sono giornate intere. Fuso Europe/Rome, con regole ora legale/solare nel file ICS. Non sono stati aggiunti orari personalizzati.
- `os_shifts` rimane la preparazione. Tre tabelle additive conservano collegamento, snapshot pubblicati e pubblicazioni mensili: `os_shift_calendar`, `os_published_shifts`, `os_shift_publications`.
- Pubblicazione D1 in un unico batch transazionale. UID per calendario/giorno stabile, SEQUENCE incrementata solo per modifiche, cancellazioni e ripristini. Un nuovo tentativo dopo una risposta persa non duplica i turni.
- Le cancellazioni mantengono l’UID e diventano `STATUS:CANCELLED`. La rimozione visiva va ancora confermata su Apple Calendar.
- API POST autenticate, con controllo Origin esistente: `getShiftCalendar`, `publishShiftCalendar`, `rotateShiftCalendarLink`, argomenti `[{"month":"2026-10"}]`. `getLifeData` include `shiftCalendar` per il mese richiesto.
- Solo `GET/HEAD /calendar/turni/<token-casuale-di-64-caratteri-esadecimali>.ics` passa prima dell’autenticazione applicativa. Non legge finanza, eventi, attività o bozze, non esegue seed/migrazioni e non accetta scritture. Risposte senza cache e senza indicizzazione.
- Il link permette a chi lo possiede di leggere i turni. Rigenerarlo invalida il precedente mantenendo gli UID, ma richiede un nuovo abbonamento in Apple. Non inserire link reali in log, screenshot o ticket.
- L’app nativa non pubblica dalla demo, non accoda queste scritture offline e non ritenta automaticamente le pubblicazioni. Un errore lascia disponibile un nuovo tentativo esplicito. Nessun accesso a EventKit o HealthKit richiesto.

## Attivazione ancora necessaria

Il runtime non ha credenziali Cloudflare. Nessun dato reale o configurazione live è stato modificato.

La connessione GitHub riconosce il repository pubblico `azeroualit-cloud/LifeOS` e il suo ramo `main` coincide con la baseline locale. Il 23 ottobre il tentativo di caricare i file per avviare la CI Apple è stato respinto dalla revisione automatica perché manca un’autorizzazione esplicita dell’utente all’esportazione del codice e dell’archivio verso il repository pubblico. Nessun blob/ramo/commit è stato creato da quel tentativo. L’utente ha successivamente confermato il caricamento sul nuovo ramo GitHub; autorizzazione acquisita. La CI Apple viene avviata con questa revisione. La successiva revisione automatica ha richiesto un consenso specifico per ripubblicare l’intero Worker con i dati incorporati. È stata quindi adottata un’alternativa che non esporta quel contenuto: template originale invariato, sole nuove funzioni in `web/backend-extensions.mjs`, applicazione delle modifiche con `web/backend_update.py`, risultato completo in `web/dist/worker.mjs` ignorato da Git. La pubblicazione del codice aggiunto non richiede di caricare una nuova copia dello storico finanziario.

1. Recuperare il sorgente live di entrambi i Worker e confrontarlo con la baseline locale. Integrare eventuali aggiornamenti successivi; non sostituire alla cieca il gateway nativo con quello web.
2. Distribuire le funzioni calendario e le API su `lifeos` e sul gateway nativo `lifeos-native-test`, conservando DB condiviso, segreti e modalità di autenticazione di ciascuno. La webapp e il backend si assemblano con `npm run build`; il risultato da valutare per il deploy è `web/dist/worker.mjs`, non il template originale. Non creare copie del database, non importare seed e non ripristinare marcatori.
3. Per il dominio web protetto da Cloudflare Access, consentire l’accesso senza login **soltanto a `/calendar/turni/*`** tramite una regola Access dedicata e più specifica. Il Worker controlla comunque il token esatto. Conservare la protezione di `/`, `/api/*`, `/setup` e di ogni altra rotta. Il gateway con sola password applicativa serve il feed prima del controllo della password.
4. Inizializzare lo schema dal pannello autenticato, quindi pubblicare un mese approvato dall’utente. Verificare da una sessione senza cookie: link corretto restituisce `text/calendar`, token errato restituisce 404, API restano protette. Verificare anche errori temporanei e rigenerazione del link senza scrivere token nei log.
5. Collegare l’abbonamento su Apple e provare: aggiunta, cambio turno, eliminazione, ripubblicazione senza duplicati, isolamento tra mesi e notte durante il cambio d’ora. Misurare il ritardo di aggiornamento reale, senza promettere una frequenza.
6. Per l’app iPhone eseguire la CI Apple aggiornata, con unitari e UI su dispositivi standard e compatti e archivio Release, prima di consegnare una nuova IPA. Aggiornare tramite Signulous senza disinstallare.

## Verifiche locali

- `web`: `npm run build`; `npm test` con Node 24+ e Chromium. SQLite locale esegue il vero SQL: autenticazione, bozze isolate, revisione stabile, cancellazione/ripristino, mesi separati, retry, rotazione del link, rollback e feed senza effetti di seed.
- Playwright: viste finanziarie e calendario a 320/375/1280 px, errori JS assenti, nessun overflow; pubblicazione fallita/nuovo tentativo, attesa coda del pennello, blocco di pubblicazione dopo un salvataggio fallito, collegamento webcal e Riduci movimento.
- Anteprima web reale con dati simulati: `web/previews/turni-apple.png`.
- Swift: parser su tutti i sorgenti e test; controllo design system; 60 test Foundation su Linux superati, inclusi 2 sul collegamento Apple. Questi non compilano SwiftUI né eseguono i test `NativeStoreTests` o UI.
- Aggiunti test Apple per chiamata di pubblicazione senza aggiornamento finanziario, timeout senza retry automatico, nuovo tentativo, blocco demo e pannello raggiungibile dopo scorrimento. Sono preparati, **non eseguiti**. CI aggiornata con i nuovi nomi dei test compatti.

Diff nativo leggibile: `native/APPLE-TURNI-52.diff`. Pacchetto sorgenti: `../lifeos-native.zip`.
