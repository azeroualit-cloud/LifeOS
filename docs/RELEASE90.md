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
