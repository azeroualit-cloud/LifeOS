# Life OS 0.9.9 — build 60

[IPA diretta per Signulous](https://github.com/azeroualit-cloud/LifeOS/releases/download/native-0.9.9-build60-restored/LifeOS-build60.ipa).

IPA unsigned, verificata prima della firma. Aggiornare senza disinstallare e mantenendo lo stesso bundle.

## Struttura e compatibilità

Ripristinata la struttura nativa della release 0.9.8 build 59, compresa Finanza con Budget/Piani, quattro destinazioni Dashboard, Attività, Calendario e Finanza, settimana in Dashboard, riepilogo, abitudini e scheda Peso e calorie. Il pulsante + della scheda apre la registrazione in Apple Health.

La base esatta della release 59 è d88355ba9c10cc57cf7e4ff99e80d8f76ff7e6d9, non il vecchio main. Il pacchetto 53 era basato sul vecchio main e aveva perso HealthKit e gli aggiornamenti di Finanza: questa build corregge la regressione. Mantiene salvataggi locali con coda, notifiche opzionali, Siri, widget e letture non bloccanti. Controlli, navigazione e presentazioni SwiftUI, dissolvenze standard senza scrittura artificiale del riepilogo e rispetto di Riduci movimento.

## Peso e sincronizzazione

HealthKit legge sei mesi di peso e calorie alimentari, sul dispositivo. La fonte alimentare è unica e selezionabile per evitare duplicati. Le pesate inserite con + o Siri vengono salvate in Apple Health dopo autorizzazione; il client non le carica nel server Life OS. Il permesso di lettura negato e l’assenza di campioni non sono distinguibili tramite HealthKit. Sono conservate le formule e le viste della 59.

Le misurazioni locali della 53 rimangono nell’archivio, consultabili nel dettaglio. Una migrazione atomica ritira dalla coda i vecchi saveHealthEntry validi conservandoli localmente, senza chiamare quell’API né scrivere automaticamente in Apple Health. Record malformati restano nel backup. Nel grafico, HealthKit prevale per lo stesso giorno; calorie locali e HealthKit non vengono sommate.

Attività, abitudini, turni e occorrenze supportati si salvano localmente prima della rete. La coda persistente conserva ordine e conferme; le letture tardive non sovrascrivono le modifiche pendenti. I movimenti finanziari conservano UUID. Creazioni/cancellazioni prive di idempotenza attendono il server. Sincronizzazione all’apertura, in primo piano e periodicamente durante l’uso, oltre ai salvataggi e al comando manuale; non è una sincronizzazione continua quando iOS sospende l’app. Conflitti tra dispositivi: l’ultimo setter inviato prevale, senza merge collaborativo.

## Web e integrazioni

Nessun codice web/backend modificato o distribuito da questo incremento. I dati condivisi modificati dal client saranno visibili anche nella webapp alla successiva lettura. I dati HealthKit restano separati dalla webapp.

Notifiche locali opzionali, non push remote; gli avvisi riflettono i dati caricati sull’iPhone. Widget di accesso rapido, senza agenda dinamica. Siri prepara attività da confermare nell’editor e registra peso in Apple Health. La firma deve conservare HealthKit e WidgetKit: permessi, Siri, widget e notifiche richiedono collaudo sul dispositivo dopo firma. Aggiornare senza disinstallare, mantenendo il bundle com.nas.lifeos.probe.

## Evidenze e provenienza

- Sorgenti del binario: commit `5bf2f3fbb4c306636f55f36a69d5ffc4911c665b`; ZIP SHA-256 `b09762b88e4dc017d2c89fa7582ac38daf1fddf5aa0dd12fed94d73f6099ef03`.
- [Build e archivio riusciti](https://github.com/azeroualit-cloud/LifeOS/actions/runs/40129522914): 2 percorsi UI di Finanza aggiornati e 6 prove su iPhone compatto superati, senza fallimenti.
- [Baseline completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/40123920833): 156 test unitari passati e 35 percorsi UI passati. Due vecchi test della release 59 cercavano il pulsante Extra superato da Nuovo piano e una voce storica senza scorrere Budget. Sono stati aggiornati mantenendo i controlli sul pagamento effettivo, saldo e budget. Una successiva correzione del test rispetta la chiusura automatica del modulo dopo il pagamento. Nessuna modifica al codice dell’app durante queste correzioni.
- La verifica incrementale impone checksum identici per tutto il codice dell’app, risorse, widget, progetto ed entitlements, tutti i test unitari e i restanti 35 test UI con i relativi helper. Si riusano soltanto gli esiti dei file identici; non si presenta questa evidenza come un’unica esecuzione di 37 test UI. Il bootstrap dei simulatori attende ora bootstatus dopo un timeout di avvio Xcode, e gli artefatti delle riesecuzioni possono essere sostituiti.
- [Verifica indipendente](https://github.com/azeroualit-cloud/LifeOS/actions/runs/40131901858) con soli permessi actions:read: confermati tutti i conteggi, provenienza invariata, archivio riuscito, CRC ZIP, versione 0.9.9 build 60, metadati italiani App Intents, descrizioni dei permessi Salute, schema URL, estensione WidgetKit e due eseguibili Mach-O arm64.
- IPA SHA-256 `ae2d04cfd0f01e48e7bd4c0848b91817b57c2b886f66489eda56f0fbbf88e14f`.

L’IPA della release conserva il checksum verificato. Il workflow di pubblicazione è temporaneo, limitato alla prima esecuzione sul ramo e a questo solo artefatto/hash, e viene rimosso dopo la consegna. Nessun merge o deploy web eseguito. Nessun collaudo su iPhone fisico o della firma Signulous: HealthKit, Siri, widget e permessi reali vanno provati dopo la firma.

## Widget successivi

I widget della build 60 rimangono accessi rapidi. Sono stati prodotti sei concept separati, prima dell’implementazione: piccoli Turno, Agenda e Ritmo; medi Settimana, Moduli e Prossimo. La scelta dell’utente e la verifica della condivisione dati/capability del profilo di firma precedono lo sviluppo dei widget con dati reali. Questi concept non fanno parte del binario 60.
