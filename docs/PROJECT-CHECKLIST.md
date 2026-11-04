# LifeOS — checklist operativa unificata

Aggiornata il 4 novembre 2026. Fonte corrente per pianificazione e passaggio Astra → Terra. [Regole](USER-DECISIONS.md), [stato tecnico](BUILD-STATE.json), [brief Salute](HEALTH-BODYBUILDING-BRIEF.md). Le caselle descrivono risultati distinti: codice implementato non significa verifica completa o accettazione per produzione.

## 0. Piano globale Astra → Terra

- [x] Mandato esteso all’intero progetto fino all’IPA finale: [PROJECT-PLAN-BRIEF.md](PROJECT-PLAN-BRIEF.md).
- [ ] Ricostruire copertura di tutte le richieste attive, comprese quelle non riassunte in questa checklist.
- [ ] Piano unico con dipendenze, priorità, conflitti, criteri di accettazione e gate di rilascio.
- [ ] Task autonomi per Terra e proposta di delega economica limitata a incarichi adatti.
- [ ] Approvazione delle decisioni e degli incrementi prima dell’esecuzione; IPA solo su richiesta esplicita.

## 1. Regole e processo

- [x] Registro decisioni persistente; conferma prima di sostituire regole ACTIVE in conflitto.
- [x] Codice e report versionati su GitHub; verificare SHA remoto a ogni consegna significativa.
- [x] Anteprima/test simulatore separati dal confezionamento IPA.
- [x] IPA-GATE-01: nessuna IPA senza richiesta esplicita dell’utente.
- [x] Correzioni di prodotto proposte e approvate singolarmente; simulatore e controlli locali nel perimetro autorizzato.

## 2. Bloom — implementato

- [x] Due colonne con immagini proporzionate e contenute nelle card.
- [x] Anteprime link, fallback e cache separata dalle note.
- [x] Verifica al simulatore con fixture di 122 elementi e testo grande: run 41816351684, 19 unitari e 4 UI passati.
- [x] Risultato visivo approvato dall’utente.
- [ ] Confronto completo fra libreria/allegati personali originali e importazione sul telefono.
- [ ] Conferma sul dispositivo della versione finale quando l’utente autorizzerà la relativa IPA.

## 3. Quick add Nutrizione — implementato

- [x] Pulsante compatto in Dashboard → pannello con proteine, carboidrati, grassi e fibre effettivi in grammi.
- [x] Calorie automatiche e data modificabile; Aggiungi sopra tastiera.
- [x] Percorso per 100 g sospeso; nessuna migrazione o cancellazione dello storico.
- [x] Due colonne standard, una con testo accessibile; valori conservati in errore.
- [x] Errore sopra Riprova e protezione dallo swipe di chiusura durante una registrazione pendente implementati e osservati nel video nativo.
- [x] Flusso standard verificato; run 41853040353: 271 unitari e 4 UI passati, 1 UI accessibilità fallito nella ricerca del campo disabilitato.
- [ ] Verificare la correzione del test sul campo disabilitato e il successivo retry completo.
- [ ] Approvazione visiva dell’implementazione finale da parte dell’utente.

Gli ultimi run 41871989512 (macos-26) e 41873100610 (prova breve macos-15) sono terminati senza runner assegnato, senza eseguire step. GitHub annota capacità insufficiente sui runner macOS arm64. Non sono risultati dei test dell’app. Nessun nuovo tentativo avviato per questo aggiornamento documentale.

## 4. Nuovo obiettivo Salute — pianificazione autorizzata, sviluppo non autorizzato

- [x] Registrare HEALTH-UX-01: pagina per bodybuilding, dati essenziali subito visibili, consultazione e inserimenti con minimo attrito, pochi tocchi e poco spostamento del dito.
- [x] Conservare layout, pulsanti e catalogo locale come ipotesi non vincolanti; leggere il brief completo.
- [ ] Astra: audit mirato di UI/dati/fonti e componenti riusabili; separare problemi attuali e nuove funzioni.
- [ ] Astra: proporre gerarchia della pagina, wireframe e flussi con stati vuoti, errori e testo grande.
- [ ] Valutare quattro riquadri in griglia 2×2: TDEE e peso stimato tra un mese sopra; ultima pesata e calorie sotto. «4x4» è la formulazione utente: 2×2 è una lettura provvisoria dei quattro riquadri, non una decisione confermata.
- [ ] Valutare sotto una fila con quattro dati: proteine, carboidrati, grassi, fibre; ripiegamento accessibile su schermi stretti.
- [ ] Valutare posizione e forma di due azioni peso/pasto senza implementare adesso nuovi inserimenti.
- [ ] Definire date, fonti, periodi e affidabilità di TDEE e previsione a un mese; non presentare stime come misure.
- [ ] Valutare futuro tracker con cibi comuni pertinenti all’utente e cibi personalizzati; ridurre il rumore del catalogo.
- [ ] Valutare catalogo e diario locali/offline, senza dipendenza da sincronizzazione web o carico Cloudflare per la registrazione dei pasti.
- [ ] Definire copertura iniziale del catalogo, fonti/licenze, qualità dei nutrienti e manutenzione; non promettere «tutti i cibi» senza un perimetro verificabile.
- [ ] Definire riuso di pasti recenti/preferiti e quantità abituali come alternative da valutare, non funzioni già approvate.
- [ ] Valutare perdita dati, backup/ripristino e passaggio fra telefoni per una soluzione locale.
- [ ] Risolvere con conferma eventuali conflitti con G05–G13 e F03–F06 prima di attuare il design scelto.
- [ ] Ottenere approvazione del piano e del primo incremento prima dell’esecuzione Terra.

## 5. Altre correzioni da concordare

- [ ] Salute attuale: dati calorici mancanti, distinzione assenza dati/zero, semantica e periodi dei grafici; coordinare con il nuovo piano Salute.
- [ ] Tab bar: contenuti coperti, etichette e azioni raggiungibili.
- [ ] Margini, padding, densità, allineamenti e proporzioni coerenti.
- [ ] Campi e pulsanti riconoscibili, target touch, selezione e stati.
- [ ] Feedback di caricamento, errore, salvataggio e assenza dati.

Nessuna di queste voci autorizza da sola un redesign o una nuova funzione. Il backlog non è una delega a implementare tutto.

## 6. Collaudo complessivo

- [ ] Flussi reali di Dashboard, Attività, Salute, Bloom e Finanza.
- [ ] Schermi piccoli, testo grande, tastiera, safe area e scroll.
- [ ] Persistenza, riavvio, errori e retry senza duplicazioni.
- [ ] HealthKit fisico: permessi, lettura, scrittura, modifica ed eliminazione dei soli campioni LifeOS.
- [ ] App Group, widget e AlarmKit/suono sul dispositivo dopo firma.
- [ ] Compatibilità backend, bollette e quote prima di eventuali interventi; nessun deploy implicito.
- [ ] Prove visive pertinenti per chiudere i difetti; non basta una build o un test verde.

## 7. Consegna

- [ ] Revisione finale con l’utente.
- [ ] Richiesta esplicita dell’utente per produrre l’IPA.
- [ ] Solo dopo: packaging IPA, controlli e verifica della versione installata.
- [ ] Accettazione finale del prodotto. La build 78 resta non accettata per produzione.
