# LifeOS — tecnologie, dati e flussi correnti

Aggiornato il 4 novembre 2026. Mappa del codice versionato, non certificazione di ogni comportamento sul telefono o in produzione.

## Tecnologie e punti di ingresso

| Area | Tecnologia / sorgente |
|---|---|
| App iPhone | Swift, SwiftUI, UIKit; `native-next/Sources/App.swift` e `native-next/project.yml` |
| Stato e sincronizzazione | `NativeStore.swift`, archivi locali e chiamate al backend; non confondere fixture/demo con dati reali |
| Interfaccia | API Apple, SF Symbols, Liquid Glass condizionale; token in `NativeDesign.swift`, controlli comuni in `NativeNavigation.swift`/`NativeComponents.swift` |
| Grafici e Salute | Swift Charts, HealthKit; `NativeHealthSummary.swift`, `NativeHealthViews.swift`, `NativeHealthStore.swift`, `NativeHealthModel.swift` |
| Nutrizione | `NativeNutritionQuickEntry.swift`, `NativeNutritionScreen.swift`, `NativeNutrition.swift`; archivio condiviso e operazioni recuperabili |
| Calendario/attività | `CalendarScreen.swift`, `NativeCalendar*`, `NativeActivityEditor.swift`, `NativeActivity*` |
| Bloom | `NativeBloomScreen.swift`, `NativeBloomStore.swift`, `NativeBloomBackupPicker.swift`, `NativeBloomPickerHandoff.swift`; archivio locale, file/allegati e componenti MapKit/Quick Look/Photos |
| Widget e automazioni locali | WidgetKit, App Intents, App Group; `native-next/Widget` e `Shared`; AlarmKit disponibile su versioni supportate |
| Finanza | `FinanceScreen.swift`, `NativeFinanceViews.swift`, `NativeExpenseRouting*`, `NativeUtility*` |
| Backend | JavaScript ES modules, Cloudflare Workers, D1/SQLite e Cloudflare Access; `backend/activities`, `expense-routing`, `movement-order`, `utilities` |
| Web | HTML/CSS/JavaScript, `web/app.html`, `web/worker.mjs`, `web/build.py`; Playwright per verifiche browser |
| Build iOS | XcodeGen + Xcode; GitHub Actions su runner macOS `xcode-27`; selezione compatibile SDK 27.0; deployment target dichiarato iOS 17 |
| Verifiche | XCTest/XCUITest, test Node/Python e verificatori IPA/Mach-O. REA 6.8.0 è usato per l’ispezione del riferimento Apple, non è una dipendenza dell’app |

La mela nutrizione ha un glifo vettoriale originale di fallback: l’asset interno Apple non era disponibile come SF Symbol pubblico nel runtime verificato. Non descriverlo come asset Apple incorporato.

## Navigazione e flussi

```text
Dashboard ─┬─ settimana → Calendario completo → giorno/agenda/editor
           ├─ eventi oggi → abitudini oggi → eventi domani/dopodomani
           ├─ Finanza → dettagli; Aggiungi spesa → editor movimento
           ├─ nutrizione inline → valori/100g → porzione → salvataggio
           └─ ora preghiera → orari completi
Attività ─── elenco → editor unificato → stato/completamento/sincronizzazione
Salute ───── TDEE / Peso / Calorie / Simulazione → dettagli
           └─ azioni peso e macro
Bloom ────── Libreria / Mappa / Riscopri
           ├─ File → lettura → chiusura picker → anteprima → conflitti → importazione
           └─ archivio locale + allegati → ripristino dopo riavvio
```

### Integrità dei dati

- Nutrizione: valori per 100 g scalati sui grammi reali; kcal dell’etichetta per i nuovi record. I legacy conservano la propria semantica. Scrittura locale prima dell’operazione HealthKit, identificativi/revisioni stabili per retry; nessuna cancellazione dei campioni di altre app.
- Lettura calorie: somma delle registrazioni di tutte le fonti nel periodo letto, senza selettore fonte. Evitare duplicazioni create dai retry LifeOS non significa deduplicare arbitrariamente le fonti lette.
- Bloom: backup personale esterno ai sorgenti, importazione con anteprima e conflitti, copia di sicurezza e allegati verificati. Nessuna nuova sincronizzazione remota Bloom implicita.
- Bollette: periodo esplicito, quote per competenza che sostituiscono stime, pagamento bancario unico e nessun doppio conteggio con il fondo. Verificare compatibilità server prima dell’invio.
- Identità: conservare bundle `com.nas.lifeos.probe`, widget `com.nas.lifeos.probe.quickactions`, App Group `group.com.nas.lifeos`, archivi e icona scelta. Aggiornamenti senza disinstallazione.

## Assemblaggio e controlli

La procedura corrente è `.github/actions/native-compat76/action.yml`: scarica la base dal commit `02c2c089841833a67fc9a223b367710edf7e37b9`, verifica SHA-256 `b09762b88e4dc017d2c89fa7582ac38daf1fddf5aa0dd12fed94d73f6099ef03`, applica `native-next/`, esegue il checker del design system e genera il progetto con XcodeGen.

Non modificare soltanto `lifeos-native.zip` o una copia estratta. Windows non offre Xcode: le prove iOS richiedono il runner Mac o un Mac disponibile.

Comandi di riferimento già presenti, da eseguire nel contesto corretto:

```sh
# Dopo l’assemblaggio della cartella app tramite l’action:
python3 app/scripts/check-design-system.py
cd app
xcodebuild build-for-testing -project LifeOSProbe.xcodeproj -scheme LifeOSProbe -destination 'platform=iOS Simulator,id=<device>'
# Vedere il workflow per entitlements, firma simulatore, suite e limiti effettivi.
```

```sh
# Dalla root repository, su un’IPA prodotta:
python3 scripts/verify-native-package.py <file.ipa> --version <versione> --build <build>
python3 scripts/verify-startup-imports.py <file.ipa>
```

Workflow della build 78: `.github/workflows/lifeos-revision78.yml`; è vincolato al ramo storico `codex/revision77`. Non assumere che un push su main avvii lo stesso percorso. Il vecchio workflow generale può contenere deploy: leggerlo prima di usarlo. Nuovi cambi applicativi richiedono verifiche pertinenti; non usare skip CI per fingere controlli passati.

Per il web esistono `npm ci`, `npm run build`, `npm test`, `npm run test:tasks` dentro `web/`; consultare `web/README.md` per fixture e browser. Le sue vecchie dichiarazioni di allineamento non certificano la parità live attuale. Per backend usare test sintetici appropriati e verificare i binding; non fare prove su movimenti reali.

## Bloom: griglia e anteprime link (H-GRID-01)

`NativeBloomLibraryContent.swift` usa due colonne lazy con larghezze esplicite e immagini proporzionate. `NativeBloomLinkPreview.swift` recupera immagine/titolo tramite LinkPresentation, conserva una cache eliminabile separata dall’archivio e mostra un fallback se i metadati non arrivano. `NativeBloomVisualFixture.swift` espone solo in DEBUG la fixture mista separata; non modifica lo store personale quando i flag di prova non sono presenti. Nessuna migrazione dello schema delle note. Flusso: card visibile → cache/metadati → preview o fallback → apertura del dettaglio originale. Prove e limiti in `BLOOM-GRID-REVIEW.md`.
