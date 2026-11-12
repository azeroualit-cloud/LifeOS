# LifeOS — candidato finale verificato, 12 novembre 2026

## Evidenza e sorgenti

- Prodotto e risorse: `8ac2d4f5725d624f8a89f8458cf7c03dc2242bc9`.
- Test corretti e selezione CI: `f9015294e7b37a6ae7be416fffdd298062e263bc`.
- Gate originale: https://github.com/azeroualit-cloud/LifeOS/actions/runs/43232065358 — fallito, conservato come tale.
- 299 unitari + 11 UI preflight passati; restante suite 93 passati e 2 falliti; zero saltati. Totale 405 casi.
- Quattro avvii Release passati sul prodotto originale; non ripetuti.
- Recupero: https://github.com/azeroualit-cloud/LifeOS/actions/runs/43249620310 — successo, solo 2 UI, zero fallimenti.
- Copertura aggregata 405/405: 403 nel gate originale, due nel recupero. Non è una suite monolitica nuovamente eseguita.
- Confronto Git verificato: nessuna modifica a Sources, Resources, Shared, Widget o project.yml rispetto al prodotto originale.

## Diagnosi e correzioni

1. `testCompactMacroDecimalInputAndKeyboardProgression`: il test forza it_IT ma pretendeva `101.8 kcal`. L’interfaccia visualizza correttamente `101,8 kcal`; corretta solo l’aspettativa.
2. `testBloomCancelClosesFilesAndAllowsRetry`: verifica immediata di isHittable dopo annullamento File. Il video originale mostra il caricamento e lo spostamento del controllo Annulla durante la navigazione File. Il test ora attende la Libreria esistente e interattiva, con screenshot/gerarchia in caso di errore, poi ripete apertura e annullamento. Entrambi i cicli passati. Nessuna modifica al prodotto.

## Ispezione visiva

Esaminate catture reali di Salute standard/grande, Dashboard, Bloom, palette turni con testo grande, Spesotti 250 ml = 117,5 kcal, fibre mancanti come “—”, cronologia per giorno. Esaminate le due nuove catture: macro 101,8 kcal e Bloom tornato alla Libreria dopo il secondo annullamento.

Artefatti originali: 13958196195 (validazione), 13956803349 (diagnostica), 13953910232 (Release). Recupero: 13958559454 (test e catture), 13957869801 (diagnostica). Dati esclusivamente sintetici.

## Limiti e passi dell’utente

Candidato tecnico verificato al simulatore; nessuna accettazione per produzione. Nessuna IPA creata, confezionata o distribuita; nessun deploy backend. Prima eventuale distribuzione: revisione utente e richiesta IPA esplicita. Poi firma/installazione preservando dati, parità personale Bloom/Finanza, HealthKit fisico, App Group/widget, AlarmKit/suono e accettazione esplicita. Non ripetere test già chiusi in assenza di nuove modifiche pertinenti.
