# Salute per bodybuilding — brief per Astra e passaggio a Terra

4 novembre 2026. Stato: obiettivo e pianificazione autorizzati; layout e architettura sono ipotesi. Nessuna nuova implementazione richiesta in questa fase. Questo brief integra [la checklist completa](PROJECT-CHECKLIST.md), non la sostituisce.

## Obiettivo esplicito

Progettare Salute per un bodybuilder che dà priorità al minimo attrito: dati importanti immediatamente leggibili, consultazione semplice, pasti registrabili velocemente, pochi tocchi e poco spostamento del dito. L’utente descrive un uso «pigro»: non richiedere configurazioni ripetute o navigazione superflua. Progettare gerarchia, posizioni e flussi nei dettagli, senza sacrificare leggibilità e accessibilità.

Parole dell’utente: «Però tutto ciò che ho detto non è obbligatorio. L’obiettivo è avere la scheda salute pensate per un bodybuilder che da priorità al lowfriction». Quindi l’obiettivo prevale sulle proposte qui sotto; non sono tutte requisiti obbligatori.

## Proposte utente da valutare

| Tema | Proposta | Stato |
|---|---|---|
| Riepilogo | Quattro riquadri: TDEE e peso stimato tra un mese in alto; ultima pesata e calorie sotto | Non vincolante. L’utente dice «4x4» ma elenca quattro celle in due righe: presumibile 2×2, da esplicitare nel piano |
| Nutrienti | Sotto, «4x1» con proteine, carboidrati, grassi e fibre | Non vincolante; presumibile fila di quattro, da adattare al testo grande |
| Azioni | Due pulsanti: aggiunta peso e aggiunta pasto | L’utente non è sicuro di forma/posizione; da progettare, non implementare ora |
| Futuro tracker | Database di cibi comuni standard e possibilità di aggiungere cibi personali | Evoluzione proposta, non già autorizzata allo sviluppo |
| Rilevanza | Dare priorità ai propri cibi, evitare cataloghi rumorosi di prodotti americani | Valutare catalogo base pertinente, ricerca e libreria personale; non assumere geolocalizzazione o un’esclusione assoluta |
| Persistenza | Cibi locali nell’app, niente meccanismi complessi di sincronizzazione, evitare carico su Cloudflare free | Preferenza architetturale da valutare, non decisione già fissata |

## Confini attuali

- In questa fase: documentare obiettivo, aggiornare checklist e preparare un piano in un’altra chat.
- Non implementare nuovi editor di peso/pasto, cataloghi alimentari, migrazioni o integrazioni. Non rimuovere il quick add o le azioni già esistenti.
- Il quick add Dashboard approvato resta un flusso di quantità effettive P/C/G/fibre con energia automatica. Un futuro catalogo non riattiva automaticamente il vecchio editor per 100 g/etichetta.
- Nessun deploy backend e nessuna IPA. IPA-GATE-01 richiede una richiesta esplicita distinta anche se l’utente approva il piano o dice «continua».
- Astra pianifica; Terra eseguirà solo gli incrementi concretamente approvati. Questo documento non autorizza Terra a realizzare l’intero backlog.

## Decisioni che Astra deve rendere esplicite

1. Gerarchia e significato dei quattro dati: TDEE stimato vs obiettivo calorico, peso stimato fra un mese vs ultima misurazione, calorie di oggi vs target. Definire fonte, periodo, data dell’ultima pesata e accesso ai dettagli.
2. Previsione: data di riferimento (mese di calendario o orizzonte definito), input e ipotesi, dati insufficienti, aggiornamento e comunicazione dell’incertezza. Valutare il modello già presente; non promettere accuratezza clinica o risultati garantiti.
3. Nutrienti: consumati oggi, eventuali obiettivi e stato senza dati. Chiarire proprietà delle fonti; preservare G03 (calorie da tutte le app in Apple Salute), evitando duplicazioni fra diario futuro e campioni scritti da LifeOS.
4. Flussi: prima registrazione e uso ripetuto, ricerca vs recenti/preferiti/pasti riutilizzabili, modifica quantità, conferma, correzione e recupero. Recenti, preferiti e modelli sono alternative progettuali da motivare, non richieste già approvate.
5. Ergonomia: uso a una mano, mano dominante non nota, zone raggiungibili, tap/scroll/cambi schermata/tastiera per i compiti frequenti. Misurare i percorsi e proporre obiettivi realistici; nessun numero di tocchi o millisecondi inventato come requisito utente.
6. Prestazioni: consultazione e registrazione non bloccate dalla rete; se si propone locale, separare salvataggio locale confermato e integrazione HealthKit. Misurare avvio, ricerca e conferma con libreria realistica sul target concordato.
7. Catalogo: perimetro iniziale italiano/pertinente, cibi generici vs marche, crudo/cotto, porzioni/unità, valori mancanti, fonti/licenze e aggiornamenti. Non inventare valori nutrizionali né scrivere «tutti i cibi comuni» come promessa di copertura totale.
8. Cibi personali: creazione/modifica e ricerca, distinzione da catalogo standard, integrità dello storico quando cambia un alimento. Catalogo, diario e snapshot dei pasti hanno responsabilità diverse.
9. Località dei dati: valutare archivio già presente prima di scegliere SQLite/SwiftData/altro; cosa includere nell’app e cosa salvare sul dispositivo. Valutare migrazioni, export/ripristino e cambio telefono. Nessun Cloudflare, account, scanner o servizio esterno aggiunto implicitamente.
10. Accessibilità e sicurezza dei dati: schermate strette, Dynamic Type, VoiceOver, assenza permessi, dati vecchi, stato vuoto, errore e annullamento. Il layout deve refluire senza nascondere valori o azioni.

## Conflitti potenziali — nessuna sostituzione autorizzata

- G08/G09/G13 descrivono le quattro schede Salute attuali come righe con trattamento omogeneo. La griglia proposta può sostituire quella disposizione solo dopo scelta e conferma esplicita; registrare l’esatto ambito.
- G05/G06/G07 fissano azioni iconiche peso/macro e relativa collocazione. Pulsanti testuali, nuova posizione o diverso flusso pasto possono richiedere conferma.
- G10/G11/G12 fissano gerarchia e trattamento dei mini grafici. Non assumere che l’obiettivo bodybuilding le cancelli.
- F03–F06 sono SUSPENDED per il quick add. Studiare una rappresentazione per 100 g dei cibi futuri non equivale a riattivare il vecchio flusso; delimitare i contesti e chiedere solo per un conflitto effettivo.
- G03 resta ACTIVE: tutti i campioni calorici letti da Apple Salute. Se il piano propone conteggi limitati al diario LifeOS, è un conflitto da sottoporre all’utente.

Le proposte sono non vincolanti: ora si possono analizzare senza porre una conferma per un’implementazione che non è richiesta. Prima di attuare una scelta incompatibile si applica META-01, senza via di mezzo o sostituzione silenziosa.

## Consegna richiesta ad Astra

Leggere AGENTS.md, USER-DECISIONS, PROJECT-CHECKLIST, STATUS, BUILD-STATE e questo brief; audit solo dei sorgenti pertinenti, evitando di rileggere l’intero storico o i backup personali. Produrre un piano compatto e autonomo che comprenda:

- Stato iniziale verificato, obiettivo, ambito immediato e futuro, decisioni aperte e conflitti con ID.
- Una proposta raccomandata con alternative solo dove cambiano davvero il risultato; wireframe/anteprima e flussi completi.
- Modello dati e architettura motivati dal codice attuale; fonti alimentari da verificare in una fase separata, senza catalogo fittizio.
- Incrementi piccoli con dipendenze, componenti riusati, file interessati, criteri d’accettazione e prove appropriate.
- Distinzione fra piano della scheda di consultazione e piano futuro degli inserimenti/database. Il secondo non diventa sviluppo autorizzato per effetto del primo.
- Un blocco di consegna per Terra con le sole decisioni approvate, dubbi rimasti, verifica necessaria e condizione di stop.

Per contenere costi: niente compilazioni ripetute durante la pianificazione, niente task generici «migliora tutta l’app», niente test globali a ogni ritocco. Non eliminare i controlli d’integrità, accessibilità o QA visuale necessari. I problemi dei runner non provano un difetto dell’app né autorizzano a saltare la verifica.

## Consegna futura a Terra

Partire solo dal piano approvato e dal relativo commit; verificare lo stato attuale prima di modificare. Eseguire un incremento completo alla volta, controlli locali proporzionati e prove simulatore pertinenti quando disponibile. Registrare passato/fallito/non eseguito, mostrare prove reali e aggiornare checklist/report/GitHub. Fermarsi prima delle funzioni non approvate o di un conflitto. Nessuna IPA senza nuova richiesta esplicita.
