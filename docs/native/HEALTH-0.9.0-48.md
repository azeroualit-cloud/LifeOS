# Build 48 — Peso e calorie nella dashboard

La dashboard conserva calendario, riepilogo, orari e abitudini. Le sezioni Da fare e Budget sono rimosse dalla Home; le rispettive pagine e i dati restano disponibili nei quattro tab esistenti.

Scheda Peso e calorie con lettura HealthKit di bodyMass (kg) e dietaryEnergyConsumed (kcal). Richiesta di sola lettura tramite Collega o gestisci Salute; caricamento automatico se già consentito, aggiornamento al ritorno in primo piano e trascinamento per aggiornare. Nessuna scrittura HealthKit, invio al Worker, persistenza o esportazione di dati salute. Demo visuale isolata nei test DEBUG; in release la demo non legge Salute. Il cambio demo/collegato ricrea il modello. Nessun permesso di lettura viene dedotto dal successo del prompt: iOS non distingue dati assenti da permesso negato. Errori eliminano lo storico in memoria.

Ultima pesata per giorno; per le calorie una sola fonte alimentare, selezionabile nel dettaglio, per evitare somme fra app duplicate. La fonte iniziale è quella con più giorni di registrazione nelle ultime otto settimane. Le giornate parziali non sono distinguibili automaticamente: controllare che il diario sia completo. Calorie ingerite, non calorie attive del Watch.

Grafici Swift Charts di peso e calorie sulla stessa scala temporale, con pesate, mediana mobile di 7 giorni, scenario tratteggiato e linea calorica dello scenario. Dettaglio raggiungibile dalla scheda, senza quinto tab. Previsione modificabile a 4/8 settimane usando un obiettivo calorico; default media recente.

## Calcoli e limiti

TDEE ricavato da bilancio energetico su ultimi 35 giorni conclusi, almeno 21 giorni fra prima e ultima pesata, almeno 10 giorni con pesate e calorie presenti ogni giorno dell'intervallo. Ultima pesata completa non più vecchia di 7 giorni; oggi escluso. Pendenza del trend con regressione lineare; conversione energetica approssimata a 7.700 kcal/kg. Dati mancanti non diventano zero. TDEE fuori 800–6.000 non esposto.

Scenario: soluzione di dW/dt = (introito − TDEE iniziale − 22 × (W−W0))/7.700. Approssimazione dinamica ispirata alla relazione di Hall et al., Lancet 2011, non implementazione completa o validata individualmente del NIH Body Weight Planner. Non separa grasso, massa magra e acqua. Nessuna fascia statistica inventata. Le calorie scenario 800–6.000 sono limiti tecnici, non raccomandazioni. Attività futura assunta invariata. Il modello richiede ulteriore validazione prima di poter essere descritto come previsione personale scientificamente validata.

## Firma e prova reale

La build produce un'IPA senza firma. La firma finale deve includere com.apple.developer.healthkit=true e un provisioning profile abilitato a HealthKit per lo stesso bundle com.nas.lifeos.probe. Una semplice rifirma che rimuove la capability non consente di leggere Salute. Il simulatore e la demo non provano accesso al database Salute dell'iPhone.

Installare come aggiornamento; aprire dashboard, consentire peso e calorie, verificare la fonte delle calorie e confrontare valori/date con Salute. Provare permesso negato/parziale, assenza di calorie, cambio fonte e ritorno da Impostazioni dopo revoca. Non disinstallare per aggiornare.

## Verifica

Locale: parser Swift su sorgenti e test; design system; 65 test di modelli passati, inclusi 7 nuovi test Health. Build e test Apple documentati nella run finale, senza considerare il risultato locale come prova di compilazione iOS.
