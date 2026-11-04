# Nutrizione — pannello quick add approvato

Render approvato dall’utente il 4 novembre 2026: «ok approvo». Pulsante compatto in Dashboard → pannello con quattro quantità effettive in grammi, calorie automatiche, data e aggiunta sopra la tastiera. Nessun nuovo inserimento per 100 g/porzione/energia manuale. Standard a due colonne; testo accessibile su una colonna e contenuto scorrevole.

Calcolo nuovi inserimenti: 4P + 4C + 9G + 2 fibre (carboidrati disponibili, convenzione UE). Fonte: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A02011R1169-20250401, allegato XIV. È una stima dai nutrienti, non un valore dell’etichetta; non comprende polialcoli/alcol non inseriti. Energia calcolata conservata nello snapshot esistente, senza migrare o ricalcolare lo storico. Nell’editor storico, una modifica della sola data conserva esattamente i vecchi valori; cambiando i nutrienti si usa il nuovo calcolo.

Stesso store, identità della bozza e retry già esistenti; chiusura solo dopo salvataggio confermato, campi conservati in errore, nessun doppio invio durante busy. Fixture DEBUG separata per successo/errore di scrittura, nessuna scrittura HealthKit reale nei test UI sintetici. Test invarianti precedenti su dati, HealthKit e porzioni storiche conservati. Stato: implementazione pronta per verifica; non ancora compilata o accettata come app reale. Nessuna nuova IPA.

## Prima verifica e controllo visivo

Run 41823044927 fermato prima della compilazione dal controllo di due spaziature numeriche, poi corrette in token e verificate anche localmente. Run 41823446725 (sorgente 7327d676): compilazione, 16 unitari nutrizione e 5 UI passati, 11 screenshot scaricati. Nota: la selezione xcodebuild sovrapposta di suite e sottosuite ha eseguito 16 unitari nutrizione, non l’intera suite: non dichiarare tutti gli unitari passati da questo run.

QA visivo: cattura con tastiera coerente con il pannello; catture app-only dopo la chiusura della tastiera parzialmente vuote. Risultato non ancora consegnabile come completamente verificato. Verifica discriminante: confrontare acquisizione app e schermo intero dopo transizione tastiera, senza modificare il codice applicativo. Salvataggio, retry, dati e requisiti UI non vengono indeboliti.

Corretto anche il selettore focused: quando si richiede tutta LifeOSProbeTests, eliminare i filtri più stretti di quel target. Il run precedente ha dimostrato che tenerli insieme restringeva l’esecuzione ai 16 unitari nutrizione. Regressione della selezione coperta da test locale; nuovo avvio con selezione target-wide unica.

## Seconda verifica discriminante

Run 41841832626 PASSATO: 271 unitari e 5 UI, 16 screenshot. Cattura a schermo intero dopo Fine mostra il pannello completo, mentre la contemporanea acquisizione app-only risulta vuota: non usare app-only come prova del rendering di questo foglio nel simulatore. Cattura errore ancora insufficiente: acquisire solo schermo intero e confrontare con video nativo del simulatore sintetico.

Testo grande: rendere esplicita l’applicazione del modifier di prova anche al foglio locale, come già avviene per i fogli del router, e verificare le coordinate effettive dei campi (una colonna in accessibilità, due in standard). Senza questo assert il nome del test non certifica la dimensione attiva. Nessuna modifica di comportamento al rendering normale per questo override DEBUG.

## Modalità accessibilità reale

Run 41845722107: 271 unitari passati, quattro UI passati e uno fallito durante input Grassi. Confermata la colonna unica e il font accessibile nel foglio. Video nativo e gerarchia mostrano il campo Grassi a y=487–534 pt, sotto pulsante fisso e barra tastiera, mentre Carboidrati manteneva il focus. Il solo isHittable restituiva un segnale insufficiente. Test corretto per verificare che l’intero campo sia nel rettangolo visibile sopra l’azione fissa prima del tap; nessun cambiamento applicativo introdotto per questo errore del test. Nuova verifica anche sulla leggibilità completa dell’errore e sulla posizione dell’azione in accessibilità.

## Recupero in errore e scorrimento del foglio

Run 41849578621: 271 unitari passati, input di tutti e quattro i nutrienti in accessibilità riuscito. Il video nativo mostra i valori conservati e Riprova, ma lo swipe discendente del contenuto chiude il foglio durante una registrazione pendente; il messaggio è sotto i dati e può richiedere ricerca. Correzione applicativa: contenuto con priorità allo scroll, dismiss interattivo disabilitato finché esiste la bozza persistita non confermata (X esplicita ancora disponibile), errore nel footer sopra Riprova. Test conserva tutti gli assert sui valori e verifica che la rilettura non chiuda il foglio; messaggio e azione devono essere visibili sullo schermo.

Run 41853040353: 271 unitari e quattro UI passati; test accessibilità fermato sulla ricerca TextField dopo disabilitazione. Video nativo a 161 secondi mostra pannello aperto, P25/C40/G10/F6 conservati, errore completo e Riprova visibile dopo scroll. Ricerca del controllo pendente estesa al tipo accessibile effettivo, mantenendo assert su visibilità e valore; gerarchia e screenshot allegati prima della verifica. Non ancora dichiarato retry verificato in questo run.

## Mancata acquisizione runner

Run 41856609394: job 126666861434 terminato cancelled, run failure; nessuno step eseguito. Annotazione ufficiale: “The job was not acquired by Runner of type hosted even after multiple attempts”. Non è un fallimento dei test né una prova del codice. Dopo istruzione utente «continua», nuovo focused/nutrition/primary 41859714562 sul commit 623e3000. Nessuna IPA: IPA-GATE-01 richiede una richiesta utente esplicita separata.

## Runner standard alternativo

Anche 41859714562 è terminato senza runner acquisito (stessa annotazione). Su richiesta esplicita dell’utente, workflow sviluppo spostato da xcode-27 a macos-26; inventario ufficiale runner verificato, include Xcode 26.x già supportato dal selettore esistente. Nessun indebolimento dei controlli SDK, nessun cambiamento al workflow IPA. Actionlint e sei test locali selezione passati. Run 41871989512 sul commit cad0a7b5, focused/nutrition/primary, in coda. GitHub status segnala incidente Actions/Pages xr3myzj7ms51, mitigato e in monitoring alle 16:48–16:49 UTC del 4 novembre: possibile fattore per la coda corrente, non prova della causa dei precedenti tentativi. Fonte: https://www.githubstatus.com/incidents/xr3myzj7ms51 .
