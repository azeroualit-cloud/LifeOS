# Revisione 0.9.0 build 52 — 25 ottobre 2026

## Implementazione

- Accento blu semantico condiviso, differenziato per tema; superfici scure opache e uniformi. Testo completato attenuato senza barratura; nessun fondo colorato per stato della riga.
- Attività divise in Attivo e In attesa; completate visibili in coda alla loro sezione, riapribili. Compatibilità con vecchi record done senza section_status: appartengono ad Attivo. Per i record già completati non è possibile ricostruire una precedente sezione non registrata dal vecchio server.
- Espansione animata sotto la riga con titolo e note modificabili, salvataggio esplicito, data/dettagli, cambio sezione ed eliminazione. TaskEditor condiviso per opzioni complete; errori e modifiche non salvate restano visibili.
- Calendario nativo: mesi consecutivi in LazyVStack, ancoraggio per mese e intervallo esteso alle estremità; controlli persistenti, scroll nativo, selezione sul numero e dettagli sotto il mese selezionato. Giorni dei mesi adiacenti lasciati vuoti per evitare duplicati interattivi.
- Dati mensili richiesti soltanto per mesi non in cache, dopo 180 ms; richieste cancellate durante navigazioni successive, errori recuperabili con Riprova e mesi senza dati esplicitamente indicati. Nessuna scrittura generata dallo scroll.
- Pennello a tocchi, distinto dal gesto di scroll; apertura animata, selezione e cambio badge, Annulla dell'ultima assegnazione confermata. Durante una scrittura i tocchi di pittura restano disabilitati; nessuna nuova modalità di trascinamento introdotta.
- Riduci movimento rispettato per pressioni, spunte, testo, selezioni, espansione e spostamenti programmati.
- Backend: rimossa la cancellazione automatica dopo cinque giorni; migrazione additiva idempotente section_status, mantenuta dal normale setTaskStatus. Nessuna modifica a conti, budget o autenticazione.
- Web: allineati accento, superfici e completamento nelle due sezioni. Espansione inline e calendario continuo riguardano la revisione nativa; il calendario web mantiene la struttura precedente.

## Verifiche locali

62 test Foundation Swift superati, inclusi ordinamento, compatibilità dati, ripristino sezione, round trip dell'archivio e continuità dei mesi. Parsing di tutti i sorgenti/test Swift superato; non equivale a compilazione SwiftUI.

Worker reale eseguito con adapter D1 su SQLite in memoria: migrazione ripetuta, conservazione completate dal 2020, ritorno a In attesa, modifica senza perdita dello stato, validazione e cancellazione soltanto esplicita superati.

Build JavaScript/HTML e Playwright Chromium passati a 320/375/1280 px: navigazione esistente, ordine delle attività, due sole sezioni, riapertura nella sezione corretta, nessuna barratura, nessun overflow e Riduci movimento. Screenshot web con fixture: web/previews/attivita.png; non è uno screenshot nativo.

## Distribuzione e verifica Apple

Build/test Apple ancora da eseguire al momento della preparazione. I test UI sono aggiornati all'espansione inline e alla navigazione continua, senza rimuovere verifiche funzionali o di geometria. La CI su push verifica il backend su dati isolati; il contratto live esistente resta disponibile solo tramite workflow_dispatch perché il vecchio getLifeData contiene la cancellazione automatica.

Nessun dato reale letto o modificato durante queste prove. Backend non distribuito: manca un'identità Cloudflare configurata e resta necessario confrontare il gateway live con la baseline prima dell'aggiornamento. La sola installazione del client non rimuove la vecchia scadenza lato server. FPS, interruzione delle animazioni e resa finale su iPhone richiedono la prova runtime.

## Blocco di pubblicazione rilevato

La revisione automatica ha rifiutato l'invio del modulo invariato NativeNextTime.swift per coordinate precise, dello screenshot web per disclosure non verificata e del workflow Apple per pubblicazione di screenshot/log/risultati/IPA come artefatti di un repository pubblico. Nessun commit della revisione è stato pubblicato; il ramo codex/apple-calendar-reminders è stato soltanto creato sulla baseline. I blob preparati non sono stati inseriti in un commit o in una pull request.

Alternativa locale completata: archivio baseline pubblico lasciato byte per byte invariato, soli sorgenti modificati conservati come overlay e pacchetto assemblato localmente in native/build (ignorato da Git). Nessun nuovo file con coordinate e nessuna nuova immagine sono pubblicati. Per eseguire il workflow con gli artefatti pubblici descritti serve autorizzazione esplicita dell'utente, richiesta dopo la preparazione del risultato verificabile.

Regressione verificata anche sulla versione precedente: lo stesso test di conservazione fallisce sulla baseline perché elimina l'attività completata nel 2020; passa sulla revisione corrente.

## Autorizzazione successiva

L’utente ha approvato esplicitamente la build sul repository GitHub pubblico e la pubblicazione di IPA, log, risultati e screenshot dei test con dati demo. Si procede con l’overlay dei soli file modificati, senza ripubblicare moduli invariati con coordinate. Il backend live resta escluso dalla verifica automatica su push.
