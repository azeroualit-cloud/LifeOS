# Life OS — widget La giornata, build 52

**IPA 0.9.0 build 52 generata e verificata il 30 ottobre 2026.** [Pacchetto per Signulous](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41025472277/artifacts/12963700996) · [esecuzione finale](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41025472277). Scadenza artefatto: 6 novembre 2026, 09:20 Europe/Rome.

SHA-256 IPA: `03170b87d8fc11d99d4e98f8ce5c8693e14cf169011f34e83685ed7e647f02f8`.
SHA-256 sorgenti ZIP: `e8084ac7a67620534a33c34be0f3cae8466fb100cff9575bae2cc082137dc0d4`.
Commit del packaging: `0e13403245481de26ba1b07ff9f880af1485f4e8`. La firma Signulous e la prova fisica restano da verificare.

## Contratto concordato

Un solo widget Home piccolo (`systemSmall`, 2×2), senza dati finanziari:

- Sette giorni a partire da oggi, iniziali italiane e sigle dei turni; oggi evidenziato. Palette condivisa con il Calendario dell’app, senza orari standard.
- Abitudini: segmenti di completamento e conteggio. Oltre sette abitudini si usa una barra proporzionale per mantenere leggibilità.
- Numero di attività aperte di oggi e numero di scadute, distinti. Oggi include scadenza o pianificazione odierna; le scadute non sono contate due volte. Escluse altre categorie, completate e attività senza data.
- Pulsante + con area 44×44 punti: App Intent apre l’app e una scelta Evento/Attività. Riusa gli editor, la persistenza e la gestione errori esistenti; data iniziale oggi. Il resto del widget apre la Dashboard.

## Integrazione

Estensione WidgetKit incorporata nell’app, versione 0.9.0 build 52 per entrambi i target. Dati pubblicati solo dopo il salvataggio atomico dell’archivio dell’app. Copia condivisa minima: date delle attività, stati delle abitudini e turni; nessun titolo, dato finanziario, URL server o credenziale. I test con archivi temporanei non pubblicano nel widget personale.

Il widget legge gli ultimi dati salvati: non autentica chiamate di rete e non promette sincronizzazione in tempo reale con il sito. Le timeline avanzano a mezzanotte nel fuso Europe/Rome; gli aggiornamenti sono comunque gestiti da iOS. I check reali delle abitudini del giorno precedente diventano sconosciuti, non vengono riproposti come completamenti di oggi. Un indicatore segnala dati vecchi oltre sei ore o check da aggiornare. Un turno assente è un trattino, mai riposo implicito.

Navigare un mese lontano non deve svuotare la settimana: la sincronizzazione legge anche il mese attuale solo quando la copertura del calendario selezionato non include i sette giorni. Nessuna modifica al backend o ai dati remoti.

App Group richiesto: `group.com.nas.lifeos.probe`, negli entitlements di entrambi i target. La firma finale deve autorizzare/conservare il gruppo e l’estensione. Compatibilità della configurazione Signulous **non verificata**; se il gruppo non è accessibile, Impostazioni mostra l’errore, mentre l’archivio principale rimane utilizzabile.

## Verifiche eseguite

- Integrità ZIP e corrispondenza SHA-256 con il workflow.
- Parsing sintattico dei sorgenti Swift tramite tree-sitter: nessun nuovo errore rispetto al pacchetto precedente. La grammatica ha un limite già presente sulla sintassi `header:` di TasksScreen.swift; non è una compilazione Swift.
- Parsing YAML, corrispondenza versioni/target, incorporamento dichiarato ed entitlements condivisi.
- Controllo design system, esteso anche a Shared e Widgets; `git diff --check`.
- Revisione del diff e conservazione della palette; backend web invariato.

## Verifiche Apple completate

| Suite | Esito | Esecuzione |
| --- | --- | --- |
| Unitari, inclusi i sette WidgetSnapshot e l’integrazione settimana | 82/82 | 41018165365 |
| UI principali, incluso inserimento rapido Evento/Attività | 31/31 | 41014595085 |
| UI compatti già eseguiti | 12/12 | 41018165365 |
| Due casi compatti fermati nell’avvio, recuperati su nuovo simulatore | 2/2 | 41023842491 |
| Archivio Release, estensione, versioni, integrità IPA e arm64 | Passati | 41025472277 |

Totale: 127 esecuzioni di test, incluse le ripetizioni UI sul compatto, più il controllo isolato Finanza. I run intermedi hanno registrato un mock che non leggeva il corpo HTTP come stream, timeout di avvio XCTest e una versione widget generata come 1. Il mock ora legge entrambe le forme; le asserzioni sul turno rimangono. I due errori compatti erano alla riga app.launch, prima delle asserzioni; il recupero ha eseguito davvero gli stessi due test dopo installazione/preavvio sul simulatore nuovo. Nessuna modifica Swift/UI per aggirare questi timeout.

La versione del widget è ora collegata esplicitamente a CURRENT_PROJECT_VERSION e MARKETING_VERSION nell’Info generato: app ed estensione risultano 0.9.0 build 52. Il controllo di packaging ha bloccato la versione incoerente prima della consegna e ha poi verificato la correzione.

Il workflow normale conserva tutte le suite. I percorsi manuali di recupero/packaging verificano i log dei run fissati e confrontano i file del pacchetto: nessun cambiamento al codice o ai test UI viene accettato per il riuso. Sono ammesse soltanto le due variabili esplicite dei metadati versione del widget. Il riuso della suite principale precedente alla correzione del mock esclude esclusivamente Tests/ dal confronto; la suite unitaria successiva valida quel mock corretto. Gli altri confronti includono anche tutti i test.

Verificati sul runner Apple: estensione PlugIns/LifeOSDayWidget.appex presente; identificatori coerenti; versioni 52 e 0.9.0 corrispondenti; schema lifeos registrato; integrità CRC dello ZIP IPA; piattaforma iPhoneOS e intestazioni Mach-O arm64 di entrambi gli eseguibili. Upload dell’artefatto completato. Nessuna pubblicazione Cloudflare.

## Verifiche residue sul telefono

Aggiornare l’app esistente tramite Signulous senza disinstallare. La firma deve mantenere l’estensione e autorizzare l’App Group. Aprire e sincronizzare Life OS, poi aggiungere La giornata alla Home. Verificare sette turni, progresso abitudini, conteggi e + con app chiusa/aperta; scegliere e salvare un evento o un’attività e controllare il riscontro. Verificare il piccolo widget nei due temi, la leggibilità e VoiceOver.

La preview Xcode systemSmall è predisposta; non è stato eseguito un controllo visivo del widget realmente ospitato da SpringBoard. Gli screenshot UI e il preavvio dell’app non sono prove del layout del widget. La compatibilità effettiva della firma Signulous/App Group resta da confermare sul dispositivo.

Riferimenti API consultati: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities e https://developer.apple.com/documentation/foundation/filemanager/containerurl(forsecurityapplicationgroupidentifier:).
