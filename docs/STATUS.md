# LifeOS — stato corrente

**NUTRITION-DATE-CLIP-01, 8 novembre 2026.** Il calendario era tagliato su iPhone, anche nel flusso con «Cerca alimento». La correzione approvata apre Data in un foglio a tutta larghezza con Fine e Annulla e conserva i nutrienti inseriti. Registrata la [regola UX-DATE-PICKER-01](USER-DECISIONS.md#ux-date-picker-01--active-8-novembre-2026). [Verifica al simulatore](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42481363683) in corso sul commit `c2c7e8b`.

**Build 83 (0.10.21), IPA pubblicata.** [Download diretto](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.21-build83/LifeOS-83.ipa). Suite completa, quattro avvii Release e verifica pacchetto superati nel [run 42404491236](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42404491236) sul sorgente `75a9af4`. SHA-256 `a7449e22405809d93e01f02298e87addcc6be172f6a8fed3489115d21bd14cd4`. Firma Signulous, prova iPhone e accettazione aperte.

**Catalogo alimenti generici, 7 novembre 2026.** Il sorgente contiene 145 voci italiane Ciqual 2025, barra «Cerca alimento» con lente e «Generic» sotto Biscotti. Catalogo e layout Salute condividono il [collaudo iOS](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42387125517) sul nuovo sorgente. Il [run precedente](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42386785838) è stato annullato dalla CI quando è arrivato il nuovo commit. Lo spostamento delle azioni Salute è [approvato](USER-DECISIONS.md#health-actions-bottom-01--active-7-novembre-2026) e implementato nel sorgente. I due pulsanti restano sopra la barra di navigazione durante lo scroll. Compilazione e test selezionati passati al simulatore sul commit c930a9f. Le prove includono la ricerca di Biscotti, la porzione e i pulsanti Salute con testo standard e grande. Verifica su iPhone ancora aperta.

Il nuovo catalogo cita Anses. 2025. Ciqual French food composition table. I codici delle voci nel file locale corrispondono al [dataset Ciqual 2025](https://zenodo.org/records/17550133). I valori sono per 100 g. Per il calcolo delle porzioni, «tracce» è trattato come zero e un valore indicato con un limite superiore come metà del limite. Le righe con valori mancanti sono escluse. Lo storico conserva i valori già registrati.

**Correzione budget utenze approvata.** Cambiare la competenza di una bolletta collegata a un piano stimato ricalcola anche la stima del mese corrente nel budget. Le quote effettive hanno precedenza. Caso sintetico da 221,79 € verificato: 73,93 € a novembre, con movimento unico e fondo di novembre invariato. 19 test del Worker e 3 test della trasformazione passati. Deploy Cloudflare verificato su lifeos e lifeos-native-test nel [run 42372669757](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42372669757). Per una bolletta corretta prima del deploy, confermare nuovamente il periodo nel movimento esistente.

**Build 82 (0.10.20), candidata.** Redesign nativo Dashboard e Salute autorizzato con richiesta esplicita di IPA. Il workflow pre-IPA esegue la suite completa e quattro avvii Release prima di produrre LifeOS-82.ipa come artifact. Catalogo offline USDA SR Legacy (4.612 voci) e diario con registrazioni locali e campioni energetici leggibili in Apple Salute. Collaudo e packaging da verificare in Actions.

**LifeOS 0.10.19 build 80 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.19-build80/LifeOS-80.ipa), SHA-256 80a4e4759c810e2f2f69ef860a128d8cd020cf133cfa2e223cc4d51edf9f60c0. Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42235788082). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Collaudo pre-IPA superato.** Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516): 368/368, zero falliti e zero saltati. [Avvii Release](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516): 4/4 sullo stesso sorgente in un job separato. Confezionamento della build 80 autorizzato.

**Secondo collaudo build 80.** Run 42213901536: 366/368 prove passate, quattro avvii Release superati. I soli due fallimenti riguardano Carboidrati con testo accessibile e tastiera aperta. Ripristinata la geometria accessibile del foglio già verificata nella build 79; mantenute le modifiche per testo standard.

**Primo collaudo build 80.** Run 42203045463: 362/368 prove passate, 276/276 unitari, quattro avvii Release superati. Corrette geometria dei comandi e copertura dei test UI: il pulsante Dashboard deve essere interamente sopra la tab bar prima del tocco con testo grande; per il riferimento Apple Salute restano invariati identificativo e valori attesi. Nuovo collaudo richiesto.

**Revisione UI richiesta dopo la build 79.** UI-80-01 corregge allineamento e miniature nelle categorie Bloom, azioni Dashboard in Liquid Glass neutro, pannello rapido Nutrizione e riepilogo Salute con azioni testuali centrali. Nuova IPA autorizzata dopo collaudo. Suite e quattro avvii Release da verificare sul candidato, in job separati.

**LifeOS 0.10.18 build 79 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.18-build79/LifeOS-79.ipa), SHA-256 f7a9155e27fc27fd30a39e8422a43bfa26bdfdae69f0920ed87cf4c1d22a6f15. Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42194114583). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Collaudo pre-IPA superato.** Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946): 368/368, zero falliti e zero saltati. [Avvii Release](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045): 4/4 sullo stesso sorgente dopo il timeout della fase originale. Confezionamento della build 79 autorizzato.

**Recupero avvii Release.** Il [run 42181976367](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42181976367) ha preparato la sessione sintetica e raggiunto il limite di 65 minuti durante la fase Release. Verifica ripetuta solo per gli avvii, con più tempo e due simulatori accesi invece di tre. Suite 368/368 conservata. Nessun packaging avviato.

**Collaudo pre-IPA (6 novembre 2026).** Suite completa passata nel [run 42124676946](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946) sul commit 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. GitHub ha interrotto la fase avvii Release al limite del job (120 minuti). Verifica separata dei quattro avvii sul medesimo sorgente, senza ripetere la suite e senza packaging.

**Consegna corrente (5 novembre 2026).** Autorizzata una singola nuova IPA dopo il superamento del collaudo pre-IPA. Suite completa e quattro avvii Release nel [run 42124676946](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946) sul candidato 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. Esito da acquisire. Ultima release verificata: 0.10.17 build 78. Firma Signulous, verifica iPhone e accettazione utente restano separate. Nessun deploy backend o cancellazione autorizzati.

**Calendario corretto e verificato:** run 42116279080 sul commit 9e06668, build riuscita, 7/7 NativeActivityTests inclusi quattro fusi e cambi ora, UI calendario 1/1. In GMT evento 5 novembre mostra 5 nell’editor prima e dopo salvataggio e resta nell’agenda del 5. Accettazione su telefono e collaudo finale complessivo restano aperti. Nessuna IPA/deploy.

**Calendario:** correzione del fuso civile approvata esplicitamente dall’utente; implementata la visualizzazione della data nell’editor con il calendario civile esistente, test su fusi e DST e UI preparati. Prove sul simulatore da eseguire; non dichiarare risolta prima dell’esito.

**Apple Health reference 42113026579:** 0f8c78a, build e test dedicato 1/1 passati; consenso sintetico via UI, fixture Dati pronti, Salute mostra 2200 cal e 176,4 lb. Il precedente errore di autorizzazione non si è ripetuto; stabilità e prova HealthKit fisica non sono garantite da una singola ripetizione. Calendario: errore data visualizzata riprodotto e correzione prodotto in attesa di approvazione DEV-02; vedi sotto. Navigazione test aggiornato ancora da rieseguire, quattro avvii Release non eseguiti.

**Diagnostica calendario 42109968064:** compilazione riuscita; giorno selezionato 2026-11-05, fuso processo GMT. Editor mostra 4 novembre prima e dopo riapertura, mentre evento compare nell’agenda del 5: discrepanza di presentazione riprodotta, non perdita del record. Fix prodotto da proporre secondo DEV-02. Apple Health non è stato eseguito in questa run, nonostante selettore previsto; workflow aggiornato per una prova mirata per volta.

**Collaudo finale 42094752571:** c2bb2af, 364/367 prove passate, 3 UI fallite e quattro avvii Release saltati. Il calendario mostra 4 novembre dopo selezione del 5: possibile differenza di fuso, dati salvati da verificare. Apple Health fixture ha segnalato scrittura non autorizzata dopo consenso UI, sebbene riuscita in run precedente. Navigazione: test adeguato allo stack. Preparata diagnosi dedicata per calendario e HealthKit, ancora da eseguire; nessuna modifica prodotto, IPA o deploy.

**Collaudo finale 42079725780:** main 9bd4a13, compilazione riuscita, 362/367 test passati inclusi 275 unitari; cinque UI falliti (precedente: 25). Avvii Release saltati. Analisi: test calendario cercava una data diversa da quella selezionata; Salute fermava scroll prima di mostrare la scheda intera; navigazione ignorava stack calendario conservato; Apple Health cercava peso senza scorrere feed virtualizzato; Abitudini aveva tastiera aperta sopra Salva. Modifiche diagnostiche ai test preparate, ancora da eseguire; non assumere che i problemi siano risolti. Nessuna IPA o deploy.

**Collaudo finale run 42060601929:** main 85caca8 autorizzato e sincronizzato; compilazione e 275 unitari riusciti; UI 25 fallimenti su 92. Dieci test revisione 78 riusciti. Gli avvii Release sono stati saltati. Analisi log: numerosi test storici presumevano tab, card o finestra home precedenti; aggiornamenti ai test preparati e da verificare. Evento calendario mancante nel giorno atteso e riferimento BodyMass non visibile in Apple Salute richiedono diagnosi; non sono classificati come risolti. Preparato artifact diagnostico leggero per prossime esecuzioni. Nessuna IPA o deploy.

**Main:** il 5 novembre 2026 l’utente ha autorizzato esplicitamente l’aggiornamento diretto del ramo principale con il ramo di lavoro, per sbloccare il collaudo finale. Verificare l’esito effettivo del push e lo SHA remoto; nessuna autorizzazione IPA o deploy.

**QA-004 compatto run 42056808149:** commit 4adc7bf, compilazione riuscita, 275/275 unitari e 6/6 UI passati. Finanza supera il confronto geometrico. Bloom standard raggiunge il fondo; con testo grande arriva alla nota 121 al gesto 67 e la apre. Screenshot finale controllato: ultima card raggiungibile sopra tab; spazio visibile ridotto con testo molto grande, non valutato come accettazione visiva. Prova su iPhone ancora necessaria.

**QA-004 compatto run 42053108157:** 275 unitari e verifica standard passati. La prova Bloom con testo grande è inconclusa: dopo 12 gesti XCTest ha atteso 60 secondi lo stato inattivo, poi la query della tab è scaduta; la causa non è stabilita. Il confronto Finanza è fallito per un secondo errore infinitesimale di arrotondamento. Preparata una ripetizione con tolleranza di un pixel e meno letture ripetute di coordinate, mantenendo gli assert.

**QA-004 compatto ripetizione:** run [42053108157](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42053108157), focused/dashboard/compact su bbd35f0, avviata con timeout adeguato e tolleranza geometrica di un pixel. Esito pendente.

**QA-004 compact run 42048485584:** 275 unitari passati; standard raggiunge il fondo. Testo grande interrotto a timeout 360s, dopo checkpoint 20 al 28%, senza raggiungere la nota finale: tempo del test esteso sulla base della prova, assert invariati. Altro test UI Finanza fallito per differenza floating point 0,00000000000006pt: confronto reso robusto con tolleranza di un pixel fisico. Nuova verifica necessaria.

**QA-004 compatto:** run [42048485584](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42048485584), focused/dashboard/compact su 8190eef, avviato; esito pendente.

**QA-004 run 42044400960:** 275 unitari e 6 UI passati; Dashboard, Salute, Bloom ultimo contenuto raggiungibile sopra tab, standard e testo grande su simulatore principale. Bloom con 122 note raggiunge la 121 al gesto 96; screenshot controllato. Compatibilità schermo compatto e iPhone fisico ancora da verificare.

**QA-004 verifica estesa:** run [42044400960](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42044400960), focused/dashboard su b1ef2ff, avviata dopo evidenza 81% a 80 gesti; esito pendente.

**QA-004 diagnosi run 42019184325:** Bloom grande avanza 0→19→40→81% in 80 gesti, con note fino a 120 visibili; nota 121 non ancora raggiunta. Limite del test esteso a 120 gesti, assert invariati; nuova prova necessaria.

**QA-004 diagnostica:** run [42019184325](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42019184325), focused/dashboard su fd79435, avviato con catture intermedie note visibili; esito pendente.

**QA-004 Bloom grande:** run 42015355697 non raggiunge la nota 121 dopo 80 gesti; causa non stabilita. Aggiunte catture e identificativi delle note visibili durante lo scroll, senza ridurre assert; nuova prova diagnostica necessaria.

**QA-004 run 42015355697:** compilazione e 275 unitari passati; 5/6 UI passati. Standard Dashboard/Salute/Bloom passato; testo grande Dashboard/Salute passati; Bloom grande non ha raggiunto la nota finale nella fixture. Diagnosi causa in corso, nessuna correzione app autorizzata implicitamente.

**QA-004 run corrente:** [42015355697](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42015355697), focused/dashboard su 8bba1c6, ripete il test con gesto confinato sopra tab; esito pendente.

**QA-004 run 42011651611:** 275 unitari e 5/6 UI passati; Dashboard/Salute standard e grandi e Bloom standard verificati visivamente. Bloom grande inconcluso: il gesto del test ha selezionato la tab Attività; corretto test confinando il drag sopra la barra senza ridurre assert, ripetizione necessaria.

**QA-004 ripetizione:** run [42011651611](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42011651611), focused/dashboard su 5601cb7, avviato con selettore Bloom robusto; esito pendente.

**QA-004 run 42009421635:** 275 unitari e 5/6 UI passati. Dashboard/Salute testo grande e prova standard inclusa Bloom riuscite; test Bloom testo grande interrotto perché XCTest ha perso identifier dello scroll. Selettore del test reso robusto senza eliminare assert su ultima nota, posizione e apertura; ripetizione necessaria.

**QA-004 verifica:** run [42009421635](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42009421635), focused/dashboard su commit 54f287b, avviato. Include test standard e testo grande su Dashboard, Salute e Bloom. Esito pendente.

**T11 blocco dispatch:** workflow finale non registrato sul ramo predefinito; tentativo fast-forward main rifiutato da revisione automatica per rischio di modifica diretta al ramo principale. Nessun push main, deploy o IPA. Continuano prove indipendenti sul ramo codex/revision77; approvazione necessaria per avanzare main.

**Collaudo finale in preparazione:** aggiunti test UI diagnostici per ultimo contenuto sopra tab bar (standard/testo grande) e separati i simulatori del ciclo Release per avvio fresh e sessione sintetica. Verifiche locali sintassi Python/selettore passate; comportamento iOS e quattro avvii non ancora eseguiti sul nuovo workflow. Nessuna IPA.

**QA-013 verificata al simulatore:** run [42005224764](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42005224764), commit 6833eb6, compilazione, 275 unitari e 7 UI passati. Frame accessibile pillole 44pt, elemento unico/label, tap al bordo e importazione/persistenza sintetica passati. Screenshot confrontato: aspetto pillole conservato. Verifica su iPhone e accettazione prodotto restano pendenti.

**Verifica Bloom:** run [42005224764](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42005224764) focused/bloom, sorgente 6833eb6, avviato; esito pendente.

**QA-013 correzione compilazione:** sostituito modifier `.accessibilityFrame` non disponibile con `contentShape(.accessibility, Capsule())`; effettiva compilazione e frame AX ancora da verificare.

**Run 42004075338:** commit ea5a71e, compilazione fallita: SwiftUI View non espone `.accessibilityFrame`; nessun test eseguito. Diagnosi e correzione in corso. QA-013 non risolto; nessuna IPA.

**Verifica Bloom QA-013:** run [42004075338](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42004075338), focused/bloom su ea5a71e, avviato; controlla frame, unicità, tocco e import. Esito pendente.

**QA-013:** secondo intervento usa geometria della pillola per il frame accessibile, senza modifica visiva. Prima correzione non efficace nel run 42000813725; seconda ancora da compilare/verificare al simulatore.

**Run 42000813725:** commit d2dbe6b, 275 unitari e 26/27 UI passati. Salute QA-014: test passati, screenshot titoli non spezzati; accettazione utente e dispositivo fisico pendenti. Bloom QA-013: tap al bordo passato, frame AX ancora 18pt anziché 44; prima correzione non efficace, nuova diagnosi in corso. Calendario passato. Nessuna IPA.

**Verifica Salute/Bloom:** run [42000813725](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42000813725) focused/all su d2dbe6b, avviata; esito pendente. Il run Bloom 42000362118 è stato annullato prima della compilazione per unificare controlli. QA-013 e QA-014 non ancora verificate al simulatore.

**Preview Bloom 41998067334:** commit e9eb9dd, 20 test unitari e 2 UI Bloom passati. Il selettore preview non include test frame AX/picker/bordo: verifica focused Bloom successiva necessaria. QA-013 ancora aperto, nessuna IPA. QA-014 Salute non coperto da questa run.

**QA-013 e QA-014:** approvate correzioni Bloom (solo frame accessibile, aspetto invariato) e titoli Salute; modifiche preparate, verifica simulatore pending.

**QA-014:** utente ha approvato correzione titoli Salute; intestazioni aggiornate con titolo e data su righe distinte. Compilazione e resa visiva ancora da verificare. QA-013 Bloom in attesa scelta dopo visualizzazione della schermata reale.

**Run 41948496725, bfca462:** compilazione e 275 unitari passati, 26/27 UI passati. Calendario corretto passato. Bloom: tap a 21pt dal centro risponde, ma frame accessibile Libreria misura 18pt contro requisito 44pt; test import si ferma prima del picker. Correzione proposta, in attesa di risposta. Nessuna IPA.

**Audit Finanza live:** run [41949645412](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41949645412), commit 2bb3f94, passato con `LIFEOS_BACKEND_AUDIT_ONLY=1`: lettura settings/sorgenti e confronto patch guardata, 3 test trasformazione passati; nessun record finanziario interrogato né deploy. Non dimostra comportamento o importi reali né parità integrale Worker.

**Run corrente 41948496725:** focused/all su bfca462, avviato per test calendario aggiornato e diagnosi target Bloom; esito pendente. Non equivale a verifica finale o IPA.

**Run 41944119975, commit 4f920f9:** compilazione e 275 unitari passati, 24/26 UI passati. QA-012: nuovo test testo grande+tastiera passato e screenshot EFC67C7C verificato, calorie e bottone separati; accettazione visiva utente e prova iPhone pendenti. Fallimenti UI: test Calendario antecedente alla correzione bdb2749; Bloom misura frame accessibile 18pt contro 44pt, causa da distinguere dalla dimensione touch reale. Griglia Salute verificata al simulatore ma titoli spezzati: correzione visiva proposta, approvazione pendente.

**Run 41944119975:** commit 4f920f9, compilazione riuscita; 26 UI con 2 fallimenti, di cui uno nella suite Salute. Identità e cause in analisi: log completo nell’artefatto non ancora letto. QA-012 non dichiarato risolto.

**Backend sintetico, 5 novembre:** 19/19 test Attività/movement-order passati su SQLite in memoria e bundle locali build-68/build-70; nessuna verifica live. Test calendario aggiornato nel commit bdb2749 per espandere la giornata prima di controllarla; ancora da eseguire su simulatore.

**Verifica corrente:** run [41944119975](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41944119975), focused/all, commit 4f920f9, avviato; esito pendente. Comprende la correzione QA-012, il test Salute aggiornato e la regressione calendario. Run precedente 41940411529: 272 unitari e 20 UI passati, 2 UI falliti; diagnosi calendario in corso.

**Run Salute 41940411529:** sorgente 5bf5f5e, compilazione passata; suite UI 22 test con 2 fallimenti, suite NativeRevision78UITests 4/4 passati. Cause in analisi tramite artefatti; nessuna accettazione visiva o prova fisica. QA-012 successivo, non incluso nel run.

**QA-012:** correzione della sovrapposizione e test UI aggiunti su richiesta utente; ipotesi da verificare al simulatore, non ancora dichiarata risolta.

**Salute T08/T09:** prima implementazione sul commit 5bf5f5e, anteprima simulatore run 41940411529 in corso. Lettura macro, griglia e cronologia sono implementate ma non ancora verificate. Nessuna IPA o deploy.

**Nutrizione, verifica visiva:** run 41894390397: 272 unitari e 5 UI passati, incluso retry accessibile. Screenshot del pannello con tastiera e testo grande mostra possibile sovrapposizione del bottone al riepilogo calorie: QA-012 aperto. Video non analizzato; nessuna accettazione visiva o prova fisica.

**Verifica nutrizione:** run [41894390397](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41894390397), sorgente d420384, concluso con successo: compilazione, test focused ed esportazione prove riusciti. Le schermate e il video non sono ancora stati riesaminati in questa sessione; accettazione visiva e prova HealthKit fisica restano aperte. Nessuna IPA.

**Salute:** HEALTH-GRID-02 confermata: griglia 2×2, nutrienti 1×4, pulsanti affiancati come seconda anteprima, senza testo e con icone esistenti. Deroga G08/G09/G12/G13 limitata al riepilogo. Implementazione e prove ancora da fare.

**Nota cronologica superata:** run focused nutrizione [41894390397](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41894390397), sorgente d420384, avviato; esito non ancora verificato. Anteprima proposta Salute: [contratto](HEALTH-GRID-PREVIEW.md) e [immagine](design/health-grid-proposal.png); conflitto HEALTH-GRID-CONFLICT-01 in attesa di conferma esplicita. Nessuna modifica Salute autorizzata dalla sola anteprima.

**Verifiche del reparto:** 35/35 test sintetici Finanza passati con `manual/build-75/worker.js` per entrambe le baseline; il primo tentativo con budget build-70 ha avuto 5 fallimenti per baseline precedente. Nessun audit live o deploy. Aggiunto test Bloom esplicito per la scelta mantieni: compilazione e verifica simulatore ancora da eseguire.

**T01 in verifica:** selettore esteso ad attività/calendario/turni, runner macos-15 scelto dopo probe; pipeline finale manuale completa senza packaging aggiunta, non ancora eseguita. Il push di questo checkpoint usa [skip ci] per evitare preview duplicata: segue una sola verifica focused nutrizione sul commit preciso. Il trigger automatico resta attivo per i successivi push. SDK/runtime 26.2 non equivalgono alla prova di riferimento iOS 27.

**Audit preparatori:** in Salute zero viene oggi scartato e il forecast usa intervalli di 86400 secondi; test su nil/zero e date civili necessari prima di dichiarare T08/T09 verificati. Bloom ha copertura sintetica import/riavvio/copy/replace; restano da provare keep esplicito, ricerca/fissati/categorie, mappa, crop/pager, filtri Riscopri e Intent reale. Nessun backup privato letto.

**Audit preparatorio T06:** test sintetici locali competenza 7/7 passati il 4 novembre 2026 (`node --test backend/utilities/tests/competence.test.mjs`); include 221,79/3 e controlli unicità. Nessun audit live eseguito e T06 resta aperto; E10 personale non dimostrato.

**Capacità CI aggiornata:** run 41873100610 tentativo 2 riuscito su macos-15-arm64, Xcode 26.3, SDK/runtime iOS 26.2. È una prova di disponibilità runner, non un test dell’app; il retry nutrizionale resta non verificato.

## Aggiornamento operativo — piano approvato, 4 novembre 2026

Il piano completo è autorizzato ed è in corso: [piano](PROJECT-RELEASE-PLAN.md), [copertura](REQUIREMENT-COVERAGE.json), [manifesto](EXECUTION-MANIFEST.json). I precedenti passaggi che indicano solo pianificazione o accettazione Bloom pendente sono storici e superati. Bloom è accettato visivamente, non per produzione; retry nutrizione resta non verificato; IPA 78 non accettata. Nessuna nuova IPA né deploy autorizzati. T07 prevede anteprima e conferma dei conflitti prima della modifica di Salute.

## Mandato Astra aggiornato — piano dell’intero progetto

L’utente richiede il piano completo di tutte le modifiche mancanti fino all’IPA finale, non solo Salute. Leggere [PROJECT-PLAN-BRIEF.md](PROJECT-PLAN-BRIEF.md); il brief Salute è un allegato. Includere una proposta di task per Terra e sottoagenti con modelli economici, verificando costi e capacità reali. Nessun agente avviato o configurato da questo aggiornamento, nessuna implementazione e nessuna IPA autorizzate.

## Passaggio pianificazione Salute — 4 novembre 2026

Nuovo obiettivo HEALTH-UX-01: Salute per bodybuilding, dati immediati e minimo attrito. Aggiornamento documentale autorizzato, nuovi inserimenti/database NON implementati o approvati. Leggere [checklist unificata](PROJECT-CHECKLIST.md) e [brief Astra → Terra](HEALTH-BODYBUILDING-BRIEF.md): distinguere obiettivo fermo, layout/catalogo non vincolanti e conflitti da confermare. Nessuna nuova chat creata automaticamente, nessuna IPA.

Ultimi controlli 41871989512 e 41873100610 terminati senza runner assegnato: annotazioni GitHub confermano capacità macOS arm64 insufficiente, nessuno step eseguito. I riferimenti «in coda» nelle note cronologiche sotto sono superati da questo aggiornamento; nessun nuovo test avviato per il passaggio.

## Incremento corrente — nutrizione rapida (4 novembre 2026)

NUTRITION-DIRECT-01: render approvato con «ok approvo», implementazione autorizzata. Dashboard con solo pulsante Nutrizione; foglio con proteine/carboidrati/grassi/fibre effettivi, calorie automatiche e data. Il flusso per 100 g è sospeso; storico non migrato. Fonte e prove: [NUTRITION-QUICK-REVIEW.md](NUTRITION-QUICK-REVIEW.md).

Compilazione riuscita, 271 unitari e quattro UI passati nel run 41853040353; un UI accessibilità fallito nella ricerca del campo disabilitato. Video nativo mostra valori conservati, errore e Riprova visibili, foglio aperto dopo scroll. Il run 41856609394 è terminato senza runner assegnato e senza eseguire test (annotazione GitHub: “The job was not acquired by Runner of type hosted even after multiple attempts”). Anche 41859714562 è terminato senza runner acquisito, nessun test eseguito. Workflow sviluppo spostato su macos-26 standard, mantenendo il selettore compatibile già esistente; verifica 41871989512 sul commit cad0a7b5 in coda. Nessuna IPA autorizzata (IPA-GATE-01). Non dichiarare ancora completato il retry di questa versione. Nessuna nuova IPA, nessun deploy, nessuna verifica HealthKit su dispositivo fisico. Il render approvato non costituisce accettazione dell’implementazione.

Aggiornato il 4 novembre 2026. Questo documento prevale come riepilogo di stato sui vecchi handoff e sui rapporti cronologici. Le istruzioni dell’utente restano nel registro delle decisioni.

## Valutazione del prodotto

**Build 78 distribuita; non accettata dall’utente per la produzione.** Le foto del telefono mostrano difetti che la precedente verifica non ha coperto adeguatamente: griglia Bloom con card fuori colonna/sovrapposte, modulo nutrizione ingombrante e poco riconoscibile, gerarchia/contesto da correggere. I test verdi non chiudono questi problemi.

## Codice, artefatto e prove

| Campo | Stato |
|---|---|
| Sorgenti app correnti | `native-next/`; Bloom con anteprime verificato e accettato visivamente; nutrizione rapida implementata, verifica recupero accessibilità in corso |
| Versione app e widget | 0.10.17 / 78 |
| Commit sorgente IPA | `33574a2114ea6e0d378f69d06aadf60378cf55e9` |
| Commit attuale repository | Leggere HEAD; include anche regole e report, non una nuova build |
| Validazione | [41721041653](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41721041653), riuscita |
| Prove | 267 unitari, 15 UI, 4 avvii Release; iPhone 15 Pro simulato, SDK/runtime 27.0 |
| Firma e telefono reale | Rifirma Signulous; nessuna prova fisica eseguita dall’agente |
| Artefatto | [Release build 78](https://github.com/azeroualit-cloud/LifeOS/releases/tag/ios-0.10.17-build78) |
| SHA-256 IPA | `d281d9d885ea4cc221022d3c52bf3fe00b876f77273821867d617a2be2b911e7` |
| Accettazione per produzione | **NO — rifiuto esplicito dell’utente** |

## Che cosa è stato effettivamente osservato

- L’utente ha mostrato importazione di 122 note completata. Questo non certifica da solo la parità di ogni contenuto/allegato con l’app Bloom originale.
- La prova UI sintetica copre File → anteprima → importazione → riavvio e dato ancora visibile; non copre sufficientemente una libreria eterogenea di 122 elementi.
- La build 78 includeva il modulo per 100 g; quel flusso è ora sospeso e sostituito nel sorgente dall’inserimento diretto approvato. Restano le altre correzioni da approvare separatamente.
- I concept generati dopo la consegna sono proposte visive: non sono stati implementati come nuova versione dell’app.

## Backend e web

L’ultimo deploy utenze documentato è il run 41630715615, riportato in [REVISIONE-77](native/REVISIONE-77.md). Questo aggiornamento non riesegue un audit live e non distribuisce Worker. La corrispondenza integrale fra `web/worker.mjs` e produzione non è stabilita: non effettuare deploy da una baseline presunta.

## Prossimo lavoro e fonti

Leggere [difetti aperti](OPEN-ISSUES.md), [regole attive](USER-DECISIONS.md), [report di passaggio](AI-HANDOFF.md) e [architettura/flussi](ARCHITECTURE-CURRENT.md). Le 238 voci storiche distinguono richieste dirette, ricostruzioni e proposte; non sono tutte requisiti attivi né tutte correzioni ancora da fare.

Lo [storico di stato fino alla build 76 e precedenti](STATUS-HISTORY-2026-11-04.md) è conservato senza usarlo come stato attuale.

## Ciclo CI separato

Implementati anteprima automatica e verifiche mirate manuali, con screenshot e selezione test tracciabile. Il percorso completo IPA è manuale; pipeline native storiche sovrapposte non partono più a ogni push. Nessuna modifica al codice app o ai deploy. Prima anteprima [41800947855](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41800947855) passata: 11 test UI, 0 errori, 21 screenshot esportati; durata 20m39s. Cinque test locali della selezione e lint dei workflow passati. Focused e IPA completa non rieseguiti. Nessun difetto grafico dichiarato chiuso. Leggere [DEVELOPMENT-CYCLE.md](DEVELOPMENT-CYCLE.md).

## Correzione approvata Bloom H-GRID-01

Due colonne indipendenti con larghezza esplicita, immagini proporzionate e anteprime link tramite LinkPresentation (cache separata dalle note, fallback e timeout). Fixture sintetica di 122 contenuti misti; verifiche standard/testo grande previste. Stato: verificata al simulatore su fixture sintetica, accettazione visiva utente pendente. Ultima IPA invariata.

Verifica Bloom finale: run 41816351684 passato, 19 unitari e 4 UI senza errori, 16 screenshot esportati. Catture standard e testo grande controllate. Prove e limiti in [BLOOM-GRID-REVIEW.md](BLOOM-GRID-REVIEW.md). Accettazione pendente.

Aggiornamento 4 novembre: risultato visivo H-GRID-01 accettato tramite «ok, procediamo con la prossima correzzione». Prossima proposta: riconoscibilità e compattezza del modulo nutrizione in Dashboard; non ancora approvata né implementata. Accettazione globale per produzione invariata.

## Quick add nutrizione approvato

Render approvato, implementazione del pulsante + Nutrizione → pannello con quattro totali in grammi e kcal automatiche completata per la verifica. Storico mantenuto; nuovo inserimento per 100 g sospeso anche nell’editor Salute. Stato: compilazione/QA pending. Dettagli in [NUTRITION-QUICK-REVIEW.md](NUTRITION-QUICK-REVIEW.md). Nessuna nuova IPA o deploy.
