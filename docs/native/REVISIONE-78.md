# Revisione 78 — lavoro e criteri di verifica

Base consegnata: 0.10.16 (77). Nuova versione prevista: 0.10.17 (78).
Questa revisione è in verifica; una compilazione o una schermata da sola non
dimostra il completamento dei flussi. Nessun nuovo IPA è ancora consegnato.

## Contratto richiesto

| Area | Risultato | Evidenza necessaria |
|---|---|---|
| Data e preghiere | Solo l'ora a destra della data; tocco apre tutti gli orari | Geometria e apertura sheet su 15 Pro |
| Toolbar | Impostazioni e più compatti, area tattile almeno 44 pt | Misure reali e screenshot |
| Attenzione | Eventi di oggi, abitudini di oggi, eventi domani/dopodomani; nessuna attività generica | Test ordinamento, esclusioni e screenshot popolato |
| Finanza | Titolo/icona/freccia, numero e Budget, Aggiungi spesa a destra | Screenshot e navigazione completa |
| Nutrizione | Proteine, carboidrati, grassi, fibre e kcal etichetta per 100 g, porzione in grammi; sola data | Calcolo porzione, HealthKit, persistenza/retry, tastiera e UI |
| Salute | Somma di tutte le entry energetiche lette, senza selettore fonte o pulsante di collegamento | Aggregazione e ispezione query; assenza controlli UI |
| Azioni Salute | Due icone Liquid Glass sopra la tab bar, peso e macro | Hit target, posizione, apertura dei due editor |
| Riepilogo Salute | TDEE/Peso/Calorie/Simulazione uniformi; titolo colorato, valore grande, unità secondaria, mini grafico grigio e ultimo dato colorato | Confronto con Apple Salute e screenshot chiaro/scuro/testo grande |
| Bloom | Pulsanti compatti; File → selezione JSON → anteprima → conferma → dati visibili anche dopo riavvio | Test UI con selettore di sistema e JSON con allegato sintetico di 6 MiB |

## Integrità dei dati

- I record nutrizionali precedenti mantengono il calcolo 4/4/9. Solo le nuove
  registrazioni con kcal esplicite usano l'energia dell'etichetta, scalata sulla
  porzione; non viene aggiunta nuovamente l'energia delle fibre.
- I quattro identificativi HealthKit già esistenti restano agli indici 0–3;
  le fibre si aggiungono all'indice 4. I record precedenti non richiedono fibre
  per poter essere riscritti o eliminati.
- Gli eventi ancora aperti di oggi sono letti anche dall'intervallo operativo,
  perché la risposta `upcomingEvents` esclude gli appuntamenti già iniziati.
  La selezione non dipende dal mese che si sta esplorando nel calendario.
- Il backup Bloom originale non viene modificato. L'anteprima appare dopo la
  chiusura del selettore File; lettura coordinata e copia locale precedono
  validazione e conferma. La validazione principale avviene fuori dal main actor.
- Nessuna modifica backend o importazione dei dati personali in produzione è
  prevista da questo incremento. I test usano dati sintetici.

## Riferimento Apple Salute e REA

Skill ufficiale letta dal pacchetto `rea-agents@6.8.0`, versione skill 49,
repository `morluto/rea`. Il doctor locale ha rilevato Node 24.21.0 non
supportato e nessun motore nativo disponibile. Non è stata modificata la
registrazione globale di Codex né sono stati installati motori sul computer.

Il workflow usa Node 24.22.1 e REA 6.8.0 nel proprio checkout temporaneo.
`scripts/inspect-apple-health78.py` apre le risorse dell'app Apple Salute del
simulatore e ne conserva identità e risposte complete, senza distribuire il
binario Apple. Una prova UI separata acquisisce schermate e gerarchia accessibile.
L'ispezione delle risorse **non** prova da sola dimensioni e comportamento del
layout. La fedeltà esatta resta da dimostrare sul riferimento effettivamente
acquisito, non va dedotta dal semplice successo di REA.

## Stato iniziale delle verifiche

`bdc313727c0e7d4420570accab4c16e4e373fcbc` ha avviato
[la prima validazione](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41693331566).
I controlli locali di composizione e `git diff --check` sono passati.
La prima compilazione Swift è passata. REA ha aperto il bundle delle risorse;
`inspect_plist` ha restituito `provider_timeout` dopo 60 secondi. Il run aveva
`continue-on-error`, quindi la conclusione verde del singolo step non prova
il successo della lettura plist. Il retry usa il timeout esplicitamente indicato
dal rapporto REA e un margine maggiore per la risposta MCP.
Test unitari/UI, confronto visivo, avvii Release e pacchetto restano da verificare. Le correzioni successive richiedono una nuova esecuzione
sul commit finale; il run iniziale non può verificarle.


La prima suite ha eseguito 261 test unitari senza errori e 12 test UI con due
fallimenti: drag verticale nel dettaglio Peso ora troppo corto per scorrere e
ricerca del menu Archivio che UIKit aveva collocato nel menu di overflow.
La seconda revisione espande il contenuto reale del metodo nel test del drag e
rende esplicito il menu Archivio nella toolbar. Il primo riferimento Apple è
stato acquisito con un avviso notifiche sovrapposto e senza dati: non dimostra
ancora le proporzioni delle card popolate. Il nuovo test prepara dati sintetici
tramite HealthKit, esclusivamente nel simulatore, chiude l'avviso e aggiunge Peso
ed Energia alimentare ai preferiti per acquisire il riferimento utile.

Il controllo visivo della prima build ha evidenziato overflow dei testi nelle
card Salute con Dynamic Type accessibilità. Le altezze vengono ora misurate sui
contenuti effettivi e uniformate al massimo necessario. Il grafico mini calorie
usa bin giornalieri e barre proporzionali, anziché barre sovrapposte. Restano da
verificare sul nuovo commit sia questi cambiamenti sia il flusso di importazione
che nella prima esecuzione non era stato raggiunto.


La seconda ispezione REA è riuscita: Info.plist binario e inventario completo di
929 record in Assets.car. Evidenze `ev_a0e72492adfd1d1694c114b30ea753fff75bf02f21b4aafda01a4c95041efeb1`
e `ev_9dfa31b7169520ea6528b64bdd3b7a229bda59fa1573b9d631021e50a4d614c8`.
Il catalogo ha SHA-256 `b8d92c28f61ea5b4b60b4a74003248109110766998e99448f142ca937833ef91`;
non sono stati copiati asset o binari Apple nel prodotto. La vista nativa di
consenso ha confermato i simboli `figure` per Peso e `apple.slice` per Nutrizione,
ora riusati nei due pulsanti con fallback per sistemi che non contengono il simbolo.

Il secondo test del riferimento non ha completato il consenso: i due switch erano
attivi, ma il comando Allow è esposto come StaticText e si trova sotto il viewport.
Inoltre i nomi delle metriche nel simulatore sono in inglese anche con la navigazione
italiana. Il test successivo scorre fino ad Allow e cerca le metriche tramite
identificativi HealthKit, usando i nomi osservati Dietary Energy e Weight.
Un nuovo gate impedisce il pacchetto se l'acquisizione del riferimento non passa,
pur consentendo di raccogliere gli esiti indipendenti dei test LifeOS.


Sul commit `1c0db695c49893bb185b3deda7f36ea882709b68` sono passati 264 test
unitari e 13 dei 14 test UI LifeOS, inclusi scorrimento grafici, dimensioni dei
pulsanti e uniformità delle card con testo accessibilità. Il test mancante ha
raggiunto la selezione reale del JSON in File: il selettore si è chiuso senza
presentare l'anteprima, riproducendo il problema segnalato. Il passaggio viene
ora gestito da un handoff che accetta i due eventi (risultato e chiusura) in
entrambi gli ordini, consegnando i byte una sola volta. Tre regressioni unitari
coprono risultato-prima, chiusura-prima e annullamento con nuovo tentativo;
il percorso del selettore di sistema resta una prova UI obbligatoria.

Le iterazioni diagnostiche marcate `[probe-78]` eseguono tutti i test unitari e
le prove UI della revisione 78 e del riferimento Apple, con artefatti completi.
Non generano pacchetti. Il commit candidato finale, senza questo marcatore,
richiede ancora il workflow completo con regressioni 74/75/77/78, avvii Release
e verifica dell'IPA. Il cerchio visivo dei pulsanti toolbar è 36 pt, come il
Profilo osservato in Apple Salute; la regione di interazione resta 44 pt.
