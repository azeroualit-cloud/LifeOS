# Candidato0.10.28build90

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
