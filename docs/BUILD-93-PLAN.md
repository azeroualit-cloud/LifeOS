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
| 2 Schede approvate | Dashboard, Attività, Calendario, Agenda, Dipingi turni, Salute (Cronologia a barre verticali, Simulazione peso, TDEE con criteri), fogli alimento/quantità/macro/obiettivi/peso/evento/abitudine/orari | In corso: vedi "Fase 2 - stato" sotto |
| 3 Finanza | Panoramica, Analisi interattiva (ordine Ritmo, Fondo con € al mese, Stima patrimonio con uscite programmate, Spese per categoria, Entrate e uscite, Stipendi, Giorno per giorno da luglio), Avvisi regolabili (`FINANCE-ALERTS-2026-11-21`), Budget, Movimenti, fogli con blocco "Da dove arrivano i soldi" (`FUNDING-BLOCK-2026-11-21`) | Da fare |
| 4 Bloom | Mappa con pin per categoria, gruppi, filtro a tendina, scheda con frecce; schede | Da fare |
| 5 Gate e IPA | Versione 0.10.31/93, workflow candidate93, controlli scala aurea e continuità linee, suite UI completa, 4 avvii Release, IPA | Da fare |

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

