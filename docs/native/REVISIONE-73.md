# Revisione 73 — flusso calendario e Dashboard

## Contratto implementato

Il tocco di una data nel mese apre un’agenda integrata sotto il calendario. Il mese rimane visibile e utilizzabile; chiusura ed espansione alla settimana sono azioni esplicite. La vista espansa conserva sette turni, intestazione unica e agenda compatta. La navigazione da Dashboard mantiene l’apertura diretta del giorno richiesto. La selezione produce feedback tattile; apertura/chiusura usa una transizione verticale di layout e dissolvenza, disabilitata con Riduci movimento. Le schede evento hanno il feedback di pressione comune dell’app.

I colori delle categorie sono deterministici; le attività nella categoria generica ricevono un colore stabile per identità, senza dipendere da data, completamento o processo. Turni conservano la loro palette. La stessa regola vale per eventi orari e pillole di tutto il giorno. Non vengono aggiunte categorie o modificati dati persistiti.

Dashboard: data e intestazione del turno condividono la baseline. Le barre caloriche storiche hanno opacità 28%; la linea del peso usa il colore del testo adattivo per emergere sopra le barre nei due temi. L’arancione di oggi e dei valori resta invariato. Nessuna modifica ai calcoli Salute.

## Verifiche

Superati 215 test unitari e 32 esecuzioni UI sul sorgente finale: 11 prove mirate e 5 regressioni su iPhone 15 Pro, 16 su iPhone SE 3. Zero fallimenti; archivio Release riuscito. Parser Swift e checker del design system passati. Test nuovi per stabilità e distinzione dei colori, permanenza del mese durante la selezione, chiusura/espansione esplicita e testo ingrandito con Riduci movimento. Le regressioni precedenti che aprivano il giorno completo includono ora il comando di espansione: l’intento della prova resta invariato.

Nessuna modifica backend o di schema. Firma Signulous e prova fisica restano esterne alla pipeline.

Pipeline: https://github.com/azeroualit-cloud/LifeOS/actions/runs/41327446300
Sorgente: `ea74b524369795a9e9b52de5cbb1ca5363ac1766`.

La revisione visiva del primo giro ha rilevato il giorno selezionato fuori dal viewport dopo il ridimensionamento. Corretto il proprietario delle settimane a cavallo del mese (mese del lunedì) e ripetuto l’ancoraggio dopo la transizione. Il test ora verifica che il giorno sia interamente visibile. Schermate finali controllate su entrambi i simulatori, con testo ingrandito; contrasto del grafico verificato nei due temi.

[IPA diretta 0.10.12 build 73](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.12-build73/LifeOS-73.ipa). Download pubblico verificato: 1.503.220 byte, CRC e checksum corretti, app/widget per iPhoneOS arm64, bundle/versioni e descrizioni permessi corretti. SHA-256: `3fe4250cfc9faf1bdb056c68f303fd1afd6da5bee68eaa0d39f513e5abaa5236`.

Aggiornare con Signulous senza disinstallare. La prova fisica e il provisioning della firma restano esterni alle verifiche. Nessun deploy Cloudflare necessario.
