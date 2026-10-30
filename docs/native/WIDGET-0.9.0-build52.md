# Life OS — widget La giornata, build 52

Implementazione nei sorgenti del 30 ottobre 2026. **Non ancora compilata su Apple né verificata su iPhone. Nessuna nuova IPA disponibile.** La build 51 resta l’ultima consegna verificata.

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

Predisposti, **non eseguiti**: sette test del modello del widget, un test di integrazione della settimana con calendario lontano e un test UI di apertura dei due editor da avvio a freddo. Preview Xcode per la famiglia reale systemSmall aggiunta al target widget. Non verificati layout renderizzato, Dynamic Type, VoiceOver e tocco effettivo del + su SpringBoard.

## Gate Apple prima della consegna

Eseguire il workflow aggiornato: compilazione, suite esistente e nuovi test, controllo compatto e archivio. Il packaging controlla che LifeOSDayWidget.appex sia presente, con versione e identificatore corretti. Ispezionare il widget reale piccolo nei due temi e su formato compatto; provare il + sia con app chiusa sia aperta, salvataggio e riscontro nel widget. Dopo firma Signulous verificare comparsa nella galleria, accesso al gruppo e aggiornamento dei dati. Non sostituire questi controlli con il mockup generato in chat.

Riferimenti API consultati: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities e https://developer.apple.com/documentation/foundation/filemanager/containerurl(forsecurityapplicationgroupidentifier:).
