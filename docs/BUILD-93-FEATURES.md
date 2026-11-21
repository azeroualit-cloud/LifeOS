# Build 93 - inventario delle funzioni della build 92

Elenco ricavato dal codice di `codex/build92` (native-next/Sources), non dalla memoria.
Serve come gate di accettazione: nella 93 nessuna voce sparisce, salvo quelle segnate "cambia" su richiesta di Nas.

Stato nell'anteprima (https://claude.ai/artifact/QAanqSYRowbYWgUKV8n271):
- OK: disegnata
- MANCA: c'è nella 92 ma non ancora nell'anteprima
- CAMBIA: cambiata su richiesta esplicita di Nas

## Dashboard
- Data e turno di oggi - OK
- Orario successivo (Empoli) con foglio "Orari" del giorno - OK
- Settimana con turni, tocco su giorno apre il Calendario - OK
- Cose da fare: eventi, abitudini, attività del giorno, con menu Gestisci (Attività, Abitudini, Calendario) - OK
- Prossimi appuntamenti - OK
- Nutrizione rapida: kcal di oggi, Peso, Alimento (Alimento a destra) - OK
- Finanza compatta, apre Finanza - OK
- Stato connessione e notifiche del server - OK

## Attività
- Elenco attività, completate, categorie (crea, rinomina, elimina spostando le attività) - OK
- Abitudini: ogni giorno, ogni N giorni, giorni della settimana, data di inizio, "Prossima: tra N giorni" - OK
- Editor attività/evento: titolo, descrizione, categoria, luogo, avviso, sveglia urgente (iOS 26), ripetizione (mai, settimana, mese, anno), data finale, modifica da questa occorrenza, elimina occorrenza o serie - OK

## Calendario
- Mese a scorrimento verticale con turni e pallini eventi - OK
- Vista Agenda e giorno, "Torna al mese", "Oggi" - OK
- Dipingi turni (palette) - OK
- Esporta turni su Apple (in Impostazioni) - OK

## Salute e Nutrizione
- Settimana/giorno selezionabile, Oggi - OK
- Calorie e macro del giorno - OK (CAMBIA: barra per macro)
- Micronutrienti con "In evidenza" scelti con la stella - OK
- Diario del giorno, modifica, elimina da LifeOS e Apple Salute, registrazioni in sospeso da riprovare - OK
- Cronologia nutrizione - OK
- Grafici peso (pesate e tendenza) e calorie per giorno con periodo - OK peso (CAMBIA: unito alla previsione), OK grafico calorie per giorno
- TDEE medio dallo storico, TDEE stimato, Simulazione con calorie dello scenario - OK
- Aggiungi peso con data, salvataggio in Apple Salute - OK
- Aggiungi alimento: ricerca, catalogo (Open Food Facts), personali, pesatura con osso/senza osso, unità, quantità, data, nutrienti a mano - CAMBIA (ricerca subito), OK pesatura, unità e data (foglio Quantità)
- Macro a mano con fibre - OK (fibre aggiunte)
- Editor alimento personale: nome, marca, famiglia, formato integratore, unità, valori facoltativi - OK
- Integratori (catalogo solo dell'utente) - OK, voce in Impostazioni e formato nell'editor

## Bloom
- Libreria con ricerca, categorie (gestione, fissa in categoria), archivio - OK
- Nuovo giro (riscoperta) - OK
- Catture in sospeso (dalla condivisione) - OK
- Nota: titolo, link con anteprima, luogo (Apple Maps, tipologia), categorie, allegati (file, foto), inquadratura immagine - OK (inquadratura immagine: invariata dalla 92, non ridisegnata)
- Mappa dei luoghi, Apri in Mappe - OK
- Importa ed esporta backup, rapporto, conflitti (mantieni, sostituisci, copia) - OK in Impostazioni (rapporto e conflitti invariati dalla 92)

## Finanza
- Budget rimanente, al giorno, conto principale, nascondi importi - OK
- Budget, Analisi, Nuovo piano, Movimenti - OK
- Movimenti: ricerca, filtro per conto, modifica, elimina, "già inclusa nel saldo rilevato" - OK (modifica invariata dalla 92)
- Destinazione della spesa: budget, risparmi, piano, periodo di competenza - OK (CAMBIA: aggiunta Rate)
- Obiettivo di risparmio e fondo emergenza - OK (in Budget)
- Analisi: spese per categoria (3/6/12 mesi), patrimonio 12 mesi, stipendi per competenza (cedolini), ripartizione stipendio, previsione patrimonio con fascia 80% - OK
- Piani: tipi Anticipa budget, Obiettivo finito, Fondo senza scadenza, Affitto e utenze, Rateizza, Spesa rapida; registra pagamento, differenza dal previsto, recupero nei budget futuri, quote future, piani precedenti - OK (CAMBIA: Rateizza passa nella spesa)
- Modifiche sul dispositivo in sospeso (riprova, annulla, ripristina dal server) - OK (in Movimenti)

## Impostazioni
- Notifiche e Siri, promemoria locali, esporta turni su Apple, widget 2x2 - OK
- Dati sul server, esporta backup completo - OK (nuovo)
