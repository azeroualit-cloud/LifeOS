# Revisione 0.3.0

## Risultato controllato

- Destinazione unica: gateway nativo associato al D1 del sito, con riconciliazione idempotente e precondizioni sui record. Backup separato prima della riconciliazione.
- Codice Worker originale invariato; nessuna password, cookie o dump nel pacchetto pubblico.
- Cache locale conservata in errore e archivi precedenti decodificabili. Timestamp distinti per dati Life e finanza.
- Letture concorrenti e limitate all'ambito; risposta analitica obsoleta scartata se cambiano mese o generazione.
- Scritture finanziarie identificate da UUID persistente e confermate su disco; nessun retry automatico delle altre mutazioni.
- Login con stato occupato esclusivo, verifica origine e cookie sicuro. Password non archiviata; conservazione sessione tramite Keychain.
- SDK Xcode recente selezionato esplicitamente; screenshot del simulatore revisionati nei due temi, testo grande, tastiera e sei settimane.

## Limiti residui espliciti

- Nessuna prova automatica certifica l'installazione Signulous o il comportamento della rete dell'iPhone.
- Solo nuove scritture finanziarie supportate hanno coda offline. Le modifiche a record esistenti richiedono rete.
- Nessun push sul browser né risoluzione interattiva dei conflitti simultanei.
- Importazione JSON sul dispositivo originariamente problematica: percorso sostituito, prova reale ancora necessaria in demo.
- Misure del runner descrivono server e payload, non la latenza percepita sul telefono.
- Keychain: se la firma esterna cambia identità o gruppo di accesso, potrebbe servire un nuovo login. Aggiornare mantenendo l'app installata.

Evidenze automatiche definitive nel run 38548668497; esito da leggere nel run. Prove dispositivo in docs/PROVA-0.3.md del repository.
