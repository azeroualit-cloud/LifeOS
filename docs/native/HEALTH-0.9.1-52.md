# Correzione HealthKit — 0.9.1 build 52

Segnalazione: dopo l'installazione l'utente non vede cambiamenti né richiesta Salute. Il numero della precedente consegna era stato comunicato erroneamente come 48: il project.yml contenuto nello ZIP, già dalla baseline 850862b, era 0.9.0 build 51. La sostituzione cercava 47 e non aveva effetto. L'artefatto precedente risulta associato al commit HealthKit corretto, ma non è stato possibile confermare quale versione fosse installata sul telefono.

Difetto accertato nel codice: start(demo: store.isDemo) escludeva completamente HealthKit nella demo finanziaria anche in release; la scheda nascondeva anche il pulsante. Inoltre l'avvio leggeva senza richiedere automaticamente l'autorizzazione, in contrasto con l'aspettativa di richiesta iniziale.

Correzione: dati simulati solo per launch --visual-test in DEBUG; in release HealthKit è indipendente dal collegamento finanziario. Al primo ingresso viene controllato statusForAuthorizationRequest, richiedendo sola lettura di peso e calorie se shouldRequest; altrimenti si leggono i dati disponibili. La mancata lettura non viene presentata come prova di permesso negato. La firma deve comunque supportare HealthKit.

Scheda spostata prima delle abitudini per essere raggiungibile senza attraversare una lunga lista; numero 0.9.1 (52) visibile nella scheda e nelle impostazioni. IPA e artefatto nominati univocamente LifeOS-0.9.1-build52; controllo diretto dell'Info.plist dell'app archiviata per versione, build, bundle, piattaforma e descrizione privacy. BUILD-INFO.txt incluso nello ZIP finale.

Verifica locale: 66 test di modelli passati, incluso il controllo che una build release non possa simulare Salute attraverso argomenti di avvio. Parser Swift e controllo design system passati. Verifica Apple e risultato finale da registrare dopo la run 38998944242. La segnalazione sul dispositivo rimane da verificare con versione installata e firma effettiva.
