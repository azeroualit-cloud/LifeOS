# Revisione 75 — bollette per competenza

Stato: **IPA 0.10.14 build 75 pubblicata e scaricata/verificata dal link pubblico**: [LifeOS-75.ipa](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.14-build75/LifeOS-75.ipa). Consegna del solo file IPA richiesta esplicitamente dall’utente. Distribuzione Cloudflare ancora in attesa di autorizzazione: la nuova funzione utenze richiede quell’aggiornamento. Nessun Worker aggiornato e nessuna bolletta reale creata.

SHA-256 IPA: `94e64ccf0cc5a139208a05cb094a67241d6436305a9b4cd4e93b4737b05bf39d`. Sorgente del pacchetto: `14d40ef496bece1ae084ff50a4030471a5cb172d`. Artefatto disponibile fino al 10 novembre 2026, 07:18 UTC; comprende `download/LifeOS-unsigned.ipa`, checksum e prove.

## Comportamento

La registrazione e la modifica di una bolletta consentono di scegliere mese iniziale e finale, anche negli anni precedenti. Il periodo è esplicito, comprende da uno a dodici mesi e viene conservato anche negli invii locali in attesa. Per i documenti precedenti non si deduce il periodo dal nome o dal numero di mesi: va indicato nell’editor.

221,79 € con competenza agosto–ottobre produce tre costi di 73,93 €. Il movimento bancario resta unico, con importo e data di pagamento originali, anche se novembre. Il budget dei mesi precedenti viene ricalcolato; un mese senza documento conserva la stima. Le quote di documenti distinti nello stesso mese si sommano. Gli eventuali centesimi indivisibili vengono assegnati ai primi mesi, conservando il totale.

Il fondo conserva accantonamenti e disponibilità originali. Per le categorie utenze il budget conta il costo effettivo, oppure la stima, una sola volta: non aggiunge nuovamente l’accantonamento e l’intero pagamento. La modifica del solo periodo conserva anche l’identità del pagamento e lo stato di un fondo già chiuso o interrotto. Richieste ripetute, interruzioni e modifiche concorrenti vengono riconciliate senza un secondo addebito.

## Novembre

Riprodotto su dati sintetici un problema al cambio mese: il calcolo della media degli stipendi includeva il mese nuovo ancora privo di accredito e cadeva sul valore di ripiego. Se il mese immediatamente precedente ha un accredito, la finestra termina su quello; restano necessari dodici mesi consecutivi completi. Non si cercano stipendi arbitrariamente vecchi e un saldo realmente negativo non viene azzerato.

Questa riproduzione non dimostra la causa del valore personale di novembre. La diagnosi proposta sui dati finanziari reali, con indicatori nei log GitHub Actions, è stata bloccata dalla revisione automatica ed è in attesa di autorizzazione esplicita. Nessuna query finanziaria diagnostica è stata eseguita. La verifica separata del contesto di codice Cloudflare, priva di query ai dati finanziari, ha confermato la compatibilità della patch con entrambi i Worker esistenti.

## Integrità e compatibilità

Metadati di competenza nello stato finanziario già esistente; nessun secondo registro bancario e nessuna migrazione automatica dei movimenti storici. API dedicate impediscono a un backend precedente di accettare una bolletta ignorandone il periodo. Le operazioni conservano autenticazione, verifica origine, registrazione locale, ID app/widget e App Group.

La distribuzione prepara una trasformazione verificata del codice Worker esistente, conserva moduli e impostazioni estranei e verifica la rilettura dopo il caricamento. Non crea pagamenti di prova sui dati reali.

## Prove

Test isolati: ripartizione esatta, resto dei centesimi, passaggio d’anno, periodi invalidi, stime, budget completo dei mesi passati, separazione dal conto e dal fondo, fondi di diversi tipi, invii ripetuti, risposta persa, modifica concorrente, fondo chiuso, rollback e autenticazione. Regressioni precedenti finanziarie e attività conservate.

Verifica mirata Apple [41548876009](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41548876009), sorgente `51fd07b2cd1170889158c0651590631001033cfc`: **245 test unitari e 6 UI superati**. Compresi Salute, Bloom, calendario con testo ingrandito, creazione della bolletta con tre quote da 73,93 € e modifica del periodo. Schermate standard e con testo effettivamente ingrandito controllate. Il test di selezione/scorrimento del grafico peso è passato; un’intermittenza osservata nella precedente esecuzione resta registrata, senza attribuirle una causa non dimostrata. Gli esiti completi sui due dispositivi e il pacchetto verificato sono riportati sotto; il controllo del download pubblico resta successivo alla pubblicazione autorizzata. SDK 27.2 disponibile; runtime compatibile con iPhone 15 Pro e SE 3: 27.0. Prova fisica su iPhone 15 Pro con iOS 27.2 e confronto con le app Apple non eseguiti.


## Verifica finale e operazioni sospese

Il [run completo 41551009765](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41551009765), sul sorgente `39bef52dd498acfe629917c12bc1546da10eb732`, ha superato 245 unitari e 46 delle 47 esecuzioni UI previste: 5 nuovi flussi, 16 regressioni mirate, 5 regressioni agenda e 20 test compatti. Entrambi i nuovi test delle bollette sono passati su entrambi i dispositivi. Un solo fallimento nel vecchio test del fondo sul compatto: dopo sei swipe oltre il selettore, la Form virtualizzava la riga e il test ne leggeva la label fuori schermo.

Corretto esclusivamente il test: raggiunge il selettore, verifica il fondo Acqua prima di scorrere al dettaglio dei 10 € dagli altri risparmi, poi verifica la modifica del pagamento esistente. Tutte le asserzioni finanziarie conservate; aggiunte visibilità e premibilità effettive. Il [run 41592894317](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41592894317) ha verificato la corrispondenza esatta dei sorgenti di produzione e dei quattro xcresult precedenti, quindi superato il test corretto su iPhone 15 Pro e SE 3. Completate così le 47 posizioni UI previste, con un’ulteriore replica del test principale. Schermate effettive controllate.

Archivio Release e controllo IPA riusciti: ZIP integro, versione/build, identificativi conservati, app e widget informativo arm64 per iPhoneOS. La verifica del download pubblico resta successiva alla pubblicazione, attualmente sospesa. Anche firma Signulous, provisioning App Group, HealthKit reale e confronto Apple sul telefono restano prove fisiche distinte.

La revisione automatica ha rifiutato l’attivazione del commit `f0cb2d1992ce2b2bfef44fd4bd20d18219b8babd`: avrebbe distribuito il codice ai Worker e pubblicato una release con permessi di scrittura, azioni considerate non sufficientemente autorizzate per quel ref. Il commit non è stato applicato al ramo. È stato invece applicato `14d40ef...`, con soli test e creazione dell’artefatto, permessi Contents Read e nessun accesso Cloudflare. Non aggirare il blocco: occorre l’autorizzazione esplicita dell’utente prima di distribuire `lifeos` e `lifeos-native-test` e pubblicare l’IPA.

Proposta locale non attivata: `work/revision75/pending-release/lifeos-publish75.yml`. Riusa l’IPA già verificata con il checksum sopra, ricontrolla identità dei sorgenti e i due xcresult corretti, verifica Health purpose strings e package, prepara e verifica la patch contro il codice Cloudflare attuale, distribuisce senza creare movimenti, quindi pubblica gli stessi byte. Richiede l’approvazione reale dell’utente: il marker del commit non vale come autorizzazione. Dopo la pubblicazione verificare indipendentemente IPA, video e SHA-256 dal link pubblico prima di considerare conclusa la consegna.


## Consegna del singolo IPA richiesta successivamente

Alla richiesta «dammi l’ipa non lo zip», il [run 41596472472](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41596472472) ha pubblicato esclusivamente l’IPA già compilata, con verifica preventiva del checksum e dell’identità dei sorgenti. Nessun accesso Cloudflare, nessun deploy e nessuna query finanziaria. Scaricata poi dal link pubblico: 1.895.216 byte, SHA-256 esattamente `94e64ccf0cc5a139208a05cb094a67241d6436305a9b4cd4e93b4737b05bf39d`, CRC ZIP, versione, app/widget arm64 iPhoneOS, purpose strings Health e schema URL verificati.

La release `ios-0.10.14-build75` ora esiste e l’IPA è consegnata. Le istruzioni precedenti sulla sospensione della pubblicazione descrivono il blocco originario, superato per la sola consegna del file dalla richiesta esplicita successiva. La distribuzione del codice ai due Worker e la diagnosi finanziaria personale restano sospese. Non attivare il vecchio workflow locale che ricrea la release: dopo autorizzazione, preparare il solo deploy guardato e aggiornare le note della release esistente.
