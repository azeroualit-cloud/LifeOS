# Life OS 0.10.2 (63) — aggiornamento manuale

## Comportamento

- Eventi di oggi e domani: Attivo, prima delle attività singole.
- Eventi da dopodomani fino a oggi +7 giorni inclusi: In attesa, dopo le attività in attesa manualmente.
- Oltre sette giorni, passati e completati: nascosti dalle attività; gli eventi restano nel calendario. Al cambio giorno si aggiorna la sezione automaticamente.
- Attività senza data: stato manuale. Attività programmate: visibili dal giorno previsto. Completate: archivio chiuso, nascosto se vuoto.
- Nell’app nativa, comandi contestuali a capsula con area touch di almeno 44 pt per attività ed eventi. Data, orario e ripetizione aprono la sezione pertinente dell’editor; nessun collegamento alle impostazioni generali al posto del promemoria. Eliminazione attività con conferma; eventi con scelta fra occorrenza e serie. Intestazione Completate allineata alle altre sezioni.

## Dashboard attuale

Il riepilogo narrativo usa meteo valido, turni di oggi/domani e il primo appuntamento aperto ancora futuro, nei prossimi sette giorni. Non usa le attività singole. Il collegamento sotto il riepilogo apre l’agenda degli appuntamenti. La proprietà highlights del modello non viene usata dalla schermata Dashboard attuale. Questa revisione non cambia il contenuto della dashboard.

## Installazione manuale

Usare il medesimo worker.js completo per entrambi i Worker:

1. lifeos-native-test: sostituire il contenuto del modulo di ingresso native-gateway.js.
2. lifeos: sostituire il contenuto del modulo di ingresso worker.js.
3. Conservare binding, Secret, impostazioni e altri moduli esistenti. Salvare e premere Deploy manualmente per entrambi.
4. Installare l’IPA 0.10.2 (63), aprire l’app e sincronizzare.

Nessun deploy automatico. Configurazione finanziaria cifrata e metadati preservati rispetto al Worker 62, la cui pubblicazione completa è stata esplicitamente autorizzata dall’utente il 26 ottobre 2026.

SHA256 worker.js: d830a2514cbbfcc7e30636b6dc07b48c67fa6fefe2d3dfbd0a765a040774fe00

## Verifiche

Dieci test Foundation superati: divisione Attivo/In attesa, passaggio automatico da dopodomani a domani, limite settimanale, identità delle ricorrenze, completamento offline e riordino con elementi nascosti. Worker reale su SQLite isolato: conservazione completate, migrazioni, orari, identità e riprogrammazione degli eventi verificati. Browser: 19 script validi e controllo della corretta sezione per gli eventi. Build Apple 40385589129: compilazione e 171 test unitari superati, controlli evento verificati; il nuovo test UI è stato corretto per selezionare il titolo come pulsante accessibile anziché testo separato. Nuova verifica Apple sulla revisione 3292ba10142b39759fea4889116738b3e14804a7 in corso.
