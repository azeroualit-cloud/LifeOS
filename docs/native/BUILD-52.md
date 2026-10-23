# Build 52 — Dashboard salute e turni

Sorgenti iPhone 0.9.0 build 52: navigazione Dashboard/Finanza, settimana e meteo, due azioni Aggiungi peso/Calendario, misurazioni manuali e grafico peso/calorie, calendario dei turni come pagina secondaria e pubblicazione Apple in abbonamento.

Questo ramo permette la verifica Apple del pacchetto nativo senza pubblicare nuovamente il backend. Le nuove API salute e calendario sono implementate e verificate localmente ma il caricamento di `web/worker.mjs` è ancora sospeso: la revisione automatica richiede un consenso specifico ai dati finanziari incorporati nel sorgente. L’utente ha autorizzato il caricamento del codice in generale; è stata presentata una domanda aggiuntiva sul solo backend. Nessun deploy Cloudflare è stato eseguito.

La demo salva le misurazioni solo localmente. Sul server le nuove funzioni richiedono prima l’attivazione delle API; l’eventuale IPA di questo ramo non dimostra l’integrazione live con Apple Calendar o il backend.

Verifiche locali: 65 test Foundation Linux, parser Swift, controllo design system e integrità ZIP. Test SwiftUI, unitari NativeStore e archivio IPA vengono verificati dal workflow Apple di questo ramo. I risultati saranno riportati dopo la sua conclusione.

Prima esecuzione Apple: compilazione e 83 unitari superati; UI 25/26. L’unico fallimento è la ricerca immediata del messaggio vuoto del grafico nel test `testHomeEmptyHealthStateCanAddAndCorrectWeight`. La revisione aggiorna la prova per scorrere fino al testo visibile, verificarne la raggiungibilità e controllare lettura del dato salvato. Nessuna asserzione del flusso è rimossa. Il workflow esegue ora questa prova prima delle suite complete. Prima esecuzione: https://github.com/azeroualit-cloud/LifeOS/actions/runs/39987119259 . Nuova verifica da completare.

Il pacchetto mantiene bundle ID e dati precedenti. Il diff cumulativo è in `APPLE-TURNI-52.diff`. Nessun dato utente viene aggiunto ai fixture dei test.

La revisione del workflow usa esclusivamente fixture locali per unitari e UI. Il controllo live preesistente, che usa una credenziale del backend, è escluso da questa build perché la revisione automatica ne richiede un’autorizzazione specifica. I test di compilazione, salvataggio locale, navigazione, UI standard e compatta restano obbligatori; verifica live e deploy sono separati.
