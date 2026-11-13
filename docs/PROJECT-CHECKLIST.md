# LifeOS — checklist operativa unificata

**PipelineIPA90 avviata13novembre2026:** [run43499809697](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43499809697),sorgente`1a71b95`,versione0.10.28build90. Prima3UI mirati compatti,suite restante sulprincipale,4avviiRelease,poi confezionamento/verifica/pubblicazioneautomatici solo se tuttiigatespassano. Correzione catalogo approvata e implementata,non ancora verificata alruntime. Utente monitora:nessunpollingattivo,nessunaltraesecuzione da avviare prima di analizzare questa. Nessuna nuovaIPA ancora verificata/distribuita;ultima89confermata. Nessun deploybackend.

**Implementato13novembre2026,da verificare in CI:** barra Liquid Glass con tutte sei le voci sempre visibili nell’ordine Dashboard/Attività/Salute/Bloom/Finanza/Calendario,senzaAltro. Stack creati su richiesta e conservati tramiteUIHostingController,ambiente SwiftUI e lifecycle inoltrati;barra nascosta con tastiera e ripristinata alla chiusura;target44pt e selezione accessibile. Filtrati128prodotti Coop alcolici/liqueur espliciti dal solo catalogo pubblico,30cocktail conservati,storico/personali invariati. Test mirati preparati:3unitari policy+2UI navigazione compatta/testo grande+tastiera+1UI catalogo come regressione della nuova gerarchia. Nessuna nuova IPA/deploy.

**Checkpoint 13 novembre 2026:** recupero43446654736 su57a23af passato (1unitario+1UI, zero fallimenti), conservati21casi del run precedente. Catalogo aggiuntivo1000prodotti/39marchi implementato su20f604a, controlli locali7importer+8selettore e validatori passati. [Nuova verifica mirata catalog-expansion](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43448734353) avviata:2unitari+1UI selezionati, esito/catture ancora da acquisire. Nessuna attesa attiva CI: monitoraggio all’utente. Nessuna IPA/deploy. Esclusione nuovi import applicata; rimozione alcolici preesistenti pendente confermaMETA01. Ultima IPA89 non include TDEE aggiornato né questi incrementi.

**Catalogo ampliato — 13 novembre 2026:** 1000 formulazioni aggiuntive di39marchi da Open Food Facts, separate dalle23schede ufficiali italiane. Dati collaborativi dichiarati nell’interfaccia, fonte prodotto e licenzaODbL visibili. Screening ingredienti/categorie esclude nuove voci alcol/vino/maiale, carne o gelatina di origine incerta e creatina; non certifica halal. Nessun duplicato di barcode con i cataloghi ufficiali;916basi g e84ml. Validazioni locali passate, nuova verifica iOS catalog-expansion da avviare. Recupero soli2test precedenti:43446654736,57a23af;21casi precedenti già passati, esito recupero non acquisito. Nessuna IPA/deploy. Rimozione anche degli alcolici esistenti: conferma META01 pendente.

**TDEE aggiornato e verificato — 12 novembre 2026.** [Run 43257504280](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43257504280), sorgente `b513c95`: compilazione, **23 unitari e 2 UI passati**, zero fallimenti/saltati. Verificate due sole pesate a un giorno di distanza, storico corto, ancoraggio a ultima pesata vecchia, esclusione dati oltre la finestra/futuri, copertura calorie e resistenza a una singola pesata anomala. Catture Salute e scenario ispezionate. Finestra: 14 giorni prima dell’ultima pesata, inclusa anche se oggi; nessun minimo arbitrario di numero/durata/confronti. Due date distinte necessarie per misurare variazione; copertura calorie 90% conservata. Modifica nel codice, **non nell’IPA 89 installata**; nuova IPA non richiesta. Nessun deploy.


**Modifica TDEE richiesta il 12 novembre:** finestra di 14 giorni a ritroso dall’ultima pesata, inclusa anche se odierna; rimossi minimi arbitrari di pesate, durata e confronti. Due date distinte necessarie per misurare variazione; copertura calorie 90% conservata. Nessun blocco TDEE per pesata vecchia o assenza di introito nella settimana corrente: per lo scenario si usa la media di calibrazione se manca quella recente; la protezione esistente sulle proiezioni da baseline vecchia resta. Implementazione e test preparati; verifica mirata tdee-review da eseguire. IPA 89 pubblicata invariata, nessuna nuova IPA/deploy autorizzati.


**IPA 0.10.27 build 89 pubblicata e verificata — 12 novembre 2026.** [Scarica IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.27-build89/LifeOS-89.ipa) · [Produzione riuscita](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43252634146). Sorgente `62533a1afb3295d70aad305339eacfd5d0554ec1`. Scaricato il file pubblico e verificati checksum `3932dda37cc8d65a0dfb4d21a084ae6a626861487f41a25e870b86fca52a4974`, versione/build di app e widget iPhone arm64, compatibilità import di avvio e presenza di 2.893 alimenti Coop e sette integratori con marca. Riutilizzate le 405 prove aggregate e i quattro avvii Release sul medesimo prodotto; nessun test ripetuto. Nessun deploy backend. IPA da firmare con Signulous; installazione conservando dati, prove fisiche e accettazione restano aperte. Le note sottostanti sono cronologia.


**Produzione IPA avviata — 12 novembre 2026:** [run 43252634146](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43252634146), sorgente `62533a1`, versione 0.10.27 build 89. Richiesta IPA-DELIVERY-2026-11-12. Controllo identità candidato e prove concluse, archivio iPhone, verifica pacchetto e pubblicazione; nessun test ripetuto, nessun deploy backend. Pubblicazione ancora da verificare.


**Candidato finale verificato senza IPA — 12 novembre 2026.** Prodotto `8ac2d4f`; sorgente dei test corretti `f901529`. Il run 43232065358 ha completato 405 test: 403 passati e due errori UI. Il [recupero mirato 43249620310](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43249620310) ha superato entrambi i casi, senza ripetere i 403 test passati né i quattro avvii Release già verdi. Copertura aggregata: **405/405 casi verificati**, non una nuova suite monolitica. Modificati soltanto test e selezione CI; codice/risorse/configurazione dell’app invariati. Catture finali ispezionate. **Nessuna IPA e nessun deploy backend.** Restano revisione utente, prove fisiche, parità dei dati personali e accettazione. Dettagli: [FINAL-CANDIDATE-2026-11-12.md](FINAL-CANDIDATE-2026-11-12.md). Le note sottostanti sono cronologia.


**Ripresa 12 novembre — run 43232065358 analizzato:** 299 unitari + 11 UI preflight passati; restante suite 93/95 UI passati, 2 falliti, zero saltati. Totale 403/405. Quattro avvii Release passati. Fallimenti: aspettativa decimale inglese in test italiano (101.8 contro 101,8 kcal); Bloom verifica isHittable immediata dopo annullamento File mentre la sezione sottostante esiste già. Correzioni limitate ai test: aspettativa italiana e attesa condizionata della raggiungibilità con diagnostica, senza cambiare prodotto. Verifica final-recovery dei soli due casi da avviare; niente nuova suite né avvii Release. Nessuna IPA/deploy.


**Gate finale attuale:** [run 43232065358](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43232065358) sul commit `8ac2d4f5725d624f8a89f8458cf7c03dc2242bc9`, avviato manualmente dopo le verifiche mirate. Suite completa e quattro avvii Release in job separati; package e publish esclusi dall’evento workflow_dispatch. In attesa dell’esito effettivo.

**Candidato pronto per il gate completo senza IPA:** [prova mirata 43229809175](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43229809175), sorgente ff2a894, passata (1 unitario e 2 UI). Ispezionate catture reali di marca Spesotti, 250 ml = 117,5 kcal, cronologia per giorno ed eliminazione del solo giorno selezionato. Le precedenti prove mirate coprono capsule/polveri, identità personale e palette standard/grande. Nel riepilogo storico le fibre non dichiarate restano “—”. La nuova suite completa e i quattro avvii Release sono il prossimo gate; non c’è autorizzazione IPA.

**Checkpoint catalogo completo e diagnosi, 12 novembre:** inventario ufficiale 5.323/5.323 URL, 222/222 pagine, ora **2.893 alimenti** dopo verifica di tre esclusioni errate (un vegetale e due prodotti di pollo/tacchino senza suino); **208 Gli Spesotti**, 305 tabelle non disponibili, 5 limiti di etichetta espliciti, un EAN duplicato coerente unificato. Coverage e manifesto in COOP-CATALOG-COVERAGE.json / COOP-CATALOG-MANIFEST.json. Voci locali senza macro non inviano zeri in HealthKit.

Il collaudo completo precedente 43178362187 sul commit 7087d91 ha completato 390 test: 389 passati, un fallimento nel vecchio vincolo di larghezza 60 pt della palette. Quattro avvii Release passati; IPA esclusa. La verifica 43189745646 sul commit 5e05fa3 ha compilato e rilevato un’aspettativa unitaria sulla rimozione della porzione in modifica manuale e due errori UI: propagazione dell’identificatore del diario sul pulsante e helper test che scriveva 300200 invece di sostituire 200 con 300. Correzioni preparate; nessuna nuova suite completa finché non passa la verifica mirata dei soli casi interessati e del latte Spesotti in ml. Non sono esiti verdi del nuovo candidato.

**Nuovo incremento autorizzato il 12 novembre (catalogo e flussi):** richiesta aggiuntiva e conferma META-01 per marche Coop/Spesotti, conservando generici, esclusioni maiale/creatina e gate IPA. Implementati nel sorgente unità capsule/compresse/grammi e ml per etichette liquide, modifica/copia personale, composizioni pubbliche degli integratori, preview eliminabile del solo giorno, cronologia per giorno e palette Liquid Glass compatta. Verifica mirata `catalog-review` da eseguire. Importazione catalogo ufficiale ancora in acquisizione: inventario completo 5.323 URL, schede nutrizionali in elaborazione; il file branded-foods attuale è un segnaposto e NON rappresenta catalogo completato. Il collaudo 43178362187 riguarda esclusivamente il sorgente precedente 7087d91 e non certifica queste modifiche. Nessuna nuova IPA e nessun deploy backend.

**Prova mirata conclusa:** [43176199615](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43176199615), sorgente `d91aa380d821498cb7722639c0489a2d3318c59c`: 288 unitari e 4 UI passati, zero fallimenti. Ispezionate catture del riferimento Apple Salute (2.200 kcal, 80 kg) e palette standard/grande. Il candidato aggiunge soltanto una protezione alla ricerca dei processi non avviati e salta tale ricerca se la fixture è già pronta; nessun sorgente prodotto modificato. Prossimo gate: singolo workflow manuale lifeos-validate80 con suite completa e quattro avvii Release. Su workflow_dispatch package89/publish89 sono esclusi dalle condizioni evento push.

## Stato corrente — audit del 12 novembre 2026

Questa sezione prevale sulle note cronologiche successive. La nuova chat autorizza il proseguimento e il collaudo finale completo, compresi quattro avvii Release, **senza creare, confezionare o distribuire IPA** e senza deploy backend. Occorre una nuova richiesta IPA esplicita in questa chat. DEV-02 resta applicabile ai nuovi difetti di prodotto; non ripetere approvazioni già registrate per lo stesso ambito.

Checkpoint osservato: `codex/revision77` remoto a `6a8826d`, `main` a `1b80e58`; il checkpoint `2d33d8a` è storico. Sorgente dell'ultimo tentativo: `db6d6f5e03e4d5cd5bf1dca850372d50063345b6`. Il [run 43113799496](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43113799496) ha eseguito 299 prove: 298 passate, 1 fallita, zero saltate. Il preflight si è fermato su `The Health authorization dialog did not become ready`; la restante suite non è stata completata. Quattro avvii Release passati; packaging e pubblicazione saltati. Questi 299 risultati non equivalgono a una suite completa verde.

| Task | Evidenza ricostruita | Stato e lavoro residuo |
| --- | --- | --- |
| T00 | Registro, copertura e manifesto disponibili; copertura con 238 voci storiche più 30 aggiuntive | Audit e riallineamento documenti in corso; verificare sincronizzazione SHA al checkpoint finale |
| T01 | Suite e quattro avvii passati nel run 43094447884, precedente agli ultimi incrementi; quattro avvii passati anche nel 43113799496 | Pipeline disponibile; collaudo completo del candidato attuale ancora aperto |
| T02 | Retry accessibile 41894390397; QA-012 testo grande e tastiera 41944119975; regressioni nutrizione successive | Verifiche sintetiche disponibili; revisione finale e HealthKit fisico aperti |
| T03 | Dashboard e QA-004 standard/grande 42044400960, compatto 42056808149; incremento 42573602745 | Verifiche simulatore disponibili; regressione finale e revisione utente aperte |
| T04 | Bloom 42005224764: frame 44 pt, bordo, importazione e persistenza sintetica; sezioni aggiornate nei collaudi successivi | Parità privata di note, allegati e hash e verifica iPhone non dimostrate |
| T05 | Calendario GMT/riapertura 42116279080; 19 test sintetici Attività; palette standard/grande 43111876770 | Regressioni simulate disponibili; sveglie, AlarmKit e suono fisici aperti |
| T06 | 35 test sintetici Finanza; audit non mutante 41949645412 con tre test trasformazione | Importi personali/E10 e parità integrale Worker non dimostrati; nessun deploy autorizzato |
| T07 | HEALTH-GRID-02 conferma la deroga; checklist 9 novembre aggiorna la sola disposizione a 3×2 | Approvazioni già registrate: non riaprire il vecchio conflitto per lo stesso ambito |
| T08 | Letture macro/fonti e deduplica coperte da prove sintetiche precedenti | Blocco corrente della fixture Apple Salute da diagnosticare; HealthKit fisico aperto |
| T09 | Griglia, storico, medie e Dashboard: 42573602745; diario storico e omega-3: 42575533916 | Implementazione e prove mirate disponibili; regressione finale e revisione utente aperte |
| T10 | QA-004 su simulatore principale e compatto, standard e testo grande; persistenza sintetica | App Group, widget e continuità dati sul dispositivo non verificati |
| T11 | Ultima suite verde 43094447884 precede palette e integratori finali | **Aperto**: risolvere prima il blocco mirato, poi una sola suite completa e quattro avvii Release senza IPA sul candidato pronto |
| T12 | Nessuna nuova autorizzazione IPA in questa chat | Sospeso fino alla richiesta esplicita; firma/installazione, prove fisiche e accettazione separate |

Ordine delle attività dell'utente al termine del lavoro autonomo: revisione delle schermate correnti ed eventuali sole nuove approvazioni DEV-02; richiesta esplicita IPA quando T11 è superato; dopo produzione, firma e installazione conservando i dati; verifica parità Bloom/Finanza e prove HealthKit, App Group/widget, AlarmKit/suono; accettazione esplicita. Le prove automatiche non sostituiscono nessuno di questi esiti.

## Cronologia fino al precedente checkpoint

Le autorizzazioni IPA e gli stati “corrente”, “da avviare” o “in corso” sotto sono storici. Per questa chat usare il perimetro e la matrice sopra; il backlog storico non autorizza nuove funzioni.

**LifeOS 0.10.19 build 80 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.19-build80/LifeOS-80.ipa), SHA-256 80a4e4759c810e2f2f69ef860a128d8cd020cf133cfa2e223cc4d51edf9f60c0. Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42235788082). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Collaudo pre-IPA superato.** Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516): 368/368, zero falliti e zero saltati. [Avvii Release](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516): 4/4 sullo stesso sorgente in un job separato. Confezionamento della build 80 autorizzato.

**Revisione UI richiesta dopo la build 79.** UI-80-01 corregge allineamento e miniature nelle categorie Bloom, azioni Dashboard in Liquid Glass neutro, pannello rapido Nutrizione e riepilogo Salute con azioni testuali centrali. Nuova IPA autorizzata dopo collaudo. Suite e quattro avvii Release da verificare sul candidato, in job separati.

**LifeOS 0.10.18 build 79 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.18-build79/LifeOS-79.ipa), SHA-256 f7a9155e27fc27fd30a39e8422a43bfa26bdfdae69f0920ed87cf4c1d22a6f15. Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42194114583). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Collaudo pre-IPA superato.** Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946): 368/368, zero falliti e zero saltati. [Avvii Release](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045): 4/4 sullo stesso sorgente dopo il timeout della fase originale. Confezionamento della build 79 autorizzato.

**Collaudo pre-IPA (6 novembre 2026).** Suite completa passata nel [run 42124676946](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946) sul commit 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. GitHub ha interrotto la fase avvii Release al limite del job (120 minuti). Verifica separata dei quattro avvii sul medesimo sorgente, senza ripetere la suite e senza packaging.

**Consegna corrente (5 novembre 2026).** Autorizzata una singola nuova IPA dopo il superamento del collaudo pre-IPA. Suite completa e quattro avvii Release nel [run 42124676946](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946) sul candidato 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. Esito da acquisire. Ultima release verificata: 0.10.17 build 78. Firma Signulous, verifica iPhone e accettazione utente restano separate. Nessun deploy backend o cancellazione autorizzati.

## Stato corrente — 5 novembre 2026

- [x] Piano completo approvato e matrice requisiti documentata.
- [x] Bloom: griglia accettata visivamente; frame accessibile 44 pt e importazione sintetica verificati nel run 42005224764. Parità libreria personale e iPhone restano aperte.
- [x] Nutrizione: retry e correzione sovrapposizione verificati al simulatore; accettazione visiva e HealthKit fisico pendenti.
- [x] Salute: griglia 2×2, nutrienti HealthKit e titoli leggibili implementati; prove mirate simulatore passate. Accettazione e HealthKit fisico pendenti.
- [x] Test Calendario corretto e passato; 19 test sintetici Attività/movimenti passati. Verifiche complete flussi e iPhone pendenti.
- [x] Finanza: 35 test sintetici e audit live non mutante passati. Parità integrale Worker e dati reali non verificati.
- [x] QA-004: ultimo contenuto raggiungibile su simulatore principale e compatto, anche con testo grande (run 42044400960 e 42056808149).
- [ ] QA visiva trasversale, tab bar, accessibilità, persistenza e regressione complessiva; revisione della leggibilità Bloom compatta con testo grande.
- [ ] Verifica fisica HealthKit, App Group, widget e AlarmKit; revisione e accettazione utente.
- [x] Richiesta esplicita IPA ricevuta.
- [ ] Completare i quattro avvii Release, confezionare e verificare l’installazione senza perdita dati.

Le sezioni precedenti del 4 novembre sotto sono cronologiche ove contrastano con questo aggiornamento.

## Aggiornamento operativo — piano approvato, 4 novembre 2026

Il piano completo è autorizzato ed è in corso: [piano](PROJECT-RELEASE-PLAN.md), [copertura](REQUIREMENT-COVERAGE.json), [manifesto](EXECUTION-MANIFEST.json). I precedenti passaggi che indicano solo pianificazione o accettazione Bloom pendente sono storici e superati. Bloom è accettato visivamente, non per produzione; retry nutrizione resta non verificato; IPA 78 non accettata. Nessuna nuova IPA né deploy autorizzati. T07 prevede anteprima e conferma dei conflitti prima della modifica di Salute.

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
