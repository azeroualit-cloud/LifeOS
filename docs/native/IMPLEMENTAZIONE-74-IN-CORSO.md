# Implementazione 74 — stato locale, non distribuito

Baseline: build 73, commit a4fb3e40514a15208a04282ac82cc55ed38bbdcd.

Implementati in questa lavorazione:
- Quattro schede Dashboard/Attività/Salute/Altro; destinazioni Finanza/Calendario/Bloom nello stack Altro e accesso esplicito dalla Dashboard.
- Puntino calendario legato al turno, mese corrente accentato e separatore prima della settimana di inizio mese.
- Rimozione particelle turno e avanzamento animato del riempimento.
- Modello nutrizione Decimal, campi macro, calcolo 4/4/9, timestamp, cronologia/edit e richieste HealthKit.
- Registro locale pending/confirmed con sync identifiers/version per i quattro campioni; retry della revisione pendente. Richiede verifica della semantica HealthKit e test delle interruzioni prima della distribuzione.
- Primo archivio Bloom separato, allegati content-addressed SHA256, indice atomico, backup sorgente conservato, import preview/idempotenza con rifiuto dei conflitti, ricerca/testo/modifica/Cestino, mappa e mescolamento.

Verifiche effettive: parsing sintattico Swift, git diff --check, checker design system passati. Nessun compilatore Swift/Xcode locale; nessun test XCTest eseguito in questa lavorazione. Nessuna IPA prodotta o pubblicata.

Da completare prima di considerare concluso il piano:
1. Documentazione SDK/runtime iOS reale, compilazione Apple e correzione type-check; test navigazione aggiornati alle quattro schede.
2. Servizio HealthKit iniettabile, test permessi/errori/riavvio/modifiche e verifica fisica. Scelta fonte nutrizionale esplicita.
3. Validazione Bloom completa (date, riferimenti, coordinate, framing, metadati, limiti), conflitti con tre scelte per record e report persistente; mapping categorie.
4. Categorie/fissati/multiselezione, creazione link/foto/file, media originali e secondari, ritaglio, Markdown completo, cluster e gestione luoghi, planner Riscopri e preferenze, App Intent/cattura.
5. Transizione geometrica calendario, controlli nativi, selezione grafici, test Riduci movimento e tocchi rapidi.
6. QA visuale e regressioni, archivio e download IPA verificato. Backup reale Bloom e confronto fisico restano verifiche distinte.

Il modulo Bloom attuale è un primo incremento funzionante nel codice, non l’intera integrazione descritta nello ZIP. Non rimuovere Bloom originale sulla base di questo stato.
