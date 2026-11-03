# Revisione 77 — stato verificabile

## Obiettivo
Solo iPhone 15 Pro come dispositivo di design. Preservare identità, archivi e compatibilità SDK della build 76. Consegnare IPA diretta dopo test, QA visivo e gate di avvio.

## Implementato, verifica iOS ancora in corso
- Bloom nella tab bar; Finanza/Calendario nello stack Dashboard.
- Settimana apre calendario completo; header data/ora/preghiera.
- Elenco unico eventi, attività e routine con identità distinte.
- Panoramica Finanza con dati mancanti espliciti e privacy importi.
- Macro compatti in Dashboard; repository condiviso; Avanti/Fine.
- Salute apre direttamente gli approfondimenti.
- Cancellazione nutrizione persistente e recuperabile sui quattro sync identifier LifeOS.
- Importazione Bloom visibile a libreria vuota, snapshot completo prima della fusione e reset filtri dopo importazione.

## Evidenze backend
- Run 41630584505: audit codice live riuscito, senza query finanziarie.
- Run 41630715615: test sintetici, audit e deploy protetto riusciti.
- Log: UTILITY_COMPETENCE_75_DEPLOYED_AND_VERIFIED; moduli, autenticazione e binding estranei conservati.
- Nessun pagamento reale di prova. Funzionamento sul telefono non ancora confermato.

## Verifiche locali
- Base fissata scaricata e SHA-256 verificato; overlay assemblato.
- check-design-system.py passato.
- Test competenza 7/7, routing utenze 6/6, budget utenze 5/5, trasformazione 3/3.
- Il test budget richiede LIFEOS_UTILITY_WORKER=manual/build-75/worker.js; il default è la vecchia base 70.

## Verifiche mancanti prima della consegna
1. Completare compilazione e tutti i test di dominio sul commit più recente; leggere risultati, non solo stato del job.
2. Eseguire i quattro test UI revisione77 e controllare screenshot chiaro/scuro/testo grande su 15 Pro; ampliare per margini, tastiera, target, grafici, importazione e retry.
3. Aggiornare le regressioni UI precedenti dipendenti dalla vecchia scheda Altro e dal vecchio ingresso Salute. Non indebolire gli assert funzionali.
4. Verificare backup Bloom reale localmente senza pubblicarlo; trasferimento al telefono tramite importazione, mai incorporato nell’IPA.
5. Controllare recupero nutrizione, migrazione legacy, permessi e retry. Nessuna prova reale HealthKit eseguita dal desktop.
6. Versione/build successive all’ultima release effettiva; archivio dispositivo, gate app/widget, fixture Keychain e quattro avvii Release.
7. Verifica visiva conclusiva, IPA diretta, checksum e release senza modificare la 76.

## Esclusioni
Nessuna nuova sincronizzazione Bloom, nessun catalogo alimentare, nessuna eliminazione di dati personali durante sviluppo. Nessun test fisico dichiarato senza esecuzione.

## Validazione finale del commit d112050
Run 41637497578: compilazione, 258 unitari e 9 UI riusciti. Fixture di sessione salvata verificata dopo i test UI. Quattro avvii Release riusciti: fresh, synthetic-upgrade, synthetic-populated-upgrade e synthetic-session-upgrade. Toolchain Xcode 27.0 / SDK 27.0. Screenshot del simulatore controllati per navigazione, testo grande, tastiera, macro, Finanza e Bloom; corretto il contrasto del pulsante Importa in scuro. Archivio dispositivo e verifica IPA ancora in esecuzione.

Il backup personale è rimasto locale: 122 ID distinti, 9 raccolte e 12 file incorporati decodificati correttamente (3 immagini principali più 9 allegati). I 7 flag archived coincidono con i 7 trashedAt. Il test sintetico con la stessa struttura passa nel run finale. Il trasferimento effettivo richiede selezionare il JSON nell’app sul telefono; non è stato eseguito dal desktop.

## Pacchetto verificato
IPA 0.10.16 / build 77 scaricata dal run 41637497578 e verificata indipendentemente: app e widget arm64 dispositivo, identità e versione corrette; nessun confronto Date debolmente collegato. SHA-256: e2e6269d6442120161f9a27ae719c41c2b7966e815f8288013f40ebc3c00d707. Pubblicazione diretta predisposta con controllo del run, del commit e dello stesso checksum; release 76 immutata.
