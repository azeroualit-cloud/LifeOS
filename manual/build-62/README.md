# Life OS 0.10.1 (62) — aggiornamento manuale

## Regole

- Attivo mostra gli eventi da oggi fino a sette giorni dopo, estremi inclusi. Oggi e domani precedono le attività; gli eventi dei giorni successivi seguono le attività singole.
- Eventi completati e passati sono esclusi dalle attività. Restano nel calendario; il passato appare concluso in base al giorno, senza creare conferme manuali fittizie. Una data futura riattiva un evento singolo; per spostare una parte di una serie si conserva il comando Modifica da questa occorrenza.
- Attività senza data: Attivo o In attesa secondo lo stato scelto. Una programmazione futura resta nascosta fino al giorno previsto; quelle già arrivate restano disponibili.
- Le attività completate sono conservate per categoria, in fondo in Completate, chiusa di default. Ogni sezione vuota scompare. Il cerchio riapre l'attività nel suo stato originale. Nessuna distinzione fra liste usa e getta o riutilizzabili, nessuna cancellazione automatica.
- Cambio giorno e completamento offline aggiornano anche l'elenco operativo, mantenendo identità e ricorrenze.
- I mesi del calendario scorrevole sono abbreviati: Set, Ott, Nov. VoiceOver mantiene il mese completo con l’anno.

## Worker da copiare

Il file worker.js è un modulo completo, identico per i due Worker esistenti.

1. In lifeos-native-test, sostituire il contenuto del modulo di ingresso native-gateway.js con il contenuto del file worker.js fornito.
2. In lifeos, sostituire il contenuto del modulo di ingresso worker.js con lo stesso file.
3. Conservare binding, Secret e impostazioni esistenti; gli altri moduli possono restare presenti. Salvare e distribuire manualmente da Cloudflare.
4. Aprire Life OS su iPhone e sincronizzare.

Questa revisione non esegue deploy automatici. La lettura applicativa applica solo le migrazioni additive già previste per conservare sezione e orario delle attività. Il database esistente resta la fonte dei dati.

Baseline Worker: versione pubblica 1f0951904c307c13a7a448381aa76e7be246a2ff/worker.js, Git blob caea3ae161200b69147e41377f337d8c71028fac, corrispondente al codice analizzato prima della patch 61. Aggiornamenti di Finanza conservati; aggiunte solo regole delle attività, migrazioni relative e presentazione web. Il file contiene la configurazione finanziaria privata cifrata già presente: la pubblicazione completa è stata esplicitamente autorizzata dall’utente il 26 ottobre 2026.

SHA256 worker.js: 21427d04221065e28520447c0854575702441c64c1cdc0077cda90d8a7b79d7b

## Verifiche

Dieci test Foundation mirati superati. Worker reale su SQLite isolato: conservazione completate, orari, identità eventi, ricorrenze, riprogrammazione e settimana operativa indipendente dal mese del calendario. Browser: 19 script incorporati validi; ordinamento, visibilità, archivio chiuso e riordino con attività nascoste verificati.

CI finale 40374895382, revisione d440a7625d7c8d48151f4165f66b1a405c55e398: test di logica e calendario sull’iPhone principale superati; cinque verifiche UI su iPhone compatto superate (agenda, archivio, accessibilità delle righe, Riduci movimento e selezione del calendario). Anteprima principale controllata: titoli Ott e Nov corretti. IPA generata e verificata: app e widget versione 0.10.1 (62), archivio ZIP integro, SHA256 3f5fad222054edfc58f57af2ed8999936372786391664dc2021159543a740273. Le anteprime su iPhone principale e compatto sono state controllate.
