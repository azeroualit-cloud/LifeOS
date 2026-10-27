# Verifica struttura e prestazioni — Life OS 0.10.3 (64)

## Esito e confini

La versione 63 conteneva lavoro evitabile nel percorso di scroll. La revisione 64 riduce quei costi e rimuove UI obsolete. Non certifica un’efficienza assoluta, un numero di FPS o l’assenza di ogni possibile ottimizzazione: per attribuire tutti gli scatti di un iPhone specifico serve una registrazione Instruments/Time Profiler e Animation Hitches su quel dispositivo, con i suoi dati.

Nessun iPhone fisico è stato collegato o profilato. I simulatori disponibili e la loro versione OS vengono riportati nei log CI; non vanno equiparati alle prestazioni di un dispositivo reale.

Inventario: 58 file sorgente della composizione nativa esaminata, due target (app e widget), configurazione di build e dipendenze. Revisione strutturale di avvio, navigazione, calendario, attività, dashboard, finanza, salute, sincronizzazione, persistenza e notifiche; benchmark mirati dei percorsi di calcolo. Non è una prova esaustiva di ogni flusso di produzione.

## Problemi dimostrati e correzioni

1. CivilDate creava DateFormatter a ogni lettura/formattazione. La griglia convertiva ripetutamente gli stessi giorni fra Date e stringhe. Formatter ora inizializzati una volta, immutabili e riusati; griglie costruite direttamente da Date. Roma, anni bisestili e passaggi di ora legale conservati.
2. La finestra del calendario cresceva senza limite. Ora conserva al massimo 13 mesi, con identità stabili, estensione anticipata vicino ai bordi e potatura di griglie/snapshot lontani. Un salto lontano ricrea i vicini della destinazione, senza mantenere intervalli scollegati.
3. Ogni estensione ricostruiva tutte le griglie. Ora ricostruisce solo i mesi aggiunti; un caricamento aggiorna solo i tre mesi interessati. Gli indici eventi/attività restano coerenti.
4. Qualunque variazione di life, comprese abitudini e misure, svuotava la cache del calendario. L’invalidazione osserva ora solo eventi, turni, attività, occorrenze, giorno/mese, modalità demo e origine del server.
5. Il testo del caricamento aggiungeva altezza all’intestazione; un altro testo compariva/scompariva nei mesi non caricati. La barra di avanzamento occupa ora spazio costante e il caricamento non cambia l’altezza delle griglie. Gli errori restano visibili e riprovabili.
6. La lista attività ricalcolava filtri e ordinamenti anche per individuare primo/ultimo elemento di ogni riga. Ora materializza le tre sezioni una volta per valutazione della vista e passa i riferimenti di posizione alle righe.

## Misure riproducibili locali

Swift 6.2.1, Linux, compilazione ottimizzata -O, stesso ambiente e stessi mesi/giorni. Misurato il lavoro necessario a produrre giorni, etichette e giorno della settimana: questi valori **non** includono GPU, layout SwiftUI o FPS reali dell’iPhone. Una seconda esecuzione ha confermato la riduzione; non sono soglie contrattuali.

| Mesi / celle | Prima (ms) | Dopo (ms) |
| --- | ---: | ---: |
| 7 / 259 | 235,5 | 3,9 |
| 13 / 462 | 423,7 | 7,6 |
| 37 / 1337 | 1334,3 | 18,5 |

Il confronto riproducibile è in [scripts/benchmark-native-calendar.swift](../../scripts/benchmark-native-calendar.swift): verifica anche l’identità completa degli output prima/dopo.

La nuova UI non conserva 37 griglie: la terza riga serve soltanto al confronto del calcolo. Nell’estensione ordinaria vengono preparati solo i nuovi mesi.

Altri campioni sintetici, media di 100 calcoli ottimizzati: previsione finanziaria con sei mesi osservati e 2.000 simulazioni, circa 0,89 ms per calcolo; stima salute con 180 giorni di peso/calorie, circa 9,27 ms. Sono campioni locali, non un profilo dell’archivio reale. I modelli non sono stati riscritti sulla base di questi soli valori.

## Codice e dipendenze

- Nessuna dipendenza runtime di terze parti dichiarata: SwiftUI, Charts, HealthKit, Foundation, Combine, SQLite3, Security, UIKit, UserNotifications, UniformTypeIdentifiers e AppIntents sono componenti di sistema.
- Verificate le IPA 63 e 64: nessun framework incorporato e nessun bundle HTML/JS/WASM. Nell’IPA 64 non compare il testo della fixture UI di debug e non c’è un collegamento diretto a WebKit. Il frontend web e i suoi strumenti di test sono un prodotto separato, non vengono inseriti nell’IPA nativa.
- Rimosse 215 righe di viste senza riferimenti: NativeSavingsRing, NativeTodayPanel, NativeBudgetHero, NativeSectionHeading, NativeNavigationLabel e BillsHistoryScreen.
- Esclusi dal target il vecchio Store/Login WebKit e NativeActionLabel, rimasti nel pacchetto baseline immutabile. L’accesso attuale usa NativeSignInScreen/NativeStore. Nessun import WebKit rimane nei sorgenti attivi del target.
- Mantenuti Storage e modelli della migrazione, coda offline, ID idempotenti, convalide, gestione errori e test: proteggono i dati e restano necessari.
- Tab native con identità conservata; non vengono ricreate per animare il cambio scheda. Il riepilogo usa una dissolvenza del testo, senza animazioni per carattere o loop a ogni frame.

## Architettura restante e limiti

NativeStore serializza gli aggiornamenti, impedisce refresh sovrapposti e conserva le scritture prima della rete. Le letture vita/finanza possono procedere in parallelo; una mutazione aggiorna il proprio ambito. Meteo con cache di 15 minuti; HealthKit con guardia contro letture sovrapposte; promemoria limitati a 48. Non è stato modificato il Worker.

Restano opportunità da valutare con dati reali, non ragioni per dichiarare «non si può migliorare»:

- NativeStore è condiviso tramite ObservableObject: pubblicazioni non pertinenti possono rivalutare altre viste. Il lavoro costoso del calendario è ora indicizzato/cached, ma una separazione ulteriore degli store va giustificata da un profilo delle invalidazioni.
- Codifica JSON e scrittura atomica dell’archivio avvengono sul MainActor. Se le dimensioni reali mostrano blocchi, si può separare codec/I/O su un esecutore seriale mantenendo ordine, durabilità e recupero. Non va semplicemente ritardato il salvataggio offline.
- La sincronizzazione automatica controlla ogni 30 secondi, con guardie di concorrenza e intervallo minimo. Un protocollo incrementale/push può ridurre ulteriormente lavoro e rete, ma richiede un contratto backend e una decisione sulla freschezza dei dati.
- Le notifiche riconciliano il piano con il sistema. Una differenza incrementale dei soli promemoria cambiati può ridurre chiamate; deve conservare autorizzazioni, aggiornamenti esterni, cancellazioni e cambio giorno.
- La stima salute usa coppie di pesate nel periodo di sei mesi. Il limite temporale è esplicito; con archivi densi può meritare un profilo e una cache dei risultati per revisione dei dati.

## Verifiche

14 test Foundation locali superati, inclusi finestra limitata e contigua attraverso dieci anni avanti/indietro, salto lontano, isolamento da aggiornamenti di abitudini/salute, cambio origine/demo, griglie bisestili e di sei settimane, ora legale di Roma. Parsing Swift e controllo design system superati.

CI Apple [40400117695](https://github.com/azeroualit-cloud/LifeOS/actions/runs/40400117695), revisione 39563d1822a4697664698a85d0a34ddff7c984e9: riuscita. **175 test unitari e 8 esecuzioni UI superati**, senza fallimenti. Verificati scroll ripetuto avanti/indietro e ritorno a Oggi (test principale 89,6 secondi), selezione/deselezione, attività, comandi contestuali, archivio, accessibilità e Riduci movimento. Anteprime principali e compatte controllate.

Ambiente Apple: Xcode 26.3, simulatori iOS 26.2 (iPhone 17 Pro e iPhone SE di terza generazione). **Non è stato eseguito un test fisico su iOS 27.** Questi test non misurano FPS o frame pacing di un iPhone reale.

IPA verificata: app e widget **0.10.3 (64)**; ZIP integro e checksum uguale all’artefatto CI. Dimensione 1.317.517 byte. SHA256: `e9318e105e79491b09ea5949daef83f8771500bc5d1fb7b0bf1b6eff1557c56f`.
