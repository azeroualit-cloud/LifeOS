# Life OS iOS

L’app mobile è scritta in **Swift**, con **SwiftUI** per interfaccia e navigazione, **Swift Charts** per i grafici, **SF Symbols** per le icone e **HealthKit** per peso e calorie. Colori, spaziature e componenti Life OS sono definiti sopra queste API native; non c’è un framework grafico di terze parti.

## Sorgenti e build

Su questo ramo la sorgente corrente è `native-next/`, un overlay sulla build 60 fissata nel workflow `.github/workflows/lifeos-build.yml`. Il workflow assembla la cartella `app/`, genera il progetto con XcodeGen e compila/testa su macOS. Il vecchio ZIP nella radice e la cartella `native/` sono riferimenti storici e non rappresentano da soli l’app corrente. La sezione Salute appartiene alla mobile app, non alla webapp.

- Editor unico: `native-next/Sources/NativeActivityEditor.swift`.
- Stato, archivio locale e sincronizzazione: `native-next/Sources/NativeStore.swift`.
- Regole attività locali e validazione: `NativeLocalActivity.swift`, `NativeActivityDraft.swift`.
- Design system: `native-next/Sources/NativeDesign.swift`.
- Grafici/calibrazione: `NativeHealthViews.swift`, `NativeHealthModel.swift`.
- Servizio backend attività: `backend/activities/activities.mjs`.

[Schema, comportamenti e verifiche della revisione 68](docs/native/STANDARDIZATION-68.md). La distribuzione sui Worker live è separata dalla compilazione: avvio manuale oppure commit esplicito con marcatore dedicato sul workflow. Build 68 e aggiornamento backend verificati dopo l’autorizzazione dell’utente; risultati e link IPA nel documento collegato.
