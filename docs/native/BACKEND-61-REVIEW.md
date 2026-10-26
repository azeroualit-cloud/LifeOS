# Backend 61 — patch sulla versione live verificata

Stato al 26 ottobre 2026: aggiornamento esplicitamente autorizzato ed eseguito su entrambi i Worker. Codice, moduli aggiuntivi, configurazione e binding verificati dopo il deploy. Ultima verifica del contratto applicativo autenticato fallita; causa ancora da isolare, quindi la checklist non è dichiarata interamente conclusa.

## Risultato dell'analisi

Il codice online è più recente della vecchia baseline web: include già schedule_json per le abitudini e la relativa validazione. Quella rappresentazione e le regole esistenti vengono conservate. Il ramo pubblico fix/platform-parity contiene i sorgenti modulari di riferimento; il bundle live presenta ulteriori modifiche da preservare. Le vecchie undici patch della baseline non vanno applicate al bundle attuale.

Le entrypoint dei due Worker condividono il bundle verificato. Il modulo aggiuntivo del Worker nativo resta byte per byte invariato.

## Modifiche pronte

1. Rimuovere la cancellazione delle attività completate dopo cinque giorni dalla lettura dei dati.
2. Aggiungere in modo idempotente section_status e scheduled_time, senza ricreare tabelle né migrare la programmazione delle abitudini a un formato diverso.
3. Conservare la sezione Attivo/In attesa durante completamento, retry, modifica e riapertura; aggiornamento atomico della sezione con lo stato.
4. Validare e salvare HH:mm; mantenere l'orario se un client precedente omette il campo, cancellarlo quando esplicitamente rimosso.
5. Esporre le capacità già supportate per abitudini e orari, in modo che l'app confermi soltanto salvataggi supportati.
6. Rendere disponibili fino a 48 eventi imminenti, oltre il precedente limite di tre elementi della panoramica, mantenendo identità e stato delle occorrenze.

## Verifiche eseguite

- Audit sorgenti in sola lettura: run 40308535289, riuscito. Solo i sorgenti vengono esportati cifrati; chiave privata rimasta nella sessione.
- Regression test sul Worker effettivo contro SQLite isolato: la versione originale fallisce la conservazione; la patch la supera. Verificati migrazione ripetibile, ripristino sezione, orari preservati/rimossi, input invalidi, schedule_json e rinomina abitudini, evento senza attività duplicata, eliminazione esplicita e dati estranei invariati. Nessuna chiamata al database live.
- La trasformazione inversa ricostruisce esattamente il sorgente originale: il resto del codice, inclusi Finanza, autenticazione, HTML e integrazioni, rimane invariato.
- Nove test del processo di aggiornamento superati: modalità predefinita in sola lettura, controllo di entrambi i Worker prima di scrivere, sorgente cambiato, conservazione moduli/configurazione/segreti, idempotenza e rollback anche con risposta persa.
- Preflight live run 40310039779, riuscito: i due sorgenti corrispondono all'audit e la configurazione è compatibile con il processo di conservazione. Nessuna scrittura né esportazione delle impostazioni.

Originale SHA256: 373384c74fe55aa66f2d1a6b8c12e778b4f33dbcf699e28696c5f12aa632f73f
Patch SHA256: 2fffe32f48461693444363457451c4787b25feb9196a1dda71e1d6175779a1e6

## Aggiornamento autorizzato ed eseguito

Applicata la patch ai Worker lifeos-native-test e lifeos, nell'ordine, conservando tutti gli altri moduli e la configurazione nel processo, senza esportarla. Il comando di deploy richiede --apply; senza questa opzione ammette solo GET. Confronta nuovamente sorgente e configurazione prima di ogni aggiornamento; se divergono si ferma. Verifica i moduli e i binding dopo ogni aggiornamento. In caso di errore ripristina e verifica il codice originale quando non ci sono cambiamenti concorrenti. Le colonne additive, se già create da una successiva lettura applicativa, restano compatibili con il codice precedente.

La revisione automatica ha rifiutato l'esportazione delle impostazioni, fuori dal consenso dato per i sorgenti: tale estensione è stata esclusa. Il consenso per il deploy è stato ottenuto ed eseguito. La ripetizione della verifica autenticata con diagnostica più precisa è stata successivamente rifiutata dalla revisione automatica per accesso con password ai dati live. Rimane necessaria un’autorizzazione esplicita per quella verifica in sola lettura, senza esportazione dei dati.


## Esecuzione del deploy

Run 40356025119, commit c8aefb31bc0666800fe0505314e8b4920494d60e: 9 test su fixture superati; aggiornamento effettivo e verifica di entrambi i Worker riusciti (LIVE_61_DEPLOYED_AND_VERIFIED). Il job complessivo risulta fallito per il successivo controllo applicativo autenticato; non va presentato come interamente verde. Non sono state effettuate altre modifiche al codice dei Worker durante la diagnosi. Workflow di deploy una tantum rimosso dopo l’esecuzione.

Run 40357068529: pagine pubbliche rispondenti; controllo senza credenziali, senza lettura di API private o dei contenuti delle pagine. Questa prova non sostituisce il contratto autenticato ancora non verificato.
