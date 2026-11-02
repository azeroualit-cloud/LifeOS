# Revisione 74 — interfaccia Apple, Salute e Bloom

Consegnata il 2 novembre 2026: [IPA 0.10.13 build 74](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.13-build74/LifeOS-74.ipa) · [registrazione dei flussi](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.13-build74/LifeOS-74-flussi.mp4). Aggiornare con Signulous senza disinstallare.

## Navigazione e interfaccia

Quattro schede: Dashboard, Attività, Salute, Altro. Altro contiene Finanza, Calendario e Bloom. Il router conserva le richieste esplicite di data, evita duplicazioni dello stack e mantiene il calendario consultato dopo il background. Le intestazioni personalizzate hanno un ritorno ad Altro. I test precedenti sono stati adattati al nuovo percorso conservando i controlli sui flussi.

I puntini del calendario usano il colore del turno, oppure un neutro senza turno. Le abbreviazioni del mese seguono le sette colonne; il mese corrente ha l’accento e il separatore precede le celle. Le celle del mese e della settimana condividono identità geometriche limitate al contenuto visivo; le aree di tocco restano stabili. Le settimane sono target diretti della lista lazy. ScrollViewReader e scrollPosition condividono il target delle richieste esplicite; il binding nativo conserva la settimana quando si aggiungono mesi alla griglia. Le frecce mostrano la settimana che contiene il giorno 1. La cache delle settimane evita di ricostruire tutte le date durante lo scorrimento. Toolbar con stile glass nativo su iOS 26+, fallback nativo precedente; rimossi i coriandoli del turno. Grafici Swift Charts con selezione di data/valore e scale indipendenti dalla selezione. Riconoscitori UIKit pubblici distinguono il tocco e la pressione con trascinamento dallo scorrimento verticale; il contenitore sospende lo scorrimento soltanto durante la pressione riconosciuta. Il riquadro data/valore ha altezza stabile. Riduci movimento viene rispettato dalle animazioni personalizzate.

La riga «Completate» ha una content shape rettangolare: anche il centro vuoto attiva il controllo. Sul dispositivo compatto il test dei movimenti scorre il menu nativo delle categorie quando la voce cercata precede quella selezionata; non modifica la selezione per coordinate né riduce le verifiche del fondo.

Inventario dei componenti attivi e delle sostituzioni: [Movimento 74](MOVIMENTO-74.md).

## Salute

Proteine, carboidrati e grassi in grammi; calcolo Decimal 4/4/9, virgola/punto decimale, totale immediato e data/ora modificabili. Tastiera numerica con Fine. Cronologia LifeOS modificabile e collegamento ai dettagli esistenti di peso/calorie/fonti/TDEE.

La scrittura HealthKit usa quattro campioni, identificativi stabili per registrazione/tipo e revisioni crescenti. Un giornale locale pending/confirmed precede l’invio; un retry riutilizza identità, revisione e payload. Non si presume una transazione fra filesystem e HealthKit. Le registrazioni di altre app non vengono modificate. I test usano un writer iniettabile e coprono autorizzazione negata, interruzione, riavvio, retry, modifica e archivio corrotto.

Documentazione Apple consultata: https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion — le versioni maggiori sostituiscono gli oggetti corrispondenti con versione inferiore. La prova reale di scrittura su iPhone e la verifica della rifirma HealthKit restano distinte dai test simulati.

## Bloom

Sorgenti del kit verificati contro tutti i 74 hash del manifest, origine `azeroualit-cloud/Bloom` commit `d11df5e29790e2c383314421cd399c8e8e7300d4`. Riutilizzati/adattati planner Riscopri, parsing/rendering Markdown, modello luoghi e mappa UIKit con cluster. Nessun PKMS, Dropbox, SwiftData aggiuntivo o lifecycle Bloom autonomo.

Archivio Codable locale separato. Allegati immutabili per SHA-256, indice pubblicato atomicamente dopo i file, verifica dimensioni/hash in lettura, backup originale conservato. Importazione Bloom 1/2 con date dal 2001, anteprima, validazione metadati/riferimenti/coordinate/ritagli/limiti, conflitti espliciti keep/replace/copy e confronto in sola lettura dei campi delle due versioni. Il confronto degli allegati usa byte e SHA-256, senza conservare Base64 nelle anteprime. I rimappamenti persistono, incluse le copie, per non duplicare una reimportazione. Rapporto persistente con conteggi, byte, checksum e categorie rimappate. Nessuna manutenzione automatica del Cestino; eliminazione manuale con conferma e conservazione degli allegati condivisi.

Libreria in griglia/elenco, ricerca, categorie multiple, fissati, gestione categorie e azioni multiple. Note di testo/titolo, link, foto, file e allegati. Pager per contenuti multipli, Markdown con tabelle e codice, Quick Look per originali e ritagli non distruttivi. Miniature ridotte per la griglia e anteprime orientate per i ritagli.

Mappa sullo stesso archivio, gruppi di note per luogo, cluster, camera conservata fra le sezioni e pannello con note collegate. Ricerca Apple Maps e tipi modificabili senza richiedere la posizione corrente. Classificazione su richiesta, fino a 30 luoghi senza tipo, nome normalizzato identico e distanza entro 150 m; nessuna sovrascrittura delle tipologie esistenti. Riscopri usa il planner deterministico del kit, massimo 30 elementi, con filtri e giro persistito.

Cattura tramite App Intent e schema LifeOS. Un URL esterno prepara il compositore; l’Intent esplicitamente invocato salva il link e mantiene una coda locale recuperabile. App e Intent condividono l’archivio per evitare writer concorrenti. Un retry non sovrascrive una nota già salvata e poi modificata.

## Evidenze e limiti

Sorgenti app della candidata finale: `8621d28800be38fd044ea35a3d7fd54d249a503b`. [Pipeline completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41517266623): completata con successo; download pubblico verificato.

- 240 unitari passati sia con SDK 26.3/runtime 26.2 sia con SDK 27.2/runtime 27.0 sul sorgente dati della candidata. [Verifica 26](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41504127033), [verifica 27](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41504127092). Coperti macro, retry/revisioni, archivi corrotti, importazione Bloom 1/2, tutti i tipi e allegati multipli, checksum, spazio insufficiente, conflitti e reimportazione dopo riavvio.
- [Regressione calendario mirata passata](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41506255193) con l’ultima sincronizzazione del viewport: otto passaggi novembre→marzo, intestazione corretta e giorno 1 visibile e premibile a ogni passaggio, testo ingrandito. Controllata la schermata reale a sei settimane: marzo nella colonna di domenica e aprile in quella di mercoledì.
- Nelle verifiche Apple precedenti sono passate compilazione e tre prove registrate dei nuovi flussi: 165 kcal, selezione dei grafici con scorrimento verticale, due note Bloom distinte, Mappa/Riscopri e ritorno agenda→mese. La pipeline finale ha superato 240 unitari e 42 esecuzioni UI: 3 dei nuovi flussi registrati, 15 regressioni mirate, 5 regressioni applicative e 19 sul dispositivo compatto. Nessun fallimento. Temi chiaro/scuro, schermate principali e compatte controllati visivamente nei risultati reali.

Il runner iniziale macos-15 offriva Xcode 26.3/iOS 26.2. Il runner pubblico preview `xcode-27` ha confermato Xcode 27.2 RC (27B48) e SDK iOS 27.2. Il runtime 27.2 scaricabile è limitato a un altro modello: simctl rifiuta iPhone 15 Pro. Il runtime generico più recente dichiarato compatibile con iPhone 15 Pro e SE 3 è iOS 27.0, usato nelle nuove verifiche. SDK e versione realmente eseguita sono registrati separatamente. Non si dichiara una prova iPhone 15 Pro su 27.2.

Deployment target iOS 17 conservato; disponibilità controllata per le API successive. Verifiche locali passate: parser Swift, diff check, checker design system e tre test Python dell’estrattore del kit. Le prove HealthKit usano un writer simulabile: scrittura reale, permessi parziali sul telefono e rifirma HealthKit/App Group richiedono il dispositivo fisico. Il confronto con Calendario, Promemoria e Salute sullo stesso iPhone, con identica versione iOS e dimensione del testo, e la verifica parlata VoiceOver restano distinti dalle prove automatiche.

Lo ZIP contiene sorgenti e istruzioni, non il database del telefono. La migrazione reale richiede un backup esportato da Bloom, seguito da controllo dei conteggi e degli allegati e riapertura offline. Non è stata dichiarata completata con dati reali.

Verifica indipendente del download pubblico: ZIP integro, app ed estensione arm64 iPhoneOS, bundle ID e versioni coerenti, widget informativo presente, descrizioni HealthKit e schema LifeOS presenti. Il pacchetto dichiara famiglie iPhone/iPad; le prove UI coprono iPhone 15 Pro e SE 3. SHA-256 IPA: `c3effa92af323e544eeaaf55e8eda964098b0aa7b5581211c65c53d5d063f715`. Registrazione H.264, 1178×2556, 269,22 secondi; checksum confrontato con SHA256.txt pubblico. La verifica del pacchetto non certifica gli entitlement applicati successivamente dal servizio di firma.
