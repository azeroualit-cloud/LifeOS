# LifeOS — correzioni e difetti aperti

**Catalogo alimenti generici, 7 novembre 2026.** Il sorgente contiene 145 voci italiane Ciqual 2025, barra «Cerca alimento» con lente e «Generic» sotto Biscotti. Catalogo e layout Salute condividono il [collaudo iOS](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42387125517) sul nuovo sorgente. Il [run precedente](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42386785838) è stato annullato dalla CI quando è arrivato il nuovo commit. Lo spostamento delle azioni Salute è [approvato](USER-DECISIONS.md#health-actions-bottom-01--active-7-novembre-2026) e implementato nel sorgente. I due pulsanti restano sopra la barra di navigazione durante lo scroll. Verifica del nuovo layout al simulatore da acquisire.

**LifeOS 0.10.19 build 80 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.19-build80/LifeOS-80.ipa), SHA-256 80a4e4759c810e2f2f69ef860a128d8cd020cf133cfa2e223cc4d51edf9f60c0. Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42235788082). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Collaudo pre-IPA superato.** Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516): 368/368, zero falliti e zero saltati. [Avvii Release](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516): 4/4 sullo stesso sorgente in un job separato. Confezionamento della build 80 autorizzato.

**Secondo collaudo build 80.** Run 42213901536: 366/368 prove passate, quattro avvii Release superati. I soli due fallimenti riguardano Carboidrati con testo accessibile e tastiera aperta. Ripristinata la geometria accessibile del foglio già verificata nella build 79; mantenute le modifiche per testo standard.

**Primo collaudo build 80.** Run 42203045463: 362/368 prove passate, 276/276 unitari, quattro avvii Release superati. Corrette geometria dei comandi e copertura dei test UI: il pulsante Dashboard deve essere interamente sopra la tab bar prima del tocco con testo grande; per il riferimento Apple Salute restano invariati identificativo e valori attesi. Nuovo collaudo richiesto.

**Revisione UI richiesta dopo la build 79.** UI-80-01 corregge allineamento e miniature nelle categorie Bloom, azioni Dashboard in Liquid Glass neutro, pannello rapido Nutrizione e riepilogo Salute con azioni testuali centrali. Nuova IPA autorizzata dopo collaudo. Suite e quattro avvii Release da verificare sul candidato, in job separati.

**LifeOS 0.10.18 build 79 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.18-build79/LifeOS-79.ipa), SHA-256 f7a9155e27fc27fd30a39e8422a43bfa26bdfdae69f0920ed87cf4c1d22a6f15. Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42194114583). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Collaudo pre-IPA superato.** Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946): 368/368, zero falliti e zero saltati. [Avvii Release](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045): 4/4 sullo stesso sorgente dopo il timeout della fase originale. Confezionamento della build 79 autorizzato.

**Recupero avvii Release.** Il [run 42181976367](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42181976367) ha preparato la sessione sintetica e raggiunto il limite di 65 minuti durante la fase Release. Verifica ripetuta solo per gli avvii, con più tempo e due simulatori accesi invece di tre. Suite 368/368 conservata. Nessun packaging avviato.

**Collaudo pre-IPA (6 novembre 2026).** Suite completa passata nel [run 42124676946](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946) sul commit 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. GitHub ha interrotto la fase avvii Release al limite del job (120 minuti). Verifica separata dei quattro avvii sul medesimo sorgente, senza ripetere la suite e senza packaging.

**Calendario data — verifica tecnica superata:** run 42116279080, 7/7 unitari e 1/1 UI, incluso GMT e riapertura; verifica iPhone ancora pendente.

**Apple Health reference:** run mirata 42113026579 superata (energia e peso sintetici visibili); precedente errore consenso non riprodotto, prova fisica ancora aperta.

**Calendario — errore data visualizzata:** run 42109968064, selezione/agenda 5 novembre, editor 4 novembre prima e dopo salvataggio con simulatore GMT. Possibile formattazione con fuso non civile; correzione richiede approvazione DEV-02.

**42094752571:** tre UI ancora fallite: data calendario 4 vs 5, consenso scrittura fixture HealthKit simulatore e navigazione (test adeguato, non verificato). Diagnostica dedicata preparata; avvii Release non eseguiti.

**42079725780:** cinque test UI falliti; aggiornamenti ai test diagnostici per calendario, scheda Salute, stack navigazione, feed Apple Health e tastiera abitudini non ancora verificati sul simulatore. Quattro avvii Release saltati.

**Collaudo finale 42060601929:** 25/92 UI falliti; test storici in aggiornamento, evento calendario non trovato nel giorno selezionato e riferimento Apple BodyMass assente dal sistema da investigare. Quattro avvii Release non eseguiti.

**QA-004 compact aggiornamento:** run 42056808149 supera standard e testo grande, ultima nota raggiunta e aperta; spazio visibile molto ridotto a testo grande resta da valutare visivamente. Verifica fisica e revisione globale aperte.

**QA-004 compatto, run 42053108157:** Bloom testo grande inconcluso per attesa inattività e timeout query UI dopo 12 gesti; nessuna conclusione sulla causa. Finanza: secondo confronto geometrico soggetto ad arrotondamento; prova aggiornata da rieseguire.

**QA-004 aggiornamento:** run 42044400960 passato standard/testo grande su simulatore principale, ultima nota Bloom raggiunta e apribile; screen compatto e iPhone ancora da verificare.

**QA-013 aggiornamento finale simulatore:** run 42005224764 passata, frame AX 44pt, elemento unico, tap bordo e import sintetico con persistenza verificati; screenshot confrontato con stato precedente, aspetto invariato. Prova iPhone e accettazione prodotto ancora pendenti.

**QA-011 aggiornamento:** screenshot `4EAB5DA4-4FE3-4A2A-AF45-825F66D16FFF.png`, run 42000813725, Salute testo grande, mostra tutte le quattro etichette tab; osservazione precedente non riprodotta in questa schermata, non chiusa in tutti gli stati. QA-004: contenuto scorre visivamente dietro la tab bar in questo frame, ma raggiungibilità ultimo elemento dopo scroll non dimostrata.

**QA-013 aggiornamento:** run 41948496725 conferma tap al bordo (21pt dal centro) riuscito, frame accessibile Libreria 18pt (requisito 44pt) fallito. Correzione mirata proposta, risposta utente pendente. Il test importazione si è fermato prima del picker.

**QA-013 — Bloom, diagnosi:** run 41944119975 misura frame accessibile del pulsante Libreria 18pt, test richiede 44pt. Il codice imposta un target di 44pt; verificare hitbox reale e gerarchia prima di decidere correzione, senza ridurre assert. Il test si è fermato prima di importare.

**QA-014 — Salute:** screenshot B26E8722 nel run 41944119975 mostra titoli TDEE/Peso previsto spezzati nelle card. Rifinitura proposta all’utente, approvazione pendente.

**QA-012 aggiornamento:** nel run 41944119975 test testo grande e tastiera passato; screenshot EFC67C7C mostra calorie e pulsante separati. Resta accettazione visiva e verifica iPhone.

**QA-012 — osservato, diagnosi da approfondire:** nel run 41894390397 screenshot `CDE933D8-219D-46EB-91F4-04C6AEAC0635.png`, con testo accessibile e tastiera attiva, il pulsante Aggiungi appare sovrapposto al contenuto calorie, con testo parzialmente coperto. Verificare scroll, safe area e leggibilità nel simulatore prima di proporre una correzione. Il test retry è passato ma non prova questo requisito visivo.

## Aggiornamento operativo — piano approvato, 4 novembre 2026

Il piano completo è autorizzato ed è in corso: [piano](PROJECT-RELEASE-PLAN.md), [copertura](REQUIREMENT-COVERAGE.json), [manifesto](EXECUTION-MANIFEST.json). I precedenti passaggi che indicano solo pianificazione o accettazione Bloom pendente sono storici e superati. Bloom è accettato visivamente, non per produzione; retry nutrizione resta non verificato; IPA 78 non accettata. Nessuna nuova IPA né deploy autorizzati. T07 prevede anteprima e conferma dei conflitti prima della modifica di Salute.

Aggiornato il 4 novembre 2026. Questa è una lista di lavoro con stato e provenienza, non un’attestazione di risoluzione. La build 78 non è accettata per la produzione.

## Difetti osservati nelle foto dell’app installata

| ID | Stato | Problema / prova necessaria per chiuderlo |
|---|---|---|
| QA-001 | OPEN — visibile | Bloom: immagini/card oltre le colonne e sovrapposizioni. Riprodurre con molte note, immagini verticali/orizzontali e titoli lunghi; nessuna card deve uscire dalla propria colonna o interferire con le altre. |
| QA-002 | OPEN — osservazione UI | Bloom: vuoti e gerarchia irregolare nella griglia. Stabilire il layout coerente con le richieste, poi verificare libreria popolata, scorrimento e miniature. |
| QA-003 | IMPLEMENTED — verifica recupero accessibilità pendente | NUTRITION-DIRECT-01 sostituisce il modulo inline con quick add, quattro campi riconoscibili, unità e calorie automatiche. Standard con tastiera e salvataggio verificato; testo grande con valori conservati e recupero visibile osservato nel video. Retry automatico ultima versione da confermare nel run 41871989512 su macos-26 (41856609394 e 41859714562 non eseguiti: runner non acquisito). Percorso porzione sospeso; approvato il render, accettazione dell’implementazione pendente. |
| QA-004 | OPEN — osservazione UI | Contenuti sotto la tab bar: verificare che l’ultimo elemento e ogni azione siano completamente raggiungibili sopra la barra, anche con tastiera e testo grande. |
| QA-005 | OPEN — osservazione UI | Salute: calorie odierne mancanti e grafico storico con punto/barra colorata richiedono semantica chiara. Applicare G12; se si propone una deroga alla regola del colore, chiedere conferma prima. |
| QA-006 | OPEN — revisione complessiva | Margini, densità, proporzioni, selezioni, icone e feedback dell’app installabile devono essere controllati con casi rappresentativi. I test esistenti non dimostrano qualità complessiva. |

Le osservazioni non autorizzano di per sé un redesign arbitrario. Il conflitto del quick add con il percorso per 100 g è già stato risolto esplicitamente: NUTRITION-DIRECT-01 ACTIVE e F03–F06 SUSPENDED. Non riproporre la vecchia restrizione come ancora attiva.

## Verifiche funzionali ancora distinte dalle prove già passate

| ID | Stato | Verifica |
|---|---|---|
| QA-007 | NOT VERIFIED | Confronto completo fra contenuti/allegati personali di Bloom originale e importazione nel telefono. Il conteggio 122 non basta per certificare tutti i contenuti. Non pubblicare il backup nel repository. |
| QA-008 | NOT VERIFIED BY AGENT | HealthKit sul telefono dopo rifirma: permessi, scrittura/modifica/eliminazione dei soli campioni LifeOS e recupero errori. I test con writer sintetico non equivalgono alla prova fisica. |
| QA-009 | NOT VERIFIED BY AGENT | App Group e widget dopo firma Signulous; AlarmKit e suono effettivo sul dispositivo. |
| QA-010 | NOT REAUDITED | Parità del Worker versionato con quello live prima di qualunque nuovo deploy. Verificare baseline, binding e autenticazione senza esportare dati personali. |

## Decisioni e proposte

- [Regole attive](USER-DECISIONS.md): decisioni esplicite, indipendenti dallo stato di implementazione.
- [Inventario completo](decision-history/2026-11-04-inventory.md): 238 voci con fonte e conflitti; 53 proposte dell’assistente restano distinguibili.
- I concept, i suggerimenti di nuove funzioni e la tabella di riconciliazione dell’assistente non sono automaticamente un’autorizzazione a implementare ogni proposta.
- Una richiesta storica sostituita non è un conflitto aperto da risolvere ogni volta. Per un nuovo input che contraddice una regola ACTIVE si applica META-01.

## Come chiudere una voce

Registrare requisito, riproduzione, cambiamento, commit, controllo pertinente, schermata reale dell’app e limiti. Controllare regressioni pertinenti e contenuti rappresentativi. Un mockup generato, il solo conteggio dei test o l’assenza di errori di compilazione non chiudono un difetto visivo.

## Nuova osservazione del ciclo anteprima

- **QA-011 — OBSERVED / riproduzione necessaria**: nel riepilogo Salute esportato dal run 41800947855 (`7EA9FE4E-5F0D-42DC-B046-D24DCA45FD24.png`) mancano visivamente le etichette Dashboard/Attività della tab bar. Verificare dopo stabilizzazione della schermata, con testo standard/grande, per distinguere transizione di cattura da difetto persistente. Nessuna causa o correzione ancora stabilita.

## H-GRID-01 — verifica della correzione approvata

QA-001/002: correzione implementata e verificata su 122 contenuti sintetici nel run [41816351684](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41816351684): 19 unitari e 4 UI passati, immagini contenute nelle card, due colonne e nessuna sovrapposizione nei quattro scorrimenti standard/testo grande. Anteprime link presenti nel caso sintetico. **Accettazione utente e prova con la libreria personale/telefono ancora pendenti**; non chiudere le voci come accettate. Rete dei singoli siti non certificata dalla fixture. Dettagli in [BLOOM-GRID-REVIEW.md](BLOOM-GRID-REVIEW.md).

## Pianificazione Salute per bodybuilding

HEALTH-UX-01 / HEALTH-PLAN-01 aggiungono l’obiettivo al backlog, non chiudono QA-005 o QA-006. Layout, azioni e catalogo alimentare locale sono proposte non vincolanti da valutare con Astra; nessun nuovo inserimento/database da implementare ora. Leggere [brief](HEALTH-BODYBUILDING-BRIEF.md) e [checklist unificata](PROJECT-CHECKLIST.md). Quick add esistente conservato; eventuali conflitti G05–G13 richiedono conferma prima di attuarli. Ultimi tentativi Mac 41871989512 e 41873100610 terminati senza runner, nessuno step eseguito; verifica finale quick add ancora mancante.
