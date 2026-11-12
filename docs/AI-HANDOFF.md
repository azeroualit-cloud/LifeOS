# LifeOS — punto di ingresso per qualsiasi IA

**Collaudo finale senza IPA in corso:** [43178362187](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43178362187), commit `7087d91a2f8386281c157c4a80133ece0c105584`. Due job: suite e quattro avvii Release. Packaging e pubblicazione esclusi dal dispatch.

**Prova mirata conclusa:** [43176199615](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43176199615), sorgente `d91aa380d821498cb7722639c0489a2d3318c59c`: 288 unitari e 4 UI passati, zero fallimenti. Ispezionate catture del riferimento Apple Salute (2.200 kcal, 80 kg) e palette standard/grande. Il candidato aggiunge soltanto una protezione alla ricerca dei processi non avviati e salta tale ricerca se la fixture è già pronta; nessun sorgente prodotto modificato. Prossimo gate: singolo workflow manuale lifeos-validate80 con suite completa e quattro avvii Release. Su workflow_dispatch package89/publish89 sono esclusi dalle condizioni evento push.


**Checkpoint 12 novembre — collaudo senza IPA.** [Prova mirata 43176199615](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43176199615) sul commit `d91aa380d821498cb7722639c0489a2d3318c59c`, in corso. Verifica locale: 8 test selettore, 36 test sintetici Finanza/Utenze, 3 test trasformazione Worker e integrazione Attività passati. Gli iniziali errori locali erano dovuti al Worker storico predefinito e alla codifica Windows: con Worker75 rigenerato e UTF-8 i controlli passano. Nessun dato personale interrogato e nessun deploy.

## Candidato finale — nuova chat del 12 novembre 2026

Questa sezione prevale sulla cronologia. Nessuna IPA autorizzata in questa chat e nessun deploy backend. Registro: FINAL-CANDIDATE-2026-11-12. Audit per tutte le aree in [checklist](PROJECT-CHECKLIST.md) e [piano](PROJECT-RELEASE-PLAN.md).

Checkpoint iniziale remoto verificato: codex/revision77 `6a8826d4e1334935798dc9e909449621c013984e`, main `1b80e58e85adfd23cb3f8c38012def651295bee3`. Nessun lavoro locale pendente iniziale né run CI in corso. Il vecchio `2d33d8a` è storico.

Diagnostica acquisita dal run 43113799496 sul commit `db6d6f5e03e4d5cd5bf1dca850372d50063345b6`: 299 test, 298 passati, 1 fallito, zero saltati; suite restante non eseguita. Quattro avvii Release passati. La cattura seed-permission-diagnostic mostra il dialogo Health con Dietary Energy e Weight, mentre l’albero LifeOS non espone interruttori. La fixture resta in request-authorization con permessi not-determined. Il test ora cerca il foglio anche nei processi HealthPrivacyService e SpringBoard, conserva la verifica dei due permessi e dei valori finali. Prova mirata nel contesto di tutti gli unitari prima del collaudo completo, senza packaging.

Non è un nuovo difetto di prodotto dimostrato: cambia solo il test. Restano revisione utente, parità personale Bloom/Finanza, HealthKit fisico, App Group/widget, AlarmKit/suono e accettazione.


**Aggiornamento verificato 12 novembre 2026 — [handoff per nuova chat](HANDOFF-2026-11-12.md).** L’ultimo tentativo build 89, [run 43113799496](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43113799496), è fallito nel preflight Apple Salute: `The Health authorization dialog did not become ready` (`NativeRevision78UITests.swift:408`). Quattro avvii Release passati; confezionamento e pubblicazione saltati. Nessuna IPA 89 da questo tentativo. Il timeout iniziale resta da diagnosticare tramite lo snapshot della fixture; i precedenti test mirati verdi non dimostrano che sia risolto. Le note successive sono cronologia precedente.

**Palette turni, integratori e caricamento artefatti.** La [suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43094447884) e i quattro avvii Release sono passati; il rilascio è stato bloccato dal servizio upload artefatti GitHub (risposta HTML al posto di JSON). Aggiunto un secondo tentativo di upload senza nascondere un eventuale secondo errore. Nuova palette turni a due colonne, una nelle dimensioni accessibili, nomi completi e orari; integratori generici in Tutti, con Personali separato. Le 11 composizioni generiche dichiarano esplicitamente la dose e usano valori indicativi, modificabili creando una voce personale. Il collaudo mirato include Apple Salute, porzioni, integratori e modifica/annullamento dei turni con testo normale e grande. Il [collaudo mirato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43107365710) ha superato 14 test unitari e 4 UI. Ispezionando le immagini sono emersi nomi spezzati nella palette; La palette normale a due colonne è verificata nel run 43109687303. Il caso con testo grande ha fallito all’apertura; ora usa una colonna e nessuna animazione di inserimento per evitare il blocco osservato. [Verifica mirata](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43111876770) passata: entrambi i test calendario e catture ispezionate. La produzione esegue tutti gli unitari e i percorsi fragili prima del resto della suite, evitando duplicazioni tramite la lista preflight.

**Revisione supermercato e integratori, 11 novembre.** Catalogo ampliato da 209 a 280 voci senza marche. Valori Ciqual 2025, con crescenza da [CREA](https://alimentinutrizione.it/tabelle-nutrizionali/160890). Gli integratori personali usano valori per dose, con zero calorie ammesse e micronutrienti opzionali. Salute conserva selezione giornaliera e storico, con ritorno Oggi. Il log completo del [test precedente](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42611075782) mostra entrambi i valori attesi nel Riepilogo: il solo errore era l’attesa iniziale di 20 secondi. Il test ora attende fino a 60 secondi, interrompe in caso di errore e limita gli alberi diagnostici alle anomalie. Il [collaudo iOS](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43084986627) ha superato 11 test UI, inclusi integratori, catalogo e storico. Corrette due condizioni emerse: rifiuto di energia zero con macro nonzero e posizione ripristinata nell’editor di Apple Salute. Nel [collaudo mirato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43089261061) sono passati tutti i 13 test nutrizionali e il salvataggio dell’integratore. Apple Salute è ancora bloccante: lo scorrimento verso l’alto ha chiuso il foglio. Il [nuovo controllo](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43091973393) arresta il gesto alla prima riga visibile. Il [collaudo finale](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43091973393) ha superato tutti i 13 test nutrizionali, il salvataggio dell’integratore e il test Apple Salute con 2.200 kcal e 80 kg nel Riepilogo. [Produzione build 89 in corso](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43094447884) con gate completi. Catture reali di catalogo, dosi e storico acquisite; prova fisica aperta.

**Build 89 (0.10.27), [secondo tentativo fallito](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42587960947).** Il [primo collaudo](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42578884079) ha completato quattro avvii Release e ha avuto un solo errore UI: il test storico di Bloom cercava ancora Riscopri. Il test ora verifica le sezioni approvate e la persistenza delle note. Viene eseguito per primo nel collaudo pre-IPA. Pacchetto e pubblicazione sono stati saltati nel primo tentativo. Il secondo collaudo ha superato Bloom e quattro avvii Release. L’unico test fallito è la cattura di Apple Salute, che non ha trovato i due elementi tramite la ricerca del sistema. La [verifica isolata](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42601587539) ha mostrato il rifiuto del permesso di scrittura delle calorie, prima della ricerca. Il test ora verifica lo stato dei due interruttori prima di confermare e interrompe la prova se il salvataggio non riesce. La [seconda prova isolata](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42604652862) ha confermato il salvataggio e si è fermata alla chiusura forzata del processo. Il test ora passa direttamente ad Apple Salute. Il [preflight successivo](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42607730011) ha mostrato le 2.200 kcal attese nel Riepilogo dopo il tap. L’asserzione intermedia sullo stato della riga nell’editor ha comunque interrotto il test. La correzione verifica l’esito nel Riepilogo con i valori attesi di calorie e peso. La pipeline di pubblicazione attende il nuovo collaudo mirato.

**Salute, Dashboard, catalogo e Bloom.** Checklist 9 novembre implementata su `codex/revision77`. Compilazione e 38 test unitari più 9 UI superati al simulatore iPhone 15 Pro sul commit `78578ab` ([collaudo](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42573602745), [catture e filmato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42573602745/artifacts/13654668637)). Il commit `a922361` aggiunge solo fixture DEBUG, selezione CI e un test UI passato per Diario storico, classifica alimenti e omega-3 ([catture aggiuntive](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42575533916/artifacts/13656015393)). Verificati a vista anche testo grande e scorrimento in entrambe le direzioni. L’utente ha autorizzato la pubblicazione della build 89 dopo aver ricevuto i render. La prova su iPhone resta aperta.

Le barre usano riferimenti per uomini adulti da [SINU LARN V](https://sinu.it/wp-content/uploads/2025/07/Tabelle-riassuntive_online.pdf), [EFSA per il potassio](https://www.efsa.europa.eu/en/press/news/161025) e [EFSA per omega-3](https://www.efsa.europa.eu/sites/default/files/2017_09_DRVs_summary_report.pdf). L'avviso indica un apporto registrato sotto il fabbisogno medio LARN di vitamina C, zinco, ferro, calcio, B2 o B6. Si attiva a settimana conclusa, con sette giorni di valori per tutte le voci e senza stime. Per gli altri nutrienti restano visibili i progressi. Le medie escludono giorni senza dati e la simulazione usa gli ultimi sette giorni conclusi.

**Build 88 (0.10.26), IPA pubblicata.** Calendario Giorno aggiornato, puntini nel Mese, Salute e Nutrizione. Suite completa, quattro avvii Release, pacchetto e checksum verificati sul commit 5be4038. [Scarica LifeOS-88.ipa](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.26-build88/LifeOS-88.ipa) · [Collaudo e pubblicazione](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42523292569). Firma Signulous e prova su iPhone da eseguire.

**Calendario Giorno.** Variante grafica per revisione con data a sinistra, turno in pillola, superficie Agenda unica, colori limitati ai marcatori e azione Liquid Glass sopra la navigazione. Catture reali standard e testo grande disponibili. Primo collaudo 4/5, una disuguaglianza sui bordi del test è fallita per circa 0,00001 pt. Correzione della tolleranza verificata nel [collaudo mirato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42522498757). [Catture e diagnostica](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42521276245/artifacts/13633628333).

**Calendario Mese.** Implementato un puntino per evento, tre per riga, con conteggio leggibile da VoiceOver. L’utente chiede una proposta grafica per la vista Giorno, da valutare a parte. Due test UI passati su e9fd592, inclusi cinque eventi su due righe e ritorno alla stessa settimana. [Schermate reali](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42520092685/artifacts/13633108552).

**Nutrizione, revisione simulatore.** Sorgente con 30 cocktail, consumo stimato per bicchiere, alimenti personali locali, 209 alimenti generici e 18 opzioni compatibili con pesatura con osso. Apple Salute riceve unità alcoliche (12 g/UA), folati in massa e vitamina K totale quando entrambi i componenti sono disponibili. ALA, EPA e DHA restano in LifeOS. L’utente ha escluso la creatina e ha chiesto schermate reali prima di decidere sull’IPA. Compilazione, 16 test unitari e 3 test UI superati sul commit cc6a240. Sei schermate reali esportate. Verifica Apple Salute su dispositivo ancora aperta. [Collaudo](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42516427060) · [Catture simulatore](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42516427060/artifacts/13631976991).

**Tempi IPA.** Pilota approvato e implementato su codex/revision77. Nel workflow LifeOS development preview and focused checks, mode=trial seleziona test a partire dal sorgente dell’ultima build distribuita e verifica un avvio Release pulito. Per il pilota, solo Salute e Nutrizione hanno una mappa ristretta. File condivisi o sconosciuti richiedono suite completa. L’opzione package_trial predefinita a false attiva un artefatto unsigned solo con richiesta esplicita sul ramo di lavoro. Il flusso di produzione conserva i gate completi. Prima misurazione end-to-end da eseguire.

**Collaudo IPA.** La build 87 ha superato 375 prove e quattro avvii Release. Tre test Nutrizione falliscono sul campo Fibre a testo accessibile con tastiera aperta, come nelle build 85 e 86. La suite seriale della 87 è durata circa 65 minuti. La correzione libera spazio di scorrimento nel foglio accessibile e migliora la diagnosi del test. La pipeline anticipa i tre casi e rimuove la doppia esecuzione delle prove di layout Salute. Copertura completa e gate IPA conservati. [Verifica mirata](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42509002706) sul commit b64edfa. La compilazione è passata, poi tre prove hanno rilevato Carboidrati da 1 a 4 punti oltre il limite dopo gli swipe. Il test ora trascina nel margine per evitare l’interazione con i campi e allega la schermata in caso di errore; La [seconda verifica mirata](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42510268817) sul commit 1c29dda è passata, inclusi i tre casi di Nutrizione. [Diagnostica build 87](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42501436059/artifacts/13628795850).

**Build 87 (0.10.25).** Vitamina C e zinco sotto i macro nella schermata Salute, con obiettivi giornalieri LARN per uomini adulti. La consegna IPA già richiesta include la correzione dopo il collaudo iOS. [Run CI](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42501436059) sul commit 42d083d.

**Build 86 (0.10.24), rilascio autorizzato.** Aggiunge vitamina C e zinco in primo piano in Salute → Micronutrienti, dettaglio consultabile, riferimenti per profilo, copertura del diario e scrittura Apple Salute per i valori supportati e autorizzati. La pipeline richiede suite completa, quattro avvii Release e verifica dell’IPA prima della pubblicazione. [Collaudo e pubblicazione](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42498975363) sul commit `d3f94e9`.

**Build 85 (0.10.23), rilascio autorizzato.** Include la vista Giorno con ritorno diretto al Mese, il catalogo senza maiale con piatti marocchini, la pesatura con osso e gli aggiornamenti visivi del ramo corrente. Pubblicazione su GitHub Releases dopo suite completa, quattro avvii Release e verifica del pacchetto. [Collaudo e pubblicazione](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42496148533) in corso sul commit `646e708`.

**Agenda Giorno.** L’utente ha scelto la lista compatta e richiesto il ritorno diretto al Mese. Implementati apertura da mese o striscia Dashboard, frecce, turno, sezioni dell’agenda e Aggiungi evento in basso. Mese resta alla posizione originaria. [Collaudo iOS](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42495836333) sul commit `444f31d`.

**Catalogo halal e marocchino.** Escluse nove voci di maiale o con carne non identificata. Aggiunte tredici voci, comprese varianti di couscous, tajine e pastilla. Sette voci supportano il peso con osso con stima edibile. [Verifica iOS](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42494307645) sul commit `20ea12b`. L’utente ha respinto il foglio proposto per l’agenda del giorno.

**Revisione post build 84.** Prima tranche nel sorgente: 188 alimenti Ciqual e icone per famiglia, Calendario mensile e Dashboard, pulsanti Categorie di Attività in Liquid Glass, contrasto e tastiera del pannello Nutrizione, bordi e padding di Salute. [Verifica simulatore](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42493721112) in corso su `b7bb685`. La [proposta per agenda e dati nutrizionali](CALENDAR-NUTRITION-NEXT.md) dettaglia i passaggi aperti.

**Build 84 (0.10.22).** Suite completa, quattro avvii Release e pacchetto verificati sul commit `d31c640`. La creazione della release GitHub ha restituito HTTP 403. [Artefatto Actions con IPA e checksum](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42491009239/artifacts/13624595609).

**NUTRITION-DATE-CLIP-01, 8 novembre 2026.** Il calendario era tagliato su iPhone, anche nel flusso con «Cerca alimento». La correzione approvata apre Data in un foglio a tutta larghezza con Fine e Annulla e conserva i nutrienti inseriti. Registrata la [regola UX-DATE-PICKER-01](USER-DECISIONS.md#ux-date-picker-01--active-8-novembre-2026). [Verifica al simulatore](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42481363683) superata sul commit `c2c7e8b`, con testo standard e grande. Prova su iPhone ancora aperta.

**Build 83 (0.10.21), IPA pubblicata.** [Download diretto](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.21-build83/LifeOS-83.ipa). Suite completa, quattro avvii Release e verifica pacchetto superati nel [run 42404491236](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42404491236) sul sorgente `75a9af4`. SHA-256 `a7449e22405809d93e01f02298e87addcc6be172f6a8fed3489115d21bd14cd4`. Firma Signulous, prova iPhone e accettazione aperte.

**Catalogo alimenti generici, 7 novembre 2026.** Il sorgente contiene 145 voci italiane Ciqual 2025, barra «Cerca alimento» con lente e «Generic» sotto Biscotti. Catalogo e layout Salute condividono il [collaudo iOS](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42387125517) sul nuovo sorgente. Il [run precedente](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42386785838) è stato annullato dalla CI quando è arrivato il nuovo commit. Lo spostamento delle azioni Salute è [approvato](USER-DECISIONS.md#health-actions-bottom-01--active-7-novembre-2026) e implementato nel sorgente. I due pulsanti restano sopra la barra di navigazione durante lo scroll. Compilazione e test selezionati passati al simulatore sul commit c930a9f. Le prove includono la ricerca di Biscotti, la porzione e i pulsanti Salute con testo standard e grande. Verifica su iPhone ancora aperta.

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

**Ultimo checkpoint:** errore data calendario corretto con approvazione e verificato al simulatore, run 42116279080 (7 unit e UI calendario passati). Collaudo finale completo dopo questa correzione e avvii Release ancora necessari; nessuna IPA autorizzata.

**Aggiornamento ultimo:** calendario visualizza 4 novembre per evento del 5 con simulatore GMT (run 42109968064), dato in agenda al 5; fix prodotto richiede approvazione DEV-02. Apple Health reference superato nel run 42113026579 dopo precedente errore consenso. Suite finale 364/367 nel run 42094752571; avvii Release saltati. IPA non autorizzata.

**Stato operativo aggiornato, 5 novembre 2026:** il piano è in esecuzione; Salute e le correzioni approvate sono implementate, con prove al simulatore descritte in STATUS. Nutrizione retry e Bloom accessibilità hanno prove automatiche riuscite; accettazione utente e prove fisiche restano aperte. Main aggiornato con autorizzazione utente; collaudo finale 42060601929 fallito su 25/92 prove UI, 275 unitari passati e avvii Release non eseguiti; diagnosi e test storici in corso. QA-004 compatto superato al simulatore nel run 42056808149; spazio visibile Bloom molto ridotto con testo grande, da rivedere. Consultare STATUS per gli esiti più recenti; le sezioni successive riportano anche storia superata. Nessuna IPA o deploy autorizzati.

Aggiornamento 5 novembre: run focused nutrizione 41894390397 passato, dettagli in STATUS; revisione video e prova fisica restano aperte. HEALTH-GRID-02 approvata con eccezione limitata al riepilogo; implementazione in corso, nessuna IPA o deploy. Le sezioni precedenti su retry non verificato e conferma Salute pendente sono storiche.

T01: pipeline finale manuale senza IPA e selettore attività/calendario/turni in verifica; consultare STATUS per prova runner e stato esatto. La suite finale non è stata eseguita.

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

Aggiornato il 4 novembre 2026. Leggere prima di pianificare o modificare il progetto.

## Ordine di lettura

1. `../AGENTS.md` — istruzioni del progetto e obbligo di conferma sui conflitti.
2. `USER-DECISIONS.md` e `.json` — META-01/META-02 e regole utente ACTIVE.
3. `STATUS.md` e `BUILD-STATE.json` — stato effettivo del codice, dell’ultima IPA e dell’accettazione.
4. `OPEN-ISSUES.md` — difetti osservati, verifiche mancanti e criteri di chiusura.
5. `ARCHITECTURE-CURRENT.md` — tecnologie, flussi, dati, build e comandi.
6. `decision-history/2026-11-04-inventory.md` — elenco storico completo con origine e contraddizioni; non sono 238 ordini tutti attivi.

## Manutenzione permanente del report

Non attendere un nuovo promemoria dell’utente: META-01 e META-02 valgono a ogni sessione. Controllare ogni nuovo input, registrare decisioni e conflitti, aggiornare i documenti interessati durante il lavoro. Prima di ogni risposta finale o passaggio di sessione verificare che lo stato documentato sia corrente e che i cambiamenti siano stati sincronizzati e verificati su GitHub. Nessun commit vuoto se lo stato non cambia; nessuna dichiarazione di sincronizzazione se il push fallisce.

## Fatti da non perdere

- L’ultima IPA è 0.10.17 build 78, sorgente `33574a2114ea6e0d378f69d06aadf60378cf55e9`.
- Compilazione, 267 unitari, 15 UI, 4 avvii Release e package verifier sono passati; questi risultati non hanno impedito difetti visibili sul telefono.
- **L’utente ha rifiutato la build come pronta per la produzione.** Non presentarla nuovamente come pronta senza correzioni e prove adeguate.
- Dopo la build sono cambiati documentazione, workflow CI e griglia Bloom con anteprime link (H-GRID-01, approvato). La verifica Bloom al simulatore è passata (19 unitari e 4 UI); accettazione utente pendente; nessuna nuova IPA distribuita e nessun deploy backend.
- `native-next/` è l’overlay canonico; il vecchio ZIP e i vecchi handoff da soli non sono l’app corrente.
- Un concept generato non prova una funzione o un layout reale; le proposte dell’assistente non sostituiscono le istruzioni dell’utente.

## Ambiente effettivamente disponibile

L’utente lavora da Windows e ha dichiarato di non avere Mac locali o remoti. Per iOS si usa il runner macOS GitHub già configurato (`xcode-27`); non presupporre una macchina Mac interattiva disponibile. Acquisto o noleggio non approvati.

Audit del job `126213552095`, run `41721041653`: setup Node 3m15s, compilazione app/test 2m41s, REA 1m33s, suite completa test 12m58s, compilazione Release + quattro avvii 7m56s. Quindi il tempo del ciclo completo non è il tempo puro per compilare l’app. Il ciclo separato è ora implementato: [DEVELOPMENT-CYCLE.md](DEVELOPMENT-CYCLE.md). Prima anteprima verificata nel run 41800947855: 11 UI passati, 21 screenshot esportati, 20m39s. Compilazione da zero 8m36s; nessuna promessa di anteprima immediata. Focused verificato nella selezione locale ma non eseguito su macOS; percorso IPA completo conservato, non rieseguito.

## Come lavorare

1. Leggere regole e stato; verificare branch, HEAD, working tree e remoto. Preservare modifiche di altre sessioni.
2. Registrare il nuovo input. Se contraddice una regola ACTIVE, citare ID/testo e chiedere se sostituirla: attendere la risposta sulla parte coinvolta. Non inventare compromessi.
3. Riprodurre il difetto su contenuti rappresentativi. Una sola nota sintetica non copre la griglia Bloom con una libreria eterogenea.
4. Correggere i requisiti autorizzati. Eseguire controlli pertinenti, verificare schermate dell’app reale, tastiera, scorrimento e testo grande quando coinvolti. Non indebolire gli assert per far passare un’interfaccia rotta.
5. Aggiornare regole, difetti, report e stato della build; distinguere risultati nuovi da prove storiche, pending e limiti.
6. Fare commit e push del lavoro di progetto; verificare lo SHA remoto e rendere tutto rintracciabile da main/README. Se il push è bloccato, segnalarlo senza dichiarare il remoto aggiornato.

La sincronizzazione del repository è autorizzata da META-02; non equivale a un’autorizzazione a distribuire codice ai Worker o pubblicare automaticamente una nuova IPA. Non pubblicare backup, credenziali o dati personali.

## Stato del repository

Ramo predefinito `main`; ramo di lavoro storico `codex/revision77`. Il nome del ramo non indica la build. `main` viene riallineato senza force push alla cronologia corrente, così una IA che clona il default trova anche i sorgenti e questo report. Se in futuro main e ramo di lavoro divergono, il README e STATUS devono indicare chiaramente dove si trova il lavoro corrente; non perdere commit concorrenti.

L’ultimo aggiornamento di documentazione non cambia il fingerprint applicativo della build verificata. Per il commit esatto del repository leggere HEAD, evitando un hash auto-referenziale nel report. Stato macchina in BUILD-STATE.json.

## Storico

I vecchi `HANDOFF.md`, README e rapporti di revisione sono evidenze storiche. Quando divergono dal registro attivo o dallo stato corrente, non usarli per ripristinare una scelta superata o dichiarare risolto un difetto aperto.

## Revisione Bloom corrente

Leggere [BLOOM-GRID-REVIEW.md](BLOOM-GRID-REVIEW.md): H-GRID-01 implementato e in verifica. Run 41813899400: 19 unitari e 3 UI passati, 1 UI fallito per gesto sulla tab bar, corretto nel test; run 41816351684 PASSATO: 19 unitari, 4 UI, 16 screenshot; controllo visivo di standard e testo grande completato. Richiedere accettazione del risultato visivo prima della prossima modifica di prodotto (DEV-02). Nessuna nuova IPA.

## Cronologia delle decisioni — gli stati successivi sostituiscono i precedenti

Le note sotto conservano la sequenza; per lo stato operativo leggere l’incremento corrente in apertura e il registro ACTIVE.

Aggiornamento 4 novembre: risultato visivo H-GRID-01 accettato tramite «ok, procediamo con la prossima correzzione». Prossima proposta: riconoscibilità e compattezza del modulo nutrizione in Dashboard; non ancora approvata né implementata. Accettazione globale per produzione invariata.

Nuovo input NUTRITION-DIRECT-01 in PENDING_CONFIRMATION: quick add con nutrienti effettivi e kcal automatiche, sospendendo per ora percorso 100 g/porzione/kcal etichetta. Conflitto F03–F06: chiedere conferma ai sensi META-01. La precedente proposta di restyling nutrizione non è stata approvata. Non implementare la parte confliggente prima della risposta.

Aggiornamento nutrizione: conflitto NUTRITION-DIRECT-01 confermato, F03–F06 SUSPENDED per ora; nessuna migrazione/cancellazione dello storico. Design del quick add a pannello approvato come idea; ora soltanto render da mostrare immediatamente, poi fermarsi prima di implementare altro. Il precedente pending è risolto. App e build invariati.

## Nutrizione: render approvato e implementazione corrente

L’utente ha approvato il render con «ok approvo». Pannello quick add e inserimento diretto implementati, controlli locali della selezione passati, verifica macOS da avviare. Il precedente stop al render è soddisfatto. Leggere `NUTRITION-QUICK-REVIEW.md`: salvare lo storico senza ricalcolarlo, nessuna nuova IPA. La scelta manuale area nutrition è motivata dall’impatto limitato ai componenti nutrizione e ai relativi test (i nuovi token non cambiano altri componenti); eseguire focused con tutti gli unitari per la persistenza.
