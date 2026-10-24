# Stato corrente — Life OS, 24 ottobre 2026

[IPA, prove e limiti build 60](native/BUILD-60.md).

Life OS iOS 0.9.9 build 60 ripristina la struttura nativa della release 59: Dashboard, Attività, Calendario e Finanza, con Budget/Piani, settimana e abitudini. Peso e calorie vengono letti da Apple Health; il + nel grafico e Siri salvano peso in Salute dopo autorizzazione. Il vecchio grafico manuale della 53 è stato sostituito; i suoi dati locali sono conservati senza copia automatica in HealthKit.

Restano coda locale persistente, sincronizzazione non bloccante dei setter supportati, notifiche locali opzionali, Siri e widget di accesso rapido. Controlli e transizioni standard rispettano Riduci movimento. Le nuove proposte di widget con turni, abitudini, eventi e meteo sono ancora concept, non implementazione.

Verificati 156 unitari e 35 percorsi UI sulla base invariata, 2 percorsi aggiornati e 6 prove compatti sulla build finale; compilazione e archivio Release riusciti. Controllo indipendente di IPA, log e provenienza completato. Dettagli e limiti in BUILD-60.md. Salute, firma, Siri e widget richiedono collaudo sul dispositivo dopo Signulous.

Nessun merge o deploy Cloudflare. Il codice web/backend non cambia in questo incremento: i dati condivisi modificati dal client possono comparire anche nel web dopo sincronizzazione, ma HealthKit resta separato. Le estensioni server della precedente build 52 non vengono attivate qui. La pubblicazione GitHub serve a distribuire l’IPA unsigned.
