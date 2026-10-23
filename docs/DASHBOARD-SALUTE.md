# Dashboard salute e turni — 23 ottobre 2026

Requisito aggiornato: **solo Dashboard e Finanza nella navigazione**. Il calendario mensile dei turni è una destinazione secondaria della Dashboard. Attività e abitudini non hanno più pagine o controlli nell’interfaccia. I dati precedenti restano nel database e nei backup; la lettura della Dashboard non elimina più automaticamente le attività completate.

## Ordine della Dashboard

1. Settimana con turni, usando i giorni centrati su oggi e lo stesso stile del calendario mensile.
2. Riepilogo dei turni e meteo; nessuna attività, abitudine o agenda di eventi Life OS. Gli eventi ordinari si gestiscono in Calendario Apple.
3. Due azioni nello stile di Finanza: **Aggiungi peso** e **Calendario**. Nell’app nativa il componente delle azioni è condiviso con Finanza.
4. Grafico **Peso e calorie**, con selettore delle due misure, unità distinte e dati consultabili anche come elenco. Il calendario dei turni mantiene pubblicazione mensile e collegamento Apple.

Il calendario si apre sia dal pulsante sia da un giorno della settimana, seleziona il giorno scelto e consente il ritorno alla Dashboard. Nell’app iPhone è una destinazione della NavigationStack della Dashboard, non una terza scheda.

## Misurazioni

Non esisteva uno storico salute né un’integrazione HealthKit nel sorgente. È stato chiesto all’utente quale sorgente preferisca; in assenza di risposta è stato implementato l’inserimento **manuale**, reversibile, senza richiedere permessi Apple Salute. Non presentare questa scelta come una preferenza già confermata dall’utente.

- Data di oggi o precedente, peso in kg e calorie facoltative in kcal. È possibile inserire anche soltanto le calorie. Il significato delle calorie non viene inferito automaticamente come calorie attive o alimentari.
- Una riga per giorno. Salvare nuovamente una data aggiorna solo le misure presenti, conservando quelle dei campi lasciati vuoti. Non somma né duplica valori.
- Limiti di input: peso 20–500 kg; calorie intere 0–15000 kcal. Sono vincoli tecnici dell’editor, non intervalli clinici o consigli sanitari.
- Nuova tabella D1 `os_health_daily`, creata in modo additivo. API autenticate `saveHealthEntry([{day,weightKg,calories}])` e `getHealthData([])`; `getLifeData` include l’array `health` degli ultimi 90 giorni.
- Grafico delle ultime 30 giornate con misurazioni fra quelle disponibili negli ultimi 90 giorni. Valori assenti restano assenti; zero calorie compare solo se inserito esplicitamente. Nessun valore simulato viene spacciato per dato dell’utente.
- La demo iPhone salva queste misurazioni solo nel proprio archivio locale. Sul server l’aggiornamento per giorno è idempotente. Errori e nuovo tentativo mantengono l’input; nessuna coda offline nuova.
- Peso e calorie non entrano mai nel calendario pubblico dei turni. L’eventuale futura integrazione Apple Salute richiederà un’implementazione distinta.

## Stato e verifica

Implementazione: webapp, estensioni backend e pacchetto sorgenti iPhone 0.9.0 build 52. IPA 52 verificata; nessun deploy o migrazione in Promemoria/Calendario Apple eseguiti. L’utente ha confermato il caricamento del codice sul nuovo ramo pubblico. Il Worker con lo storico resta il template originale invariato: sono pubblicati soltanto il nuovo codice delle estensioni e il build che le assembla in `web/dist/worker.mjs`, escluso da Git. Questa alternativa non ripubblica dati finanziari incorporati. CI Apple completata con successo; [evidenze e IPA](native/BUILD-52.md). Credenziali Cloudflare assenti.

Superati build JavaScript, SQLite locale e Playwright a 320/375/1280 px: navigazione ridotta, assenza di vecchi contenuti, sette giorni, apertura/ritorno dal calendario, salvataggio con errore e retry, input conservati, selezione delle misure, assenza di overflow. Verificate anche pubblicazione, cancellazione e rigenerazione dei turni. Anteprima reale con fixture: `web/previews/dashboard-salute.png`.

Superati parser Swift, controllo design system e 65 test Foundation Linux, inclusi validazione salute, valori mancanti/zero, decimali italiani, aggiornamento giornaliero nella demo e riepilogo senza vecchi appuntamenti. CI Apple finale: compilazione e archivio Release passati, 83 unitari, 26 UI standard e 12 UI compatti superati; checksum, ZIP, versione/bundle e arm64 dell’IPA verificati separatamente. Il test dello stato vuoto raggiunge il testo visibile e verifica il dato salvato. I test UI e i selettori della suite compatta sono aggiornati alla nuova struttura; i casi legati a pagine rimosse sono sostituiti da verifiche delle nuove funzioni, preservando le prove finanziarie pertinenti.

Prima dell’attivazione confrontare il backend live e conservare DB, segreti e protezioni esistenti. Procedura calendario: [APPLE-CALENDAR.md](APPLE-CALENDAR.md). Diff cumulativo dei sorgenti iPhone: [native/APPLE-TURNI-52.diff](native/APPLE-TURNI-52.diff).
