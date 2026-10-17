# 0.9.2 build 53 — calibrazione TDEE sullo storico

Il precedente estimatore leggeva otto settimane e usava soltanto 35 giorni. Faceva una regressione sul peso già smussato, poi la confrontava con l'introito medio, perdendo l'allineamento fra cambi di alimentazione e cambi di peso.

Ora HealthKit legge fino a sei mesi. La calibrazione usa calorie cumulative e pesate originali nelle stesse date: C(t) − 7.700 × [W(t) − W(0)] rappresenta la spesa energetica cumulativa approssimata. La mediana delle pendenze fra pesate su intervalli lunghi stima la spesa media storica. Intervalli minimi 21 giorni, oppure 56 quando lo storico copre almeno 84 giorni. La mediana mobile rimane solo nel grafico e nel peso di partenza dello scenario, senza introdurre ritardo nella calibrazione.

Requisiti: almeno 28 giorni, 10 pesate, ultima pesata conclusa non più vecchia di 7 giorni e calorie registrate in almeno il 90% dei giorni. Piccoli buchi sono stimati dalla media dei giorni registrati: numero e sensibilità dell'ipotesi ±500 kcal per ciascun giorno mancante sono espliciti. Non è un intervallo di confidenza. Oggi escluso. Registrazioni parziali non sono distinguibili automaticamente. Nessuna somma fra app alimentari diverse.

La UI indica TDEE medio storico, date, pesate, giorni registrati/stimati e introito medio di calibrazione. Arrotondamento a 50 kcal per evitare precisione apparente. L'introito dello scenario usa gli ultimi 28 giorni registrati, distinto dalla media dell'intero storico. Il grafico mantiene le ultime sei settimane, con assi ricavati dai dati visibili. Le modifiche non contengono dati personali.

È una calibrazione del bilancio energetico, non una misura del metabolismo attuale: la conversione 7.700 kcal/kg rimane un'approssimazione e acqua, glicogeno e tessuti non sono identificabili esattamente. La spesa può essere cambiata durante i mesi osservati. Il modello dinamico approssimato dello scenario non è il modello NIH completo.

Verifica locale: 70 test passati, inclusi intake variabile con TDEE noto sintetico, uso di oltre 35 giorni, calorie recenti distinte dalla calibrazione, gap espliciti, copertura insufficiente e pesata isolata anomala. Parser Swift e design system passati. Esito Apple da registrare dopo la build.

## Verifica Apple e consegna

Run 39003281979: compilazione riuscita; 86 test unitari e tre test UI mirati passati. Il runner compatto non aveva avviato il test per AXDisableAccessibilityOnTermination / kAXErrorCannotComplete, non per un'asserzione dell'app. Nessun cambiamento applicativo fatto per questo errore infrastrutturale.

Run 39004080051: compilazione ripetuta, identità dello ZIP sorgenti verificata via SHA256 793db8f24d559fde21e45b5f8a5d94e0f69d3c99e258cfc0fba21f8a8d4fc236 prima di riusare i risultati precedenti. Simulatore compatto avviato esplicitamente; testHealthScenarioCanBeEditedWithoutAddingNavigationTab passato (45,535 secondi), un test e zero errori. Archive iPhone riuscito e Info.plist controllato direttamente: 0.9.2 (53), iPhoneOS, com.nas.lifeos.probe, descrizione privacy HealthKit presente.

Artefatto originale: https://github.com/azeroualit-cloud/LifeOS/actions/runs/39004080051/artifacts/12090825594
Release per download diretto: https://github.com/azeroualit-cloud/LifeOS/releases/tag/v0.9.2-build53

Firma finale e uso su dispositivo restano separati dalla verifica Apple automatizzata. La stima è una media storica del bilancio energetico, non una misura del TDEE attuale. Nessun dato personale è incluso in sorgenti, test o release.
