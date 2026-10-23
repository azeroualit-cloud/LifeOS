# Build 52 — Dashboard salute e turni

Sorgenti iPhone 0.9.0 build 52: navigazione Dashboard/Finanza, settimana e meteo, due azioni Aggiungi peso/Calendario, misurazioni manuali e grafico peso/calorie, calendario dei turni come pagina secondaria e pubblicazione Apple in abbonamento.

Questo ramo verifica il pacchetto nativo e contiene le sole nuove estensioni backend e UI. La revisione automatica ha bloccato la ripubblicazione del Worker completo con lo storico: è stata adottata un’alternativa senza quel contenuto. `web/worker.mjs` resta il template originale invariato; `backend-extensions.mjs` e `backend_update.py` aggiungono solo codice, producendo localmente `web/dist/worker.mjs`, ignorato da Git. Non vengono caricati dati finanziari nuovi o una copia modificata dello storico. Nessun deploy Cloudflare è stato eseguito.

La demo salva le misurazioni solo localmente. Sul server le nuove funzioni richiedono prima l’attivazione delle API; l’eventuale IPA di questo ramo non dimostra l’integrazione live con Apple Calendar o il backend.

Verifiche locali: 65 test Foundation Linux, parser Swift, controllo design system e integrità ZIP. Test SwiftUI, unitari NativeStore e archivio IPA vengono verificati dal workflow Apple di questo ramo. I risultati saranno riportati dopo la sua conclusione.

Prima esecuzione Apple: compilazione e 83 unitari superati; UI 25/26. L’unico fallimento è la ricerca immediata del messaggio vuoto del grafico nel test `testHomeEmptyHealthStateCanAddAndCorrectWeight`. La revisione aggiorna la prova per scorrere fino al testo visibile, verificarne la raggiungibilità e controllare lettura del dato salvato. Nessuna asserzione del flusso è rimossa. Il workflow esegue ora questa prova prima delle suite complete. Prima esecuzione: https://github.com/azeroualit-cloud/LifeOS/actions/runs/39987119259 . Nuova verifica da completare.

Il pacchetto mantiene bundle ID e dati precedenti. Il diff cumulativo è in `APPLE-TURNI-52.diff`. Nessun dato utente viene aggiunto ai fixture dei test.

La revisione del workflow usa esclusivamente fixture locali per unitari e UI. Il controllo live preesistente, che usa una credenziale del backend, è escluso da questa build perché la revisione automatica ne richiede un’autorizzazione specifica. I test di compilazione, salvataggio locale, navigazione, UI standard e compatta restano obbligatori; verifica live e deploy sono separati.
