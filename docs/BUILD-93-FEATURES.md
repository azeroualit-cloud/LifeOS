# Build 93 - inventario delle funzioni della build 92

Elenco ricavato dal codice di `codex/build92` (native-next/Sources), non dalla memoria.
Serve come gate di accettazione: nella 93 nessuna voce sparisce, salvo quelle segnate "cambia" su richiesta di Nas.

Stato nell'anteprima (https://claude.ai/artifact/QAanqSYRowbYWgUKV8n271):
- OK: disegnata
- MANCA: c'è nella 92 ma non ancora nell'anteprima
- CAMBIA: cambiata su richiesta esplicita di Nas

## Dashboard
- Data e turno di oggi - OK
- Orario successivo (Empoli) con foglio "Orari" del giorno - MANCA
- Settimana con turni, tocco su giorno apre il Calendario - OK
- Cose da fare: eventi, abitudini, attività del giorno, con menu Gestisci (Attività, Abitudini, Calendario) - MANCA il menu Gestisci e gli eventi nella lista
- Prossimi appuntamenti - MANCA
- Nutrizione rapida: kcal di oggi, Peso, Alimento (Alimento a destra) - OK
- Finanza compatta, apre Finanza - OK
- Stato connessione e notifiche del server - MANCA

## Attività
- Elenco attività, completate, categorie (crea, rinomina, elimina spostando le attività) - MANCA la gestione categorie
- Abitudini: ogni giorno, ogni N giorni, giorni della settimana, data di inizio, "Prossima: tra N giorni" - OK in parte (manca giorni della settimana nel foglio)
- Editor attività/evento: titolo, descrizione, categoria, luogo, avviso, sveglia urgente (iOS 26), ripetizione (mai, settimana, mese, anno), data finale, modifica da questa occorrenza, elimina occorrenza o serie - MANCA (il foglio Evento è parziale)

## Calendario
- Mese a scorrimento verticale con turni e pallini eventi - OK
- Vista Agenda e giorno, "Torna al mese", "Oggi" - MANCA Agenda e giorno
- Dipingi turni (palette) - MANCA
- Esporta turni su Apple (in Impostazioni) - MANCA

## Salute e Nutrizione
- Settimana/giorno selezionabile, Oggi - OK
- Calorie e macro del giorno - OK (CAMBIA: barra per macro)
- Micronutrienti con "In evidenza" scelti con la stella - OK in parte (manca la stella / In evidenza)
- Diario del giorno, modifica, elimina da LifeOS e Apple Salute, registrazioni in sospeso da riprovare - OK in parte (mancano azioni e stati)
- Cronologia nutrizione - MANCA
- Grafici peso (pesate e tendenza) e calorie per giorno con periodo - OK peso (CAMBIA: unito alla previsione), MANCA grafico calorie per giorno
- TDEE medio dallo storico, TDEE stimato, Simulazione con calorie dello scenario - OK TDEE, MANCA Simulazione
- Aggiungi peso con data, salvataggio in Apple Salute - OK
- Aggiungi alimento: ricerca, catalogo (Open Food Facts), personali, pesatura con osso/senza osso, unità, quantità, data, nutrienti a mano - CAMBIA (ricerca subito), MANCA pesatura con/senza osso, unità e data
- Macro a mano con fibre - OK (fibre aggiunte)
- Editor alimento personale: nome, marca, famiglia, formato integratore, unità, valori facoltativi - MANCA
- Integratori (catalogo solo dell'utente) - MANCA

## Bloom
- Libreria con ricerca, categorie (gestione, fissa in categoria), archivio - OK in parte
- Nuovo giro (riscoperta) - MANCA
- Catture in sospeso (dalla condivisione) - MANCA
- Nota: titolo, link con anteprima, luogo (Apple Maps, tipologia), categorie, allegati (file, foto), inquadratura immagine - OK in parte (mancano luogo, allegati, inquadratura)
- Mappa dei luoghi, Apri in Mappe - MANCA
- Importa ed esporta backup, rapporto, conflitti (mantieni, sostituisci, copia) - MANCA (in parte sostituito dal trasferimento sul server)

## Finanza
- Budget rimanente, al giorno, conto principale, nascondi importi - OK
- Budget, Analisi, Nuovo piano, Movimenti - OK
- Movimenti: ricerca, filtro per conto, modifica, elimina, "già inclusa nel saldo rilevato" - MANCA
- Destinazione della spesa: budget, risparmi, piano, periodo di competenza - OK (CAMBIA: aggiunta Rate)
- Obiettivo di risparmio e fondo emergenza - MANCA
- Analisi: spese per categoria (3/6/12 mesi), patrimonio 12 mesi, stipendi per competenza (cedolini), ripartizione stipendio, previsione patrimonio con fascia 80% - OK in parte (mancano patrimonio, cedolini, previsione)
- Piani: tipi Anticipa budget, Obiettivo finito, Fondo senza scadenza, Affitto e utenze, Rateizza, Spesa rapida; registra pagamento, differenza dal previsto, recupero nei budget futuri, quote future, piani precedenti - OK in parte (CAMBIA: Rateizza passa nella spesa)
- Modifiche sul dispositivo in sospeso (riprova, annulla, ripristina dal server) - MANCA

## Impostazioni
- Notifiche e Siri, promemoria locali, esporta turni su Apple, widget 2x2 - MANCA
- Dati sul server, esporta backup completo - OK (nuovo)
