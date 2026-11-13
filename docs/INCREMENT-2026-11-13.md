# Incremento 13 novembre 2026

Richiesta esplicita CATALOG-NAVIGATION-2026-11-13 confermata. Nessuna nuova IPA né deploy backend. La build installabile 89 non include questo incremento né il TDEE successivo già verificato.

## Implementazione e ricerca

- Schede Tutti (alimenti), Personali (tutte le voci personali modificabili), Integratori (pubblici e personali). Creazione nella scheda Integratori preimposta il tipo corretto.
- 32 integratori Coop spostati dalla dispensa: tabelle rimangono per100g/ml, senza dedurre quantità per capsule dalle confezioni. Storico snapshot invariato. ml supportati anche nelle copie personali.
- 23 nuove formulazioni e fonti: ITALIAN-BRANDS-2026-11-13.md. Generici, Coop e Spesotti preservati; maiale/creatina esclusi.
- Ricerca offline per termini combinati nome/marca/alias, accenti e maiuscole ignorati, prefissi, codice a barre esatto ove disponibile. Priorità nome esatto/alias, nome iniziale, altri termini; frequenza30giorni resta spareggio. Token pubblici indicizzati una volta; personali sempre letti dal valore corrente. Nessuna scansione fotocamera introdotta.
- Proposta successiva: 100–200 formulazioni principali su più categorie, evitando varianti della sola confezione. Non importare migliaia di voci non verificate.
- Sei destinazioni native: prime quattro Dashboard/Calendario/Finanza/Salute; Altro contiene Attività/Bloom. Stack indipendenti e percorsi Dashboard/deep link conservati.
- Dipingi turni usa calendar.badge.clock e checkmark in modalità attiva.

## Controlli

Validazioni locali: verify-branded-catalog completo2893 e verify-italian-brands23/5 passati; test_development_selection8 passati; diff check passato. Xcode non disponibile su Windows. Modalità CI catalog-navigation: classi nutrizione/unità, selezione integratori/ricerca, navigazione/overflow, capsule/polvere, editor integratori, proiezione/widget/AlarmKit e preview widget. Catture generate soltanto nel run; non dichiararle già disponibili. Nessuna suite completa ripetuta.

## Sveglia e widget: prove utente

Sveglia: iOS26+, modalità reale, evento non ricorrente con inizio2–3minuti futuro → Avviso evento → Sveglia urgente → salva e autorizza. Bloccare iPhone, controllare suono/avviso/Ferma. È locale all’iPhone, distinta da Promemoria locali. Conservare eventuale messaggio Sveglia non aggiornata. Prova fisica ancora aperta.

Widget: aprire/sincronizzare LifeOS → Impostazioni → Notifiche e Siri → Aggiorna widget2×2; leggere stato. Galleria Home: Life OS · Oggi, formato piccolo. Assente: verificare estensione conservata nella firma; vuoto con avviso App Groups: stessa group.com.nas.lifeos per app/estensione. Non attribuire a firma o prodotto senza sintomo. L’utente deve ancora comunicare se assente/vuoto/vecchio e messaggio. Nessuna reinstallazione/cancellazione prescritta.

## Run corrente

https://github.com/azeroualit-cloud/LifeOS/actions/runs/43440966964
Sorgente e16e83c77a7d2477f9550cf37e9428d8f24573f5. Workflow manuale catalog-navigation, package_trial=false. Nessun risultato iOS ancora acquisito; l’utente monitora il run. Alla ripresa leggere esito e catture prima di avviare altri run.
