# Build 93 - piano di implementazione e stato

Ramo `codex/build93`, base build 92 pubblicata (0.10.30 build 92). Obiettivo 0.10.31 build 93.
Autorizzazione IPA: `IPA-DELIVERY-93-2026-11-21` ("Sì IPA 93"), una sola IPA a gate verdi sullo stesso commit.
Riferimento visivo approvato: https://claude.ai/artifact/QAanqSYRowbYWgUKV8n271 (`BUILD93-PREVIEW-FINAL-2026-11-21`).
Inventario da rispettare: [BUILD-93-FEATURES.md](BUILD-93-FEATURES.md). Nessuna funzione della 92 può mancare.

## Come si compila

Su Linux non c'è Xcode. La CI assembla lo zip di base fissato (`lifeos-native.zip` al commit 02c2c08) più l'overlay `native-next/`
(vedi `.github/actions/native-compat76`). Un file della base si modifica copiandolo in `native-next/Sources`.
- `lifeos-compile93.yml`: compila e lancia i soli test unitari a ogni push su `native-next/**`. Mai IPA.
- `lifeos-candidate93.yml` (da creare alla fine): gate completo come la 92, poi IPA 0.10.31 build 93.

## Fasi

| Fase | Contenuto | Stato |
|---|---|---|
| 1 Dati online | Modulo `backend/bloom-foods` (stesse tabelle del sito, campi solo-app in `web_foods_app` e `web_bloom_app`, date Apple convertite anche per `trashedAt` con riparazione idempotente). `NativeOnlineSync`: il server decide, il telefono tiene cache e byte degli allegati; trasferimento automatico una tantum ripetibile senza doppioni; vince la modifica più recente; Worker vecchio = nessun cambiamento. Impostazioni: Dati sul server, Esporta backup completo (Bloom con allegati, alimenti, dati app). | Fatto: compilazione e test unitari verdi (run 44930586905, commit 60d5a63) |
| 1b Deploy Worker | `lifeos-bloomfoods-deploy93.yml` (solo avvio manuale) cambia solo `lifeos-native-test`. Lo avvia Nas. | Pronto, non distribuito |
| 2 Schede approvate | Dashboard, Attività, Calendario, Agenda, Dipingi turni, Salute (Cronologia a barre verticali, Simulazione peso, TDEE con criteri), fogli alimento/quantità/macro/obiettivi/peso/evento/abitudine/orari | Fatto nel codice (vedi "Fase 2 - stato"); ricerca immediata in Aggiungi alimento aggiunta il 22 novembre |
| 3 Finanza | Panoramica, Analisi interattiva (ordine Ritmo, Fondo con € al mese, Stima patrimonio con uscite programmate, Spese per categoria, Entrate e uscite, Stipendi, Giorno per giorno da luglio), Avvisi regolabili (`FINANCE-ALERTS-2026-11-21`), Budget, Movimenti, fogli con blocco "Da dove arrivano i soldi" (`FUNDING-BLOCK-2026-11-21`) | Fatto nel codice, vedi "Fasi 3-5 - stato" |
| 4 Bloom | Mappa con pin per categoria, gruppi, filtro a tendina, scheda con frecce; schede | Fatto nel codice, vedi "Fasi 3-5 - stato" |
| 5 Gate e IPA | Versione 0.10.31/93, workflow candidate93, controlli scala aurea e continuità linee, suite UI completa, 4 avvii Release, IPA | In corso |

## Regole di lavoro

- Conservare identificativi di accessibilità e titoli di navigazione usati dai test UI; cambiare l'aspetto, non i percorsi.
- Nessun testo esplicativo nelle schermate (decisione dell'anteprima).
- Gli allegati di Bloom restano sul telefono: il server conserva il nome. Una nota creata sul sito con un file non presente sul telefono appare come nota.
- La CI verde non è accettazione del prodotto (la build 78 fu rifiutata nonostante i test verdi).

## Fase 2 - stato (21 novembre 2026, sessione Claude)

Riferimento: anteprima canvas versione 1795280675-e4db. L'esportazione locale "LifeOS build 93 - Finanza e dati online.html" fornita da Nas come bozza finale coincide con il canvas per tutte le 21 tavole della fase 2 (markup e logica identici a meno della rinomina dell'esportazione).

Decisioni confermate in questa fase (META-01, risposta «Sì, sostituisci» a ciascuna domanda):
- `NUTRITION-GOALS-93-2026-11-21` sostituisce `MACRO-NO-GOALS-92` (obiettivi calorie e macro).
- `HEALTH-TREND-93-2026-11-21` sostituisce `HEALTH-GRID-3X2-92` (Andamento in Salute).
- `DASHBOARD-93-2026-11-21` sostituisce `DASHBOARD-ORDER-92` (Finanza come scheda intera).

Fatto nel codice (`native-next/`):
- Token in scala aurea (2, 5, 8, 13, 21, 34; righe 55 pt; schede 21 pt; margine 16 pt) in `NativeDesign.swift`; componenti `DesignSystem/LOProgress.swift` (barre, barra divisa, valore macro, stepper, schede valore, colonne impilate).
- Salute: giorno, calorie con obiettivo e barra per macro, micronutrienti in evidenza, Diario in scheda, Andamento 1/3/6 mesi con Peso, TDEE, Media calorie, Media proteine, Peso e simulazione, Calorie per giorno.
- Foglio Obiettivi (`NativeNutritionGoalsSheet.swift`): calorie dal TDEE con deficit o fisse, proteine e grassi in g o g/kg (peso medio 7 giorni), carboidrati dal resto. Salvati sul telefono (UserDefaults), non sul server.
- TDEE (`NativeTDEEScreen`): finestra 7-28 giorni, kcal per kg, giorni mancanti massimi, pendenza mediana o regressione; i predefiniti riproducono il calcolo della 92. Il criterio scelto vale in tutta l'app.
- Simulazione peso (`NativeWeightSimulationScreen`): trend reale o calorie, orizzonte fino a 26 settimane, obiettivo di peso con calorie necessarie.
- Cronologia: barre impilate P/C/G per Giorni, Settimane, Mesi, Trimestri con linea dell'obiettivo; elenco per giorno con modifica ed eliminazione conservato.
- Dashboard: prossimo turno, Cose da fare in scheda, Nutrizione con obiettivi (Peso a sinistra, Alimento a destra), Finanza intera con barra speso/rimane, Prossimi appuntamenti.
- Attività: categoria a tendina con "Tutte", Da fare / Abitudini, sezioni Oggi, Prossimi giorni, In attesa (conservata dalla 92), Completate.
- Calendario: Oggi in vetro, selettore Mese / Agenda, pennelli con il colore del turno, giorni successivi nell'Agenda con turno e impegni.
- Fogli: Peso con valore grande e variazione dall'ultima pesata; Nuova abitudine con ripetizione a segmenti e giorni a lettere; Orari con riga breve.
- UI test: stessi identificativi; aggiornate solo le asserzioni legate alle regole sostituite (ordine griglia Salute, altezza Finanza, titolo Cronologia, categorie a tendina, ripetizione abitudini).

Non fatto o volutamente escluso:
- Fogli Aggiungi alimento, Quantità, Macro a mano, Alimento personale, Evento, Categorie: restano quelli della 92 con i nuovi token; la ricerca immediata e il layout dell'anteprima sono da fare.
- Interruttori dell'anteprima senza funzione nella 92 o sul server (Categoria e Promemoria delle abitudini, "Salva anche in Apple Salute" facoltativo): non disegnati per non mostrare controlli finti.
- Pennelli Dipingi turni restano nell'intestazione (non in basso come l'anteprima) per non toccare la geometria provata dai test del calendario.
- Nessuna prova al simulatore delle nuove schermate in questa sessione: solo compilazione e test unitari in CI. Le catture del workflow di sviluppo sono la prima verifica visiva.

Verifica tecnica: compilazione e 358 test unitari verdi, 0 falliti ([run 44949689104](https://github.com/azeroualit-cloud/LifeOS/actions/runs/44949689104), commit `9367df7`). Anteprima di sviluppo con controlli UI selezionati e catture reali verde ([run 44949689024](https://github.com/azeroualit-cloud/LifeOS/actions/runs/44949689024), artefatto `lifeos-development-preview-9367df7…`). La suite UI completa resta per la fase 5. Non è accettazione del prodotto.

## Fasi 3-5 - stato (22 novembre 2026, sessione Claude)

Istruzione dell'utente: `IPA-COMPLETE-ONLY-93-2026-11-22` («io voglio solo ipa completo capisci o no?»): niente revisioni intermedie, IPA completa a gate verdi.

Fatto nel codice:
- Panoramica Finanza (`NativeFinance93.swift`, `FinanceScreen.swift`): budget rimanente con barra per categoria (palette Monocromo), speso di totale e giorno del mese, conto principale in scheda, quattro azioni, ultimi movimenti in scheda, "Dove va lo stipendio" a riquadri (impegni, messo da parte, speso per categoria, libero) con dettaglio e altre voci del gruppo. Occhio "Nascondi importi" nell'intestazione.
- Analisi (`FinanceAnalysisScreen.swift`, `NativeFinanceAnalysis93.swift`): Ritmo (norma dai mesi completi di `yearly`, ultimo mese e ultimi 3 mesi), Quanto dura il fondo (`planning.now`, eccedenza media da `forecastHistory`, spesa al mese regolabile a passi di 50 €), Stima patrimonio (previsione esistente, stime in ciano), Spese per categoria a barre con media al mese, Entrate e uscite, Stipendi per competenza, Giorno per giorno, Patrimonio.
- Avvisi (`NativeFinanceAlerts93.swift`, Impostazioni → Avvisi di Finanza): Ritmo sopra la norma (5-30%, 10%), Spese ricorrenti fuori norma (+10..60%, +25%; 5..50 €, 15 €), Riepilogo del lunedì (6-21, 9); limiti 1 a settimana / 1 per voce al mese / 1 al mese in tutto; silenzio 22-8. Notifiche locali calcolate sul telefono a ogni aggiornamento della Finanza, mai in demo.
- Budget: Stipendio, Piani e impegni, Budget del mese; piani del mese con tipo e residuo; testi esplicativi tolti. Movimenti: ricerca, categoria e conto a tendina, totale della categoria, sezione "Sul dispositivo".
- Blocco "Da dove arrivano i soldi" in spesa/bolletta/modifica destinazione: barra piano/risparmi/budget e importi.
- Bloom: pin colorati per tipo di luogo, filtro a tendina con conteggi, scheda del luogo con frecce precedente/successivo, Apri nota/e e Apri in Mappe.
- Versione 0.10.31 build 93 in `project.yml`; `scripts/verify-candidate93.py`.

Limiti dichiarati:
- "Da dove arrivano i soldi": la divisione manuale fra risparmi e mesi di budget e la restituzione dei mesi del piano richiedono un Worker che le gestisca; l'app mostra e invia solo le destinazioni già supportate (piano con resto dai risparmi, risparmi, budget).
- Ritmo usa mesi completi (ultimo mese, ultimi 3 mesi) perché il server invia i totali mensili, non giornalieri; Giorno per giorno usa i movimenti del mese caricato.
- Avvisi solo locali: nessun invio dal server; il tocco apre la Dashboard.
- Fogli Quantità, Macro a mano, Alimento personale, Evento e Categorie restano moduli iOS raggruppati con i nuovi token.

## Diario alimentare condiviso e sito (22 novembre 2026)

Decisioni: `FOOD-DIARY-SERVER-2026-11-22` (diario sul server, registrato dal telefono e modificabile dal PC; peso solo in Apple Salute), `SITE-PARITY-2026-11-22` (il sito non ha mai meno dell'app). Su richiesta dell'utente («No, nella 93») il diario entra nella build 93: il run candidato 45030075390, già verde sulla suite completa, è stato annullato prima della pubblicazione; nessuna IPA prodotta. `scripts/verify-candidate93.py` rifiuta l'IPA senza `NativeFoodDiarySync.swift`.

- Server (`backend/bloom-foods`, Worker `lifeos-native-test`): tabella `web_food_diary` nel D1 condiviso; `listFoodDiary(since)`, `listFoodDiaryDays(from,to)`, `saveFoodDiaryEntry`, `deleteFoodDiaryEntry`, `importFoodDiary`. Vince la modifica più recente (`modified` in millisecondi); le eliminazioni restano come righe `deleted`; il giorno è quello di Roma. Test Node verdi.
- App (`NativeFoodDiarySync.swift`): ogni pasto salvato o eliminato entra in coda per il server; lo storico del telefono viene inviato una volta (ripetibile senza doppioni); le modifiche dal PC vengono scritte in Apple Salute con revisione più alta (sostituisce i campioni precedenti), le eliminazioni tolte da Apple Salute. Worker vecchio: nessun cambiamento sul telefono, la coda resta. Test unitari in `NativeFoodDiarySyncTests.swift`.
- Sito (ramo `codex/revision77`, `web/`): Diario per giorno in Nutrizione con totali, aggiunta da alimento personale o macro a mano, modifica (la quantità scala macro e micronutrienti) ed eliminazione; stessi metodi nel Worker `lifeos`. Inoltre: mappa Dove va lo stipendio con testo in ogni riquadro e popup di voce e gruppo; Analisi con Ritmo, Quanto dura il fondo, Giorno per giorno; Da dove arrivano i soldi con Risparmi; Avvisi di Finanza.

Distribuzione: i due Worker (`lifeos-native-test` con `lifeos-bloomfoods-deploy93.yml`, `lifeos` con `web/DEPLOY.md`) li distribuisce l'utente. Senza di essi l'app continua a funzionare solo sul telefono.

## Deploy dei Worker (22 novembre 2026, DEPLOY-WORKERS-93-2026-11-22)

- `lifeos` (sito): interfaccia e diario da `codex/revision77` @ `3131f85`, run [45065087236](https://github.com/azeroualit-cloud/LifeOS/actions/runs/45065087236): caricamento verificato da Cloudflare.
- `lifeos` (sito) aggiornato a `codex/revision77` @ `efeadad` (settimana orizzontale in Dashboard, calendario mese + agenda, avvisi ignorabili), run [45066372338](https://github.com/azeroualit-cloud/LifeOS/actions/runs/45066372338): verificato, Worker attivo.
- `lifeos` (sito) aggiornato a `codex/revision77` @ `33cbe99` (Dashboard senza scheda turno e Abitudini accanto a Da fare, badge turno a una lettera rettangolari, colori turni del foglio TEAM H24, agenda solo giorni con eventi), run [45067563120](https://github.com/azeroualit-cloud/LifeOS/actions/runs/45067563120): verificato.
- `lifeos-native-test` (app): Bloom, alimenti personali e diario, run [45065698114](https://github.com/azeroualit-cloud/LifeOS/actions/runs/45065698114): caricamento verificato e lettura reale di alimenti, Bloom e diario riuscita con il login di prova.
- Token Cloudflare e password di prova rinnovati dall'utente nei segreti del repository. Database, accesso e segreti dei Worker conservati.
- Non è ancora stata fatta una prova d'uso reale sul sito nel browser né sull'iPhone.


## Stato IPA 93 (22/11/2026)

- Candidato completo verde nella run [45057419266](https://github.com/azeroualit-cloud/LifeOS/actions/runs/45057419266) (sorgente `ec8d16a`): suite completa, quattro avvii Release e pacchetto riusciti; IPA nell'artifact `LifeOS-93-ec8d16a0a04472b8b7ea25ed800550b8164eb885-1`.
- Pubblicazione della release `ios-0.10.31-build93` rifiutata da GitHub con HTTP 403 (token Actions senza scrittura), anche nella ripresa dedicata `lifeos-publish93-retry.yml` (run 45073413159 e 45076302501). Serve verificare i permessi Actions del repository.
- Prove fisiche su iPhone e accettazione dell'utente ancora aperte.
- 22/11/2026: in Salute «Peso» a sinistra e «Alimento» a destra, come in Dashboard (richiesta utente), con controllo nel test UI. Nuovo candidato completo avviato (Start 10).
- 22/11/2026: tentativo 10 fermato su richiesta dell'utente (commit `[hold]`). Agenda dell'app: dopo il giorno scelto mostra solo i giorni con impegni nei 30 giorni successivi (carica anche il mese dopo). IPA da non avviare finché l'utente non lo chiede.
- 22/11/2026: meno padding nell'app (margine interno schede 21→16 pt, spazio tra sezioni 34→21 pt, sempre sulla scala aurea; Peso/Alimento nella scheda Nutrizione alti 44 pt). Scheda Finanza in Dashboard più densa: legenda Speso/Budget con giorni rimasti e ultime due spese del mese. IPA non avviato.
- 22/11/2026: mappa Bloom senza scala (si sovrapponeva al filtro luoghi); scheda del luogo più compatta: tocco sulla scheda apre le note, pulsanti «Mappe» e «Waze» (link universale waze.com/ul). IPA non avviato.
- 22/11/2026: Attività, categorie come fila di pulsanti (un tocco) invece del menu a tendina; «Da fare / Abitudini» sopra, pulsante cartella per gestire le categorie. IPA non avviato.
- 22/11/2026: Salute in stile Fitia (richiesta utente): settimana senza scheda con titolo «Oggi»/giorno, lettere con cerchio sul giorno scelto e pallino colorato per fascia calorie (±10 % obiettivo); scheda calorie centrata con arco e fascia obiettivo, macro in colonne centrate. Il riquadro Micronutrienti resta separato. IPA non avviato.
- 22/11/2026: Calendario, scatti durante lo scorrimento segnalati dall'utente: le posizioni delle settimane si misurano solo mentre si raggiunge una settimana richiesta (prima a ogni fotogramma). Da verificare su iPhone. Le modifiche dopo il candidato 93 andranno nella build 94, da avviare solo su richiesta dell'utente.
- 22/11/2026: SPACING-SYSTEM-2026-11-22 applicato: schede 13 pt sopra/sotto e 16 ai lati, 8 pt tra le righe, 13 pt tra le schede in Dashboard, testata Micronutrienti senza altezza forzata. Anteprima disegnata pubblicata come artifact privato. IPA 94 da avviare solo su richiesta.
- 23/11/2026: correzione compilazione (scheda luogo Bloom divisa in viste più piccole). Bloom: «Waze» sempre visibile, «Mappe» chiede ogni volta Apple Mappe o Google Maps (app, altrimenti web). Salute: scheda calorie con obiettivo nello stesso carattere del valore, macro con valore e obiettivo della stessa dimensione, arco più curato (fascia obiettivo come tratto chiaro, riempimento sfumato, pallino finale con spunta nella fascia).
