# Mandato Astra — piano completo LifeOS fino all’IPA finale

4 novembre 2026. Questo mandato corregge il precedente invito limitato a Salute: Astra deve ricostruire il piano dell’intero progetto. Il brief Salute resta un allegato di requisiti e ipotesi. Qui si autorizzano documentazione e pianificazione, non l’esecuzione del backlog, la configurazione globale dei modelli o la produzione IPA.

## Obiettivo e fonti

Ricostruire da stato reale, decisioni utente e conversazioni/documenti disponibili TUTTE le modifiche ancora pertinenti per arrivare a una versione finale installabile e verificata. Non limitarsi a Salute o alla checklist breve. Non rifare automaticamente Bloom o quick add già implementati.

Leggere AGENTS.md, AI-HANDOFF.md, USER-DECISIONS.md/.json, PROJECT-CHECKLIST.md, STATUS.md, BUILD-STATE.json, OPEN-ISSUES.md, ARCHITECTURE-CURRENT.md e HEALTH-BODYBUILDING-BRIEF.md. Usare decision-history/2026-11-04-inventory.md/.json e i rapporti di area per rintracciare richieste omesse, conferme e storia; le 238 voci non sono tutte ordini attivi. Audit dei sorgenti canonici native-next e delle integrazioni solo dove necessario. Se una precedente chat o allegato non è disponibile, elencare il limite: non dichiarare letture mai fatte o inventare requisiti.

## Copertura obbligatoria del piano

- Decisioni, conflitti e criteri di accettazione: ogni richiesta pertinente deve avere un ID e un esito motivato (completa, parziale, da fare, proposta, sospesa, superata, non verificabile).
- Dashboard: gerarchia eventi/abitudini e finestra temporale, preghiere, Finanza, quick add, accessibilità e navigazione. Verificare i requisiti attivi invece di presumere che ogni componente esistente sia corretto.
- Bloom: griglia/anteprime già implementate e risultato visivo approvato; restano parità della libreria personale, allegati, persistenza e prove pertinenti. Non pubblicare backup personali.
- Nutrizione rapida: implementazione esistente, conservazione storico, prova finale errore/retry e accettazione visiva mancanti. Niente ritorno silenzioso al percorso 100 g.
- Salute: nuovo obiettivo bodybuilding con minimo attrito; riepilogo, dati/fonti, grafici, stime, macro ed ergonomia. Griglia, pulsanti e catalogo alimentare locale sono ipotesi da decidere; il futuro tracker deve essere analizzato nel piano senza diventare funzione obbligatoria per la prima IPA.
- Attività, calendario e turni: flussi e vincoli attivi, editor, completamento, sincronizzazione ed errori; distinguere regressioni da nuove richieste non approvate.
- Finanza e bollette: destinazione pagamento, periodo/quote di competenza, unicità del movimento, compatibilità server, dati e retry. Audit di baseline live prima di eventuali deploy; nessun deploy autorizzato dal piano.
- UI trasversale: margini, padding, proporzioni, pulsanti, campi, icone, tab bar, safe area, schermi piccoli, Dynamic Type, tastiera, stati vuoti e feedback.
- Integrità e integrazioni: persistenza/riavvio, migrazioni eventuali, HealthKit e assenza doppioni, App Group, widget, AlarmKit, firma e aggiornamento senza perdita dati.
- Ambiente/CI: Windows senza Mac personale, runner GitHub; ultimi pool Mac senza acquisizione per capacità arm64. Non ripetere job identici senza nuova evidenza e non sostituire prove reali con test verdi irrilevanti.
- Consegna: regressioni finali, revisione visiva, richiesta esplicita IPA, confezionamento e controllo pacchetto, verifica versione installata e accettazione sul telefono. IPA-GATE-01 resta ACTIVE: pianificare l’IPA non significa autorizzarla.

## Consegne di Astra

1. Una matrice di copertura requisito → origine/ID → stato reale → prova → lavoro mancante → fase. Distingui risultato tecnico, accettazione visiva e verifica sul telefono.
2. Un piano unico ordinato per dipendenze fino alla consegna, con punti di conferma espliciti e separazione tra indispensabile per il rilascio, decisioni da prendere ed evoluzioni future.
3. Per ciascun incremento: obiettivo circoscritto, decisioni già approvate, file/componenti, dati e invarianti, dipendenze, fuori ambito, criteri di accettazione, verifiche locali/simulatore/dispositivo, rischio e condizione di stop.
4. Per Salute: proposta UI/UX concreta e flussi, confronto delle ipotesi, trattamento delle stime, opzioni del catalogo pertinente/locale e del futuro diario. Nessun nuovo inserimento o database da implementare ora.
5. Conflitti con regole ACTIVE identificati con ID; chiedere conferma prima di sostituirle, non trovare compromessi impliciti. Le proposte non vincolanti possono essere analizzate senza fingere che siano già scelte.
6. Un pacchetto di esecuzione autonomo per Terra: manifest dei task, ordine/dipendenze, file pertinenti, contratti e prove richieste. Non costringere ogni agente a rileggere tutta la conversazione.
7. Audit finale del piano: nessuna richiesta attiva pertinente senza collocazione; nessuna proposta trasformata in obbligo; nessun gate di produzione omesso.

## Divisione del lavoro e contenimento costi — proposta da includere nel piano

L’utente chiede se sia fattibile usare sottoagenti e modelli meno costosi. Sì come possibilità da valutare, senza una promessa di risparmio e senza attivare/configurare ora agenti in background.

- Astra: riconciliazione requisiti, scelte di prodotto/architettura, dipendenze e revisione del piano. Non far generare a ogni sottoagente un piano completo concorrente.
- Terra: integrazione ed esecuzione degli incrementi approvati, controllo dei diff e verifica dei flussi. Componenti condivisi, HealthKit, persistenza, migrazioni e integrazione finale restano sotto revisione competente.
- Modello economico: incarichi semplici e delimitati, come inventario mirato in sola lettura, documentazione o modifiche locali ben specificate con verifiche chiare. La documentazione OpenAI indica gpt-6-luna per sottoagenti leggeri; verificarne disponibilità e modello effettivo nella chat di esecuzione. Non presumere che un nome di agente selezioni un modello diverso.
- Ogni incarico deve dichiarare ID, input minimi, commit base, file di proprietà, dipendenze, vincoli, output e verifica. Per task piccolo evitare delega se il coordinamento costa più del lavoro.
- Parallelizzare soltanto parti indipendenti, senza più agenti che modifichino contemporaneamente gli stessi file. Proposta iniziale: non più di due esecutori contemporanei; è una raccomandazione, non un nuovo limite imposto dall’utente.
- Contesto breve e mirato: non clonare tutta la chat a ogni agente. Risultati compatti con diff, esiti e dubbi. Un coordinatore integra e aggiorna report; niente compilazioni globali duplicate a ogni sotto-task.
- Definire escalation al coordinatore quando emergono requisiti ambigui, conflitti, schema dati, errori ripetuti o modifiche fuori ambito. Aumentare capacità dove serve invece di accumulare tentativi economici falliti.
- Distinguere tempo e costo complessivo: più agenti possono ridurre durata ma aumentare token. Verificare modello e reasoning effettivi; niente stime di risparmio inventate.

Riferimento tecnico per capacità di delega e scelta modelli: https://learn.chatgpt.com/docs/agent-configuration/subagents (consultato il 4 novembre 2026). La configurazione dei modelli non è stata modificata da questo documento.
