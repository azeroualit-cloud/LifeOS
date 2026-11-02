# Revisione 74 — interfaccia Apple, Salute e Bloom

Stato: implementazione e verifica Apple in corso. Non è una dichiarazione di consegna finale.

## Navigazione e interfaccia

Quattro schede: Dashboard, Attività, Salute, Altro. Altro contiene Finanza, Calendario e Bloom. Il router conserva le richieste esplicite di data, evita duplicazioni dello stack e mantiene il calendario consultato dopo il background. Le intestazioni personalizzate hanno un ritorno ad Altro. I test precedenti sono stati adattati al nuovo percorso conservando i controlli sui flussi.

I puntini del calendario usano il colore del turno, oppure un neutro senza turno. Le abbreviazioni del mese seguono le sette colonne; il mese corrente ha l’accento e il separatore precede le celle. Le celle del mese e della settimana condividono identità geometriche. Toolbar con stile glass nativo su iOS 26+, fallback nativo precedente; rimossi i coriandoli del turno. Grafici Swift Charts con selezione di data/valore e scale indipendenti dalla selezione. Riduci movimento viene rispettato dalle animazioni personalizzate.

## Salute

Proteine, carboidrati e grassi in grammi; calcolo Decimal 4/4/9, virgola/punto decimale, totale immediato e data/ora modificabili. Tastiera numerica con Fine. Cronologia LifeOS modificabile e collegamento ai dettagli esistenti di peso/calorie/fonti/TDEE.

La scrittura HealthKit usa quattro campioni, identificativi stabili per registrazione/tipo e revisioni crescenti. Un giornale locale pending/confirmed precede l’invio; un retry riutilizza identità, revisione e payload. Non si presume una transazione fra filesystem e HealthKit. Le registrazioni di altre app non vengono modificate. I test usano un writer iniettabile e coprono autorizzazione negata, interruzione, riavvio, retry, modifica e archivio corrotto.

Documentazione Apple consultata: https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion — le versioni maggiori sostituiscono gli oggetti corrispondenti con versione inferiore. La prova reale di scrittura su iPhone e la verifica della rifirma HealthKit restano distinte dai test simulati.

## Bloom

Sorgenti del kit verificati contro tutti i 74 hash del manifest, origine `azeroualit-cloud/Bloom` commit `d11df5e29790e2c383314421cd399c8e8e7300d4`. Riutilizzati/adattati planner Riscopri, parsing/rendering Markdown, modello luoghi e mappa UIKit con cluster. Nessun PKMS, Dropbox, SwiftData aggiuntivo o lifecycle Bloom autonomo.

Archivio Codable locale separato. Allegati immutabili per SHA-256, indice pubblicato atomicamente dopo i file, verifica dimensioni/hash in lettura, backup originale conservato. Importazione Bloom 1/2 con date dal 2001, anteprima, validazione metadati/riferimenti/coordinate/ritagli/limiti, conflitti espliciti keep/replace/copy. I rimappamenti persistono, incluse le copie, per non duplicare una reimportazione. Rapporto persistente con conteggi, byte, checksum e categorie rimappate. Nessuna manutenzione automatica del Cestino; eliminazione manuale con conferma e conservazione degli allegati condivisi.

Libreria in griglia/elenco, ricerca, categorie multiple, fissati, gestione categorie e azioni multiple. Note di testo/titolo, link, foto, file e allegati. Pager per contenuti multipli, Markdown con tabelle e codice, Quick Look per originali e ritagli non distruttivi. Miniature ridotte per la griglia e anteprime orientate per i ritagli.

Mappa sullo stesso archivio, gruppi di note per luogo, cluster, camera conservata fra le sezioni e pannello con note collegate. Ricerca Apple Maps e tipi modificabili senza richiedere la posizione corrente. Classificazione su richiesta, fino a 30 luoghi senza tipo, nome normalizzato identico e distanza entro 150 m; nessuna sovrascrittura delle tipologie esistenti. Riscopri usa il planner deterministico del kit, massimo 30 elementi, con filtri e giro persistito.

Cattura tramite App Intent e schema LifeOS. Un URL esterno prepara il compositore; l’Intent esplicitamente invocato salva il link e mantiene una coda locale recuperabile. App e Intent condividono l’archivio per evitare writer concorrenti. Un retry non sovrascrive una nota già salvata e poi modificata.

## Evidenze e limiti

Il runner ha rilevato Xcode 26.3, SDK e simulatore iOS 26.2. iOS 27.2 non è disponibile nel runner e non viene dichiarato verificato. Deployment target mantenuto a iOS 17, con controlli di disponibilità per API successive. Confronti sullo stesso iPhone dell’utente e su versione/dimensione testo identiche restano una verifica successiva, come concordato con l’approccio prima API native.

Verifiche locali: parser Swift, diff check, checker design system; tre test dell’estrattore Python del kit passati. Verifica Apple intermedia riuscita: 230 unitari e due prove UI passati sul commit `74fb982ac51a04471ac66c6fd16398f570f7a556` (run https://github.com/azeroualit-cloud/LifeOS/actions/runs/41417798692). Schermate Salute e Bloom controllate; totale 165 kcal e persistenza della nota verificati. La pipeline di distribuzione deve confermare anche le ultime correzioni, le regressioni, lo schermo compatto e l’archivio prima della pubblicazione.

Lo ZIP non contiene il database reale del telefono. Per trasferirlo serve il backup esportato da Bloom e la verifica successiva di conteggi/allegati, riapertura e uso offline. Non disinstallare l’app originale sulla base dei soli test sintetici.
