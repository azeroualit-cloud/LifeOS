# Candidato 0.10.28 build 90

Richiesta utente13novembre2026«produci l’ipa»,poi«confermo» sulla correzione catalogo/tastiera. Autorizzati correzione,verifica,confezionamento e consegna. Non richiedere nuovamente queste autorizzazioni per lo stesso ambito. Nessun deploybackend,cancellazione dati o accettazione fisica implicita.

## Contenuto

Sei destinazioni Liquid Glass sempre visibili:Dashboard/Attività/Salute/Bloom/Finanza/Calendario. Host delle schermate stabili per evitare la chiusura del catalogo quando compare la tastiera. Scheda Integratori separata,1000formulazioni di39marchi collaborativi con fonte/licenza,23schede ufficiali separate,CatalogoCoop/Spesotti,unitàg/ml/capsule,modifica personali,cronologia per giorno e icona turni.128voci supermercato alcoliche esplicite nascoste,30cocktaildiscoteca conservati;storico invariato. TDEE sulle2settimane dall’ultima pesata,inclusa,senza minimi arbitrari già verificato.

## Gate e limiti

Nuova pipeline manuale sul ramo codex/revision77,stessoSHA per test e IPA. Compilazione una volta nel job test,prima3UI mirati(navigazione/stati,testogrande/tastiera,catalogo),poi tutte le prove restanti saltando quei3casi. Quattro avviiRelease separati sullo stesso candidato. Packaging e pubblicazione90 soltanto con entrambi i gate riusciti;verifica versione/build,import di avvio,app+widget arm64,cataloghi e checksum. Nessuna attesa o polling CI su richiesta utente:consegnare link run quando avviato.

Il run43474910142 su8e17d1c compilava e passava3unitari+1UI;dueUI fallite:selettore Annulla invece dellaX nativa e catalogo che spariva dopo il tap ricerca. Correzione approvata:radice UIHostingController installata una volta per tab,snapshot contenuto+EnvironmentValues tramitewrapper SwiftUIstabile,aggiornamenti mainthread coalescenti per evitare pubblicazioni duranteupdateUIViewController. Il test ora verifica che la tastiera non chiuda il catalogo e che ricerca/risultati siano utilizzabili. Non dichiarare risolto prima del risultato.

## Dopo la pubblicazione

Acquisire esiti reali,conteggi,quattro avvii e artefatti;scaricareIPA pubblicata,controllareSHA256/versione/build e contenuto. Aggiornare stato distribuito soltanto dopo verifica. L’utente firma e installa conservando dati ed estensione widget;prove fisiche HealthKit/AppGroup/widget/AlarmKit e parità dati restano aperte. L’IPA non equivale ad accettazione prodotto.

## Run corrente

https://github.com/azeroualit-cloud/LifeOS/actions/runs/43499809697
Sorgente1a71b9556b28187dd3f23b59c38c38018f346602. Workflow registrato su main alcommit672fcad9f9233b7ffe75223ce422368fc781637e dopo404API,poiavviato su codex/revision77;nessunjobautorizzato su main. Tutte le fasi usano loSHAevento,nonilramomobile. Nessuna attesaattiva richiesta:utente comunica esito. Nonriavviareautomaticamente suiteintera dopo fallimento;analizzare loge conservare prove valide.

## Diagnosi dopo il primo tentativo

**Diagnosi43499809697,sorgente1a71b95:** compilazione passata;preflight compatto1/3UIpassati,2falliti;restante suite,Release eIPA non eseguiti. TestBloom aveva selezionatoCategorie:gerarchia delrun43474910142dimostraX nativa label«chiudi» dentroSearchField;ora query precisa,nessun selettore geometrico. Catalogo ancora si chiude:video mostra caret nelcampo poi dismiss,escluso tapfuori. Correzione giàautorizzata raffinata con un solo cambiamento discriminante:eliminata copia integraleEnvironmentValues tra host,trasferite solo preferenze pubbliche esplicite;wrapperstabile e observer tastiera invariati. Verifica runtime ancora necessaria. NessunaIPAprodotta,nessundeploy.

Non richiedere nuovamente approvazioneDEV02:è la stessa regressione catalogo già approvata. PubblicazioneIPA ancora autorizzata. Poiché il contenitore cambia,il singoloUIstati passato va rieseguito come regressione pertinente;nessunasuite lunga è stata eseguita nel primo tentativo. Nuovo preflightgli stessi3casi,restante suite solo se passano. Preferenze esplicite:dynamicTypeSize,locale,layoutDirection,colorScheme,calendar,timeZone,nativeForceReduceMotion. Preferenze readonlyaccessibilità risolte daUIKit inognihost;non copiare contesti di presentazione privati.

## Tentativo corrente dopo diagnosi

https://github.com/azeroualit-cloud/LifeOS/actions/runs/43506535087
Sorgenteaa3fb83ec452a5bca32bbfdf0cb6c9781508f3ac. Non rilanciare altri tentativi prima di analizzarne esito/log. Il primo tentativo non ha eseguito restante suite,Release oIPA. Nessuna nuova approvazione necessaria per questa stessa correzione/produzione.

## Esito secondo tentativo:solo test residuo

**Run43506535087,sorgenteaa3fb83:catalogo corretto.** Compilazione e2/3UI mirati passati(navigazione/stati,catalogo con tastiera/ricerca),unico errore neltestBloom:querycercavaX chiudi dentroSearchField,ma gerarchia9C90D51B mostra ramo fratello. Corretto solo iltest a queryesatta«chiudi» nell’app con attesa barra interattiva. Codiceapp/risorse/configurazione invariati rispettoaa3fb83. Preparato riuso dei2casi passati,recupero delsoloUIrimasto,poi restante suite/Release/IPA gated. Nessunasuite lunga è stataeseguita nei2tentativi90;nessunaIPA90prodotta,nessundeploybackend.

Evidenza:a11yfinal-screenshots/Preflight/9C90D51B-32AF-4B87-9755-0079F8567336.txt righe54–66 mostra SearchField eX come rami fratelli,labelchiudi. La querynelcampo era errata. Non modificare prodotto né richiedere nuove approvazioni per correggere quel selettore. Catture catalogo ebarra6voci ispezionate;catalogo riaperto e ricerca completata neltestpassato.

Riuso rigoroso proposto:2casi passati dal43506535087,sourceaa3fb83,artifactdiagnostico14077666871;confronto immutabilità prodotto/assembly e testpassati,poi unUIrecupero sulnuovoSHA. Distinguere prove aggregate da casi eseguiti nelnuovorun;restante suite saltatutti3casi coperti. Confezionamento deve preservare provenienza di entrambiirun.

## Recupero senza ripetere i due casi validi

**Recupero del solo test rimasto — 13 novembre 2026.** Il run 43506535087 su `aa3fb83` ha superato compilazione, navigazione/stati e ricerca catalogo con tastiera. Rimaneva solo il selettore Bloom: la X «chiudi» è un ramo fratello del campo. Corretto il test a livello app, senza modificare il prodotto. Il nuovo gate conserva i due risultati validi dopo confronto rigoroso di prodotto, assemblaggio e test; esegue un solo UI compatto, poi le prove restanti saltando tutti e tre i casi coperti. Provenienza distinta: due conservati e uno nuovo. Sei test locali del gate e verifica delle evidenze reali passati. Nessuna IPA 90 ancora prodotta; nessun deploy backend.

La partizione viene verificata contro l’artefatto 14077666871 del run 43506535087: due casi passati, un fallito, nessuno saltato. Tutto il prodotto e l’assemblaggio devono essere identici; l’intero file del test di navigazione deve essere identico fuori dal solo metodo riparato e gli altri file UI devono essere immutati. Il riepilogo xcresult corrente resta di un solo test; la copertura aggregata separata e BUILD-PROVENANCE.json indicano le due fonti. Se il prodotto o i test validi cambiano, il riuso è rifiutato.

## Run corrente: recupero singolo

https://github.com/azeroualit-cloud/LifeOS/actions/runs/43522275345
Sorgente `47cc00e4a89c3b73b95292f79e0c2bbabbe08377`. Non rilanciare senza analizzare questo risultato. Conservare la distinzione tra 2 casi UI riutilizzati dal run 43506535087 e il caso riparato eseguito qui; tutte le prove restanti e Release sono nuove sul candidato corrente. Autorizzazioni correzione e IPA già registrate.

## Revisione indipendente dopo run 43618379858

**Revisione indipendente del 14 novembre completata prima del nuovo run.** Tre sottoagenti hanno controllato contenitori, evidenze UI e pipeline. Ultimo run 43618379858: compilazione e 2/3 mirati verdi; il primo tap Calendario non attivava la destinazione. Hit area rettangolare applicata dopo lo sfondo; corretta anche l’invalidazione degli aggiornamenti ambiente accodati. Nuovi test verificano centro, icona e didascalia di tutte le sei voci. Pipeline ripulita dal riuso obsoleto: 5 mirati compatti e 14 regressioni sul principale prima della suite restante, poi quattro Release e IPA solo a gate verdi. Sette test locali del gate, otto del selettore, verifica dei 19 selettori reali e diff passati. La correzione runtime resta da provare; nessuna IPA90 prodotta.

Rapporto: INDEPENDENT-AUDIT-2026-11-14.md. Nessun aumento dei timeout e nessuna asserzione funzionale indebolita. I 14 casi primari comprendono tutti i 12 fallimenti della precedente suite e due probe Bloom (colonna/gap). Non dichiarare risolti scroll e percorso Finanza sulla sola compilazione o sui cinque casi compatti.

## Run corrente dopo i tre audit indipendenti

**Nuovo run dopo revisione indipendente:** [43623029267](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43623029267), sorgente `0de0287`. Prima cinque controlli compatti sulle sei voci e quattordici regressioni sul principale (tutti i dodici fallimenti precedenti più due probe Bloom); solo dopo suite restante, quattro Release e produzione IPA90. Tre sottoagenti hanno revisionato architettura, evidenze e gate. Correzioni e controlli locali passati; risultato runtime ancora da acquisire. Nessuna IPA90 verificata, nessun deploy backend. Monitoraggio affidato all’utente come richiesto.


## Diagnosi del run 43623029267 — 14 novembre 2026

Sorgente provato: `0de02872e459f4cb3cfe56684ed83d1cd8d66941`. Compilazione passata, preflight compatto 2/5 UI passati e 3 falliti; quattordici regressioni principali, suite restante, quattro avvii Release e IPA non eseguiti. Artefatti: diagnostica 14125792401, evidenze 14125637973.

Passati catalogo Integratori/ricerca e tutti i 18 tap normali (centro, icona, didascalia delle sei destinazioni). Anche i sei centri con testo grande passano prima del fallimento della query Image. La navigazione normale supera Calendario diretto/palette, Salute, conservazione palette e mese Finanza; fallisce Calendario aperto dalla Dashboard (linea 73). La gerarchia 8EFAC26D mostra ancora dashboard-scroll e Dashboard selezionata. La radice memorizzata conteneva NavigationStack costruito fuori dall'host osservante: estratto NativeDashboardStack con propria osservazione del router e percorso, senza ripubblicare il contenuto di ogni tab.

Due ulteriori errori dei test: query Image figlia assente nel pulsante icon-only grande; controllo immediato isSelected dopo tap Salute. Il primo viene allineato al centro dell'icona visibile (coincide col centro pulsante); il secondo usa attesa condizionata del medesimo tap nativo, senza retry, con diagnostica se la selezione non arriva. Questo non dimostra ancora che il tap grande funzioni: il nuovo run deve confermarlo. Le verifiche di contenuto e conservazione stack restano obbligatorie.

Due sottoagenti hanno separato diagnosi contenitori ed evidenze/test. Correzione nel perimetro funzionale già approvato. Nessun aumento dei timeout di blocco calendario, nessun riuso dei risultati precedenti dopo modifica prodotto, nessun deploy backend e nessuna IPA90 prodotta. Prossimo gate invariato: 5 compatti, 14 regressioni, restante suite, 4 Release, poi IPA autorizzata solo se tutto passa.

Aggiornamento dopo esame del video grande: l'ultimo fotogramma resta su Attività dopo il tap Salute; non è dimostrato un semplice ritardo. La nuova attesa resta una verifica rigorosa, senza secondo tap. Si prova una singola variabile del prodotto: disattivare la reazione interattiva del vetro dell'intera barra, mantenendo Liquid Glass e le azioni dei sei pulsanti. È un'ipotesi di interferenza nei gesti da discriminare, non una causa già dimostrata. La documentazione Apple ammette vetro interattivo sui contenitori: non si dichiara l'API usata scorrettamente ([WWDC25, Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)). Traccia dei tap solo nelle fixture DEBUG per distinguere mancata azione da cambio/reset del router. Il prossimo risultato deve confermare attivazione con tap nativo e contenuto, oltre allo stack Dashboard.


**Verifica avviata:** [43628175869](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43628175869), sorgente `c64430e7fbc71e80b47d7bd1c5a46d284cd67e59`. Esito runtime ancora da acquisire. Cinque UI compatti, quattordici regressioni principali, restante suite e quattro Release; IPA90 autorizzata soltanto dopo tutti i gate verdi. Nessun risultato precedente riutilizzato dopo le modifiche. Monitoraggio lasciato all’utente; nessuna attesa CI attiva.
