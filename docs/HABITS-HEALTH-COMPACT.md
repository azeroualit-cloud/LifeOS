# Abitudini programmate e salute compatta — 18 ottobre 2026

Richiesta: ridurre l’altezza della scheda peso/calorie e scegliere dalla gestione abitudini la ripetizione ogni N giorni oppure i giorni settimanali. Vale per web e iOS; autorizzazione alla pubblicazione e alla generazione IPA già fornita nella sessione.

## Contratto e migrazione

`backend/worker/habits.mjs` e `NativeRoutineSchedule.swift` condividono il contratto `schedule`: mode daily/interval/weekdays, intervalDays 1–365, weekdays ISO lunedì=1…domenica=7, startDate civile. Le abitudini senza schedule restano quotidiane. Una ricorrenza a intervalli parte dalla data scelta: saltare una spunta non sposta le date successive. La dashboard filtra le abitudini previste oggi; Gestisci le conserva tutte. Ogni data ha una spunta indipendente.

Migrazione additiva idempotente della sola colonna `os_routines.schedule_json`, senza cancellazione o riscrittura di `os_routine_checks`, marcatori os_meta o dati finanziari. Il server valida la ricorrenza prima di scrivere e rifiuta spunte fuori giornata/programmazione; una rinomina da un vecchio client conserva la programmazione. Limite portato da 8 a 100 abitudini per distribuire le abitudini su giorni differenti. `routineScheduleVersion:1` impedisce che i nuovi editor dichiarino salvata una programmazione su un Worker vecchio che la ignorerebbe. Demo locale e collegamento reale usano le stesse regole.

## Scheda salute

Il grafico riassuntivo passa da 180 a 120 punti, con spazi e riepilogo ridotti. Peso, TDEE, calorie e previsione rimangono visibili; toccando la scheda si apre il dettaglio esistente. L’altezza si adatta ai caratteri di accessibilità: nessun taglio forzato del testo.

## Verifica locale

106 test Foundation superati; 12 test dei modelli web (compreso confronto diretto JS/Swift su date civili, ora legale, anno bisestile e giorni saltati; migrazione SQLite del Worker reale con conservazione delle spunte). 34 test server Piani superati; due suite Chromium superate, inclusi creazione/modifica ricorrenze, selezione settimanale vuota, filtro dashboard, gestione completa e persistenza dopo reload. TypeScript, parsing Swift, contratto condiviso, demo e design system superati. Fixture esclusivamente sintetiche.

Sorgenti preparati come 0.9.6 build 57. Gli esiti Apple, l’IPA e il Raw verificati saranno registrati nella provenienza della consegna al completamento. Nessun deploy Cloudflare eseguito.
