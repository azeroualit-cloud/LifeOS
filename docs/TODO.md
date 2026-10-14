# Life OS — controlli residui

## Implementato

- [x] Unica fonte D1 attiva per sito e app, riconciliazione protetta e backup.
- [x] Refresh concorrente leggero, aggiornamenti per ambito e analisi separata.
- [x] Gestione timeout transitori, cache e coda finanziaria idempotente.
- [x] Accesso nativo e conservazione protetta della sessione.
- [x] Quattro sezioni integrate, revisione Apple e screenshot nei due temi.
- [x] Test automatici di modelli, sincronizzazione e interfaccia.

## Verifica sul dispositivo

- [ ] Installazione 0.3.0 tramite Signulous sopra la precedente, dati conservati.
- [ ] Modifiche app→sito e sito→app sullo stesso database.
- [ ] Nuova spesa offline, chiusura/riapertura, invio singolo al ritorno rete.
- [ ] Avvio a freddo Wi-Fi/rete mobile, accesso e permanenza della sessione.
- [ ] Calendario, tastiera, testo ingrandito, temi ed editor sul telefono.
- [ ] Importazione JSON in demo: verificare il problema originariamente segnalato.

Checklist completa: docs/PROVA-0.3.md su GitHub. I test collegati lavorano sui dati reali: etichette TEST e pulizia finale.

Funzioni successive non comprese in questa consegna: push in tempo reale, coda offline per tutte le modifiche, risoluzione dei conflitti simultanei e importazione completa di un backup nell'archivio reale.
