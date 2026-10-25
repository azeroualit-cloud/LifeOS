# Life OS — sistema nativo condiviso

## Obiettivo e criteri

Conservare struttura, font iOS, colori dei turni, più inferiore e dati esistenti. Le stesse funzioni visive usano gli stessi componenti; non rendere indistinguibili controlli, contenuti e grafici. Budget Finanza conserva il nuovo padding20. Riuso effettivo nelle quattro sezioni, moduli e navigazione; nessuna dipendenza aggiunta.

Accettazione: checkbox uguali e con target44; titoli di riga Body17 e metadati Footnote13; superfici e margini da token; card standard20/compatte16/gruppi per righe; categorie personalizzate conservate; fallback icona neutra per nomi sconosciuti. Temi, testo grande, casi vuoti e affollati, aggiunta e modifica restano verificabili al simulatore.

## Struttura preservata

Home: giorni → riepilogo → abitudini → todo≤3 → budget. Attività: categorie → liste per stato. Calendario: mese/turni → giorno → eventi. Finanza: Panoramica/Extra → pagine secondarie esistenti. Barra inferiore condivisa, moduli nativi in sheet. Nessun nuovo livello o nuova funzione.

## Regole del sistema

- Spaziatura: scala4pt (2pt soltanto microseparazioni). Gutter schermo20, inset lista16, gap sezioni24, gap lista16. Clearance finale condivisa48 per mantenere gli ultimi comandi sopra la barra flottante. Nessun padding numerico nelle schermate.
- Card: normale padding20/gap16; compatta padding16/gap12; gruppo di righe inset16 e separatori allineati al testo. Raggio24 per card custom; gruppi List/Form conservano il trattamento nativo iOS. Controlli raggio12, badge6, giorni12, capsule soltanto navigazione e stati.
- Tipografia: Body17 per contenuto, Headline17 per titoli sezione, Subheadline15 per azioni secondarie, Footnote13 per metadati, Caption11–12 per assi/legende e calendario denso. Valori Title/Title2; Dynamic Type di sistema. Non ridurre indiscriminatamente il testo per farlo entrare.
- Colori: accento platino per interazione/icone; testo primario e secondario; verde/rosso desaturati soltanto per direzione finanziaria; warning/danger/success per stato. Turni con palette esistente. Nessun colore inventato per categoria.
- Icone: SF Symbols monocromi, stessa scala e peso per ruolo. Il completamento usa lo stesso controllo; riempimento solo per stato completato. Categoria sconosciuta→tag; nessuna modifica automatica al nome o ai dati.
- Motion: risposta breve condivisa, rispetta Reduce Motion; la selezione del calendario resta immediata. Feedback aptico delle routine dopo successo confermato.

## Componenti e responsabilità

Primitive: NativeIcon/NativeIconButton, NativeCheckmark/NativeCompletionButton, NativeDisclosureIndicator, NativeStatusBadge, NativeSelectionSurface, NativeInlineMessage.
Composti: NativeCard(density:), NativeGroupedCard, NativeRowText, NativeSectionHeader. Pattern: NativeListAppearance per List/Form, NativeBottomNavigation per le quattro destinazioni, NativeBudgetHero per il contenuto finanziario (calcoli fuori dal componente).

I componenti descrivono presentazione e tap. Non eseguono query, non contengono calcoli finanziari e non riscrivono record. Le schermate mantengono CRUD, caricamento, errori e stato. I controlli disabilitati e gli errori rimangono visibili/accessibili.

Catalogo categorie: le categorie di spesa canoniche provengono da Input.categories; le scelte di entrata e le icone risiedono in un catalogo presentazionale. Alias normalizzati solo per presentazione, corrispondenze di parola per evitare falsi positivi. Nomi personalizzati conservati nel picker e nei dati; categorie Attività lette dal server, mai sostituite con un elenco fisso.

## Modifiche future

Usare prima un componente esistente. Aggiungere un token o una variante solo per un ruolo effettivamente usato. Grafici, ring e geometria del calendario hanno misure dedicate, non sono card generiche. Eseguire scripts/check-design-system.py: vieta nuovi padding, spacing e raggi numerici nelle schermate, oltre ai font di testo a misura fissa. Eventuali eccezioni devono essere esplicite e motivate nel controllo. Verificare screenshot, contenuti lunghi, entrambi i temi e formato compatto dopo cambi strutturali.

## Verifica e file

Token: Sources/NativeDesign.swift. Primitive/compositi: NativeComponents.swift. Navigazione: NativeNavigation.swift. Catalogo: NativeCategoryCatalog.swift. Contenuti finanziari: NativeFinanceViews.swift. Check stile: scripts/check-design-system.py, eseguito anche in CI. Quattro test catalogo e controllo UI condiviso per categorie/checkbox; suite funzionale esistente conservata. 60 test locali passati; sintassi Swift verificata. Esito Apple e screenshot da registrare dopo la build. I dieci file core di modelli, persistenza e sincronizzazione sono identici alla baseline.

## Checklist — 0.8.1

NativeChecklistRow è il pattern condiviso di Home, Attività ed eventi/attività del Calendario: checkbox44, Body17, metadati13 solo quando presenti, stessa distanza8 tra controllo e testo, apertura separata dal completamento e chevron nel target di apertura. Le routine Home conservano il proprio pulsante a riga intera con stato busy.

Attività usa NativeChecklistListAppearance e NativeChecklistListRow: stesso raggio24, superficie, inset16 e separatori allineati al testo di NativeGroupedCard. Intestazioni Headline come Home, In attesa attenuato. Primo/ultimo elemento definiscono gli angoli del gruppo; completate e comando eliminazione sono un solo gruppo. List conserva swipe e riordino nativi, nessuna conversione in ScrollView o perdita di azioni.

## Riepilogo Home — 0.8.2

Turni descritti per nome, senza orari abituali; gli appuntamenti conservano il proprio orario se presente. NativeTypingSummary rivela il riepilogo in0,65s una volta per avvio del processo, senza replay al cambio scheda o sincronizzazione. Mantiene testo e font completi nel layout, nascondendo soltanto i glifi successivi: nessun salto delle sezioni. Testo accessibile subito; effetto saltato per Reduce Motion e VoiceOver. Cancellazione, uscita e aggiornamento contenuti mostrano subito il testo completo. I token di durata/cadenza sono in NativeDesign.Motion.

Navigazione0.8.2: GlassEffectContainer coordina barra e azione separata su iOS26+. Il vetro della barra non è un unico grande controllo interattivo; il più mantiene il proprio vetro interattivo. Indicatore di selezione unico che scorre su quattro colonne uguali con molla0,30s, feedback di pressione locale; nessuna animazione implicita sul cambio pagina. Geometria fissa e controlli44pt, Reduce Motion rispettato, fallback materiale nativo su sistemi precedenti.

## Revisione build 52 — prevale sulle indicazioni storiche

Accento blu per controlli e completamento, contrasto distinto nei due temi. Superfici scure opache condivise; righe completate con sfondo invariato e testo secondario senza barratura. Attivo/In attesa sono le sole sezioni delle attività. Espansione contestuale sotto la riga; calendario a mesi consecutivi con scroll verticale nativo e controlli persistenti. Motion locale 160 ms per selezioni, 260 ms per layout, disattivato con Riduci movimento. Frequenza dei fotogrammi da misurare su iPhone.
