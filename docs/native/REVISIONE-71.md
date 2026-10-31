# Revisione 71 — consegna verificata

Base: build 70, sorgente `native-next`, Swift e SwiftUI; Charts per Salute, WidgetKit per il widget, AlarmKit per le sveglie urgenti. Nessun nuovo framework esterno. Icona attuale conservata su scelta dell’utente.

## Struttura attuale

```mermaid
flowchart TD
    App["App iOS: Swift e SwiftUI"] --> Home["Dashboard"]
    App --> Activity["Attività e Calendario"]
    App --> Finance["Finanza"]
    Home --> Health["Apple HealthKit e Swift Charts"]
    Activity --> Editor["Unica scheda attività/evento"]
    Activity --> Timeline["Layout per minuti e sovrapposizioni"]
    Editor --> Store["Archivio locale e coda persistente"]
    Finance --> Store
    Store --> Server["API Cloudflare esistenti"]
    Store --> Bridge["Dati essenziali del widget"]
    Bridge --> Group["App Group condiviso"]
    Group --> Widget["WidgetKit: Life OS · Oggi, 2×2"]
    Editor --> Alarm["AlarmKit: sveglie autorizzate su questo iPhone"]
```

La base è nativa Apple. Sono specifici di Life OS i componenti composti con SwiftUI, i colori dei turni, il modello dei dati e il layout degli impegni. Liquid Glass, fogli, selettori, navigazione, grafici e integrazioni di sistema usano i framework Apple. Non vengono aggiunti altri framework grafici.

## Contratto UI

- Dashboard: solo data nell’intestazione; turno e progresso conservati. Peso e calorie usa arancione Salute per valori e barra odierna, grigio per storico e linea peso. Settimana: giorni passati all’80%, giorni futuri visibili anche nel mese successivo.
- Attività: tocco sul titolo → scheda nativa dal basso; completamento resta indipendente nella lista. Titolo/descrizione, inizio e scadenza affiancati, selettore data aperto dal primo tocco e rimozione con ×. Orari direttamente sotto le date, poi categoria e luogo. Attesa, completamento, eliminazione e ricorrenze restano disponibili.
- Calendario: mese continuo a tutta altezza, giorni ampi e numeri semibold. Tocco → giorno con settimana superiore e griglia oraria posizionata per minuto e durata, con colonne per sovrapposizioni e attività di tutto il giorno fisse sopra le ore. Ritorno al mese; accessi normali e riapertura riportano a oggi. Accesso esplicito dalla Dashboard apre il giorno richiesto. Nessuna esportazione Apple nella scheda Calendario; resta in Impostazioni.
- Dipingi: riferimento Supershift scelto dall’utente; palette orizzontale Liquid Glass nativo su iOS 26 (materiale di sistema sulle versioni precedenti). Il salvataggio continua a usare la coda locale persistente; gli aggiornamenti di soli turni non ricostruiscono l’indice eventi di tutti i mesi. La posizione visibile viene osservata senza riscrivere continuamente l’offset dello scorrimento; i salti sono riservati ai comandi espliciti e all’estensione della finestra dei mesi.
- Finanza: struttura aperta dell’allegato, titolo e pulsanti sulla stessa riga, importi allineati a sinistra, conto con saldo a destra, Budget/Analisi in pillole, movimenti con icona e divisori. Nuovo movimento dal +; ulteriori azioni nel menu. Le icone sono simboli semplici monocromatici, senza immagini generate.

## Sveglie urgenti

Prima integrazione nativa AlarmKit, solo iOS 26+, per eventi singoli futuri con orario. Consenso distinto dalle notifiche; nessun accesso ad AlarmKit per un’attività senza sveglia. Opzione locale a questo iPhone, non sincronizzata al server; serie ricorrenti escluse esplicitamente. UUID stabile, modifica della stessa sveglia, cancellazione dopo completamento/eliminazione e riconciliazione dei record caricati. Un mese non caricato non equivale a un evento eliminato. Gli errori di autorizzazione/programmazione/cancellazione sono visibili. La prova del suono su iPhone reale resta necessaria.

## Widget

La vecchia identità `LifeOSQuickActions` viene sostituita da `LifeOSOverview`, nome galleria **Life OS · Oggi**, una sola famiglia 2×2. Dopo installazione rimuovere il widget con i vecchi pulsanti e aggiungere quello nuovo. Il cambio rende distinguibile un’estensione vecchia da quella aggiornata. Se il nuovo nome manca anche in galleria, verificare che il servizio di firma conservi l’estensione dell’IPA aggiornata. App ed estensione richiedono `group.com.nas.lifeos`. L’app espone stato e aggiornamento manuale; anche in assenza di App Group richiede il refresh della vista per non lasciare la precedente cache. La firma effettiva del servizio esterno non è verificabile dal simulatore.

## Verifiche

Superati **207 test unitari e 36 esecuzioni UI**, zero fallimenti, su iPhone 15 Pro e iPhone SE 3. Sintassi, design system, regressioni backend e integrità del pacchetto verificati. [Test Apple](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41196021079): tutti i test e l’archivio riusciti; il controllo finale ha rilevato una descrizione di autorizzazione assente dal plist. La correzione riguarda solo i metadati: le tre descrizioni AlarmKit/HealthKit sono ora proprietà esplicite del plist. [Confezionamento finale riuscito](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41198865956), con controllo automatico che sorgenti e test siano identici alla revisione testata.

[Scarica direttamente LifeOS-71.ipa](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.10-build71/LifeOS-71.ipa), versione **0.10.10 (71)**. Download pubblico verificato: checksum, CRC, bundle/versioni di app ed estensione, binari arm64 per iPhoneOS, schema URL e tre descrizioni di autorizzazione. Dimensione: 1.496.519 byte. SHA-256: `1fbd6df65664dc0ff1825eafbeb9b26c1cf54a95b6ae38c9b95916dccfb24849`.

Sorgente e test: `1512469de2f9e440ad25775f0371eea689c756d2`. Pacchetto finale: `d1b97d1cd7848ae9fa522195ae4a4a9f85192d8c`. IPA non firmata, da rifirmare con Signulous aggiornando senza disinstallare. Provisioning App Group e suono AlarmKit su iPhone fisico restano da verificare. Nessuna modifica backend necessaria per questo incremento; i Worker aggiornati e verificati della build 70 restano la base attuale.
