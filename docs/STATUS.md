# Stato corrente — Life OS, 23 ottobre 2026

[PR](https://github.com/azeroualit-cloud/LifeOS/pull/1) · [IPA e prove build 52](native/BUILD-52.md) · [Dashboard](DASHBOARD-SALUTE.md) · [Calendario Apple](APPLE-CALENDAR.md).

Navigazione con Dashboard e Finanza. Dashboard con settimana, turni/meteo, Aggiungi peso e Calendario, grafico peso/calorie. Attività e abitudini rimosse dall’interfaccia; dati storici conservati. Il calendario dei turni è una pagina secondaria della Dashboard. Peso e calorie sono manuali; HealthKit non integrato.

## Verifiche concluse

- Compilazione e archivio Release iOS riusciti: 83 unitari, 26 UI standard e 12 UI compatti superati, oltre alle due prove mirate.
- IPA 0.9.0 build 52 verificata per checksum, ZIP, bundle e architettura arm64.
- Build JS, SQLite locale e Playwright a 320/375/1280 px superati. 65 test Foundation Linux superati.
- La nuova compilazione CI usa soltanto fixture locali, senza accessi al backend con credenziali.

## Da attivare

Nessun deploy Cloudflare o abbonamento Apple live eseguito; nuove API da distribuire e prova fisica ancora necessaria. Il codice nuovo backend è pubblicato come estensioni: template originale invariato, Worker completo assemblato localmente in dist e ignorato da Git. Nessuna nuova copia dello storico finanziario viene caricata nel repository.

La cronologia precedente rimane nella storia Git di questo file. I dettagli correnti di consegna, sorgenti e limiti sono in native/BUILD-52.md.
