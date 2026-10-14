# Life OS 0.3 — prova sul dispositivo

App e sito ora usano lo stesso database principale. La vecchia copia resta un archivio e non viene usata per la sincronizzazione. Gli inserimenti di prova sono dati veri nel registro: usa descrizioni che iniziano con TEST e rimuovili al termine.

## Installazione e accesso

Installa l’IPA come aggiornamento tramite Signulous, mantenendo l’app e il suo bundle ID. Non disinstallare l’app con movimenti in coda. Se il servizio impone una nuova installazione, esporta prima il backup dall’app e fermati per verificare il mantenimento dei dati.

La connessione resta quella già configurata. Dopo questo aggiornamento potrebbe servire un primo accesso: Impostazioni → Accedi, password già scelta per l’app. L’accesso ora è una schermata nativa; non richiede il login Google del sito. La sessione viene conservata nel Portachiavi, non nel backup JSON.

## 1. Sito e app

1. Crea nell’app un’attività “TEST sincronizzazione”.
2. Ricarica il sito: deve comparire una sola volta.
3. Modificala o completala dal sito.
4. Nell’app premi Sincronizza: deve aggiornarsi. In primo piano l’app controlla anche automaticamente ogni circa 30 secondi.
5. Elimina l’attività e verifica l’eliminazione nell’altro client dopo l’aggiornamento.

La sincronizzazione non è push e il sito aperto può richiedere una ricarica. Due modifiche contemporanee allo stesso elemento non hanno ancora un editor per risolvere conflitti: evita di modificarlo da entrambi i client nello stesso momento.

## 2. Movimento finanziario

1. Annota il saldo, poi aggiungi una spesa da 1 € chiamata “TEST movimento”, conto Trade Republic.
2. Verifica che il sito la mostri una sola volta dopo la ricarica e che saldo e budget siano coerenti.
3. Modifica la spesa e verifica lo stesso risultato sul sito.
4. Elimina il movimento di prova. In assenza di altre operazioni, il saldo deve tornare al valore iniziale.

Non interpretare il tempo di caricamento dei grafici come un secondo invio della spesa. Il riepilogo e lo storico dettagliato si aggiornano separatamente.

## 3. Offline, riapertura e invio singolo

1. Con dati già caricati, attiva la modalità aereo.
2. Verifica che Dashboard, Attività, Calendario e i dati finanziari già memorizzati rimangano consultabili.
3. Inserisci una spesa da 1 € chiamata “TEST offline”: deve restare nella coda del dispositivo.
4. Chiudi completamente l’app e riaprila, ancora senza rete: la spesa deve essere ancora in coda.
5. Riattiva la rete e premi Sincronizza. La spesa deve comparire una sola volta sul sito e sparire dalla coda dopo la conferma.
6. Ripeti Sincronizza e riapri l’app: non deve comparire una seconda spesa.
7. Elimina il movimento TEST.

Nuove spese ed Extra hanno una coda persistente. Le altre modifiche richiedono la rete: non considerarle salvate offline se l’app segnala errore. Se l’esito di una modifica non in coda è incerto, aggiorna i dati prima di ripeterla.

## 4. Avvio e timeout

Riapri l’app dopo un periodo di inattività, con Wi-Fi e poi rete mobile. I dati memorizzati devono restare visibili durante l’aggiornamento. Un errore transitorio di lettura viene ritentato una sola volta; le scritture non vengono ripetute automaticamente alla cieca.

Se resta un problema, annota operazione, ora, tipo di rete, tempo approssimativo e testo del messaggio. Non inviare password, cookie o token.

## 5. Interfaccia e operazioni restanti

- Prova tema chiaro, scuro e automatico.
- Ingrandisci il testo dalle impostazioni iOS; controlla scorrimento, tastiera e pulsanti Salva/Annulla.
- Controlla tutte le quattro schede, un calendario a sei settimane, cambio mese, turni e annullamento del turno.
- Prova una routine e un evento TEST ricorrente; verifica singola occorrenza e serie. Poi rimuovi i dati di prova.
- Prova un Extra TEST: le quote pianificate non devono creare movimenti bancari; un pagamento o un collegamento a un movimento esistente deve evitare un doppio addebito. Rimuovi poi piano e movimenti TEST secondo le azioni disponibili.
- Verifica importazione JSON solo in una modalità locale/demo; non importare snapshot sul collegamento condiviso.

## Cosa riportare

Per ogni problema: schermata, azione, risultato atteso e risultato osservato. Per la velocità: tempo percepito all’avvio, dopo una routine e dopo una spesa. I tempi del server misurati dal runner non equivalgono ai tempi della tua rete iPhone.
