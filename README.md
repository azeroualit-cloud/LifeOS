# Life OS iOS

L’app mobile è scritta in **Swift**, con **SwiftUI** per interfaccia e navigazione, **Swift Charts** per i grafici, **SF Symbols** per le icone, **HealthKit** per peso e calorie e **WidgetKit** per il widget 2×2 e **AlarmKit** per le sveglie urgenti su iOS 26+. Colori, spaziature e componenti Life OS sono definiti sopra queste API native; non c’è un framework grafico di terze parti.

## Sorgenti e build

Su questo ramo la sorgente corrente è `native-next/`, un overlay sulla build 60 fissata nel workflow `.github/workflows/lifeos-build.yml`. Il workflow assembla la cartella `app/`, genera il progetto con XcodeGen e compila/testa su macOS. Il vecchio ZIP nella radice e la cartella `native/` sono riferimenti storici e non rappresentano da soli l’app corrente. La sezione Salute appartiene alla mobile app, non alla webapp.

- Editor unico: `native-next/Sources/NativeActivityEditor.swift`.
- Stato, archivio locale e sincronizzazione: `native-next/Sources/NativeStore.swift`.
- Regole attività locali e validazione: `NativeLocalActivity.swift`, `NativeActivityDraft.swift`.
- Design system: `native-next/Sources/NativeDesign.swift`.
- Grafici/calibrazione: `NativeHealthViews.swift`, `NativeHealthModel.swift`.
- Servizio backend attività: `backend/activities/activities.mjs`.

[Schema, comportamenti e verifiche della revisione 68](docs/native/STANDARDIZATION-68.md). La distribuzione sui Worker live è separata dalla compilazione: avvio manuale oppure commit esplicito con marcatore dedicato sul workflow. Build 68 e aggiornamento backend verificati dopo l’autorizzazione dell’utente; risultati e link IPA nel documento collegato.

[Revisione 72: correzioni e verifiche](docs/native/REVISIONE-72.md) · [IPA diretta 0.10.11 build 72](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.11-build72/LifeOS-72.ipa). Superati **213 unitari e 44 esecuzioni UI**. Selettore data completo, calendario senza cerchi grandi, settimana con sette turni, intestazione unica, agenda compatta con eventi annidati e pillole di tutto il giorno; Finanza con importo ridotto e meno divisori. Download pubblico verificato. Aggiornare con Signulous senza disinstallare; nessun deploy Cloudflare necessario.

[Revisione 71: struttura, modifiche e verifiche](docs/native/REVISIONE-71.md) · [IPA diretta 0.10.10 build 71](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.10-build71/LifeOS-71.ipa). Superati **207 unitari e 36 esecuzioni UI**. Calendario mese/giorno, editor dal basso, Dipingi ispirato a Supershift, Finanza ristrutturata, accento Salute arancione e sveglie urgenti locali. Icona attuale conservata. Per il widget rimuovere quello vecchio e aggiungere **Life OS · Oggi**; firma App Group e suono su iPhone fisico restano da verificare. Aggiornare senza disinstallare. Nessun nuovo deploy Cloudflare necessario.

[Revisione 70: modifiche, schema e verifiche](docs/native/REVISIONE-70.md) · [IPA diretta 0.10.9 build 70](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.9-build70/LifeOS-70.ipa). Superati 199 unitari e 33 esecuzioni UI; pacchetto scaricato e verificato. Entrambi i Worker Cloudflare aggiornati e verificati per l’ordinamento dei movimenti per inserimento.

Il widget informativo usa solo il formato piccolo, sette giorni di turni e riepiloghi. La condivisione dati richiede una rifirma compatibile con l’App Group `group.com.nas.lifeos` per app ed estensione: il provisioning Signulous sul telefono resta da verificare. [Storico Dashboard 69](docs/native/REVISIONE-69.md).
