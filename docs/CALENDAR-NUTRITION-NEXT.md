# LifeOS — proposta per l’agenda del giorno e il catalogo Nutrizione

La prima tranche aggiorna i componenti esistenti. Questa proposta descrive le scelte ancora da approvare per i due flussi che cambiano struttura o persistenza.

## Agenda del giorno — flusso approvato

Un tocco su una data del mese o della striscia Dashboard apre una schermata Giorno dedicata. Il comando Mese riporta alla posizione e alla data di partenza. Il titolo riporta la data, con frecce per il giorno precedente e successivo e il turno sotto. La lista mostra prima gli impegni di tutto il giorno, poi gli orari e le relative attività. Aggiungi evento resta in basso e usa la data corrente della schermata. Il pennello continua a modificare i turni nel mese. Il passaggio si anima con Riduci movimento disattivato.

## Proposta precedente del foglio — respinta

L’utente non ha approvato il foglio. La descrizione seguente conserva la proposta per la cronologia. Toccando una data nel mese, aprire un foglio con superficie distinta e transizione dal basso. La data e il turno sono nell’intestazione. Seguono le sezioni Tutto il giorno e Agenda, con orario a sinistra e righe degli impegni a destra. In fondo, Aggiungi evento resta raggiungibile con il pollice e apre il modulo precompilato con la data. L’agenda del giorno può espandersi e chiudersi tornando al mese e alla posizione di scorrimento precedente. Riduci movimento usa una dissolvenza o elimina lo spostamento. Il pennello dei turni rimane un gesto di modifica e non apre il foglio.

```text
  Dom 8 novembre                    Chiudi
  Riposo

  Tutto il giorno
  [Evento o attività]

  Agenda
  09:00  [Impegno]
  14:30  [Impegno]

           + Aggiungi evento
```

Verifica: apertura da mese e Dashboard, calendario senza impegni, giorno con eventi e attività, creazione con data corretta, ritorno alla stessa settimana, testo grande e Riduci movimento. La CTA resta separata dalla barra delle schede.

## Catalogo, cocktail e Apple Salute

- Il catalogo standard resta italiano e concentrato sui cibi quotidiani. Le varianti di carne espongono preparazione e pelle. Ciqual misura la parte edibile. Per le cosce compatibili si può inserire il peso con osso. LifeOS conserva il valore inserito e applica una resa stimata per taglio e preparazione. La composizione resta Ciqual. Le rese provengono dalle tabelle USDA ARS per coscia e sovracoscia (codici 241-3221, 241-3222, 241-3321, 241-3322 e 241-5222). Per il crudo, il rapporto fra resa dopo cottura con e senza osso è un’approssimazione. [Riferimento rese](https://www.ars.usda.gov/ARSUserFiles/80400530/pdf/8586/csfii85_4days_codebook.pdf). [Fonte Ciqual](https://zenodo.org/records/17550133)
- Aggiungi alimento personale dalla ricerca crea una voce riutilizzabile sul dispositivo, con nome, famiglia, kcal e nutrienti per 100 g. I campi non noti restano vuoti. Il diario salva una copia dei valori della porzione.
- Sezione cocktail con porzione per bicchiere, quantità modificabile e dicitura «Stima». Partire da Gin Tonic, Sex on the Beach, Long Island, Vodka Lemon, Vodka Red Bull, Rum e Cola, Mojito, Moscow Mule, Spritz, Negroni e altri classici reperibili. Calcolare i valori dalle ricette di riferimento, quantità e gradazioni documentate. [Ricette IBA](https://iba-world.com/cocktails/)
- LifeOS scrive già le fibre per le registrazioni con quel valore. Verificare autorizzazione e presenza del campione per Biscotti nell’app Salute. Estendere la scrittura con vitamine e minerali effettivamente disponibili, mantenendo unità per ogni nutriente e usando stime documentate per i dati mancanti quando esiste una base affidabile. [Tipi nutrizionali HealthKit](https://developer.apple.com/documentation/healthkit/nutrition-type-identifiers)
- Per i cocktail registrare le bevande standard stimate dalla ricetta. Apple Salute espone un conteggio delle bevande e un tipo separato per l’alcol nel sangue. [Bevande alcoliche in HealthKit](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/numberofalcoholicbeverages)
- Conservare gli identificativi HealthKit storici per macro, calorie e fibre. Assegnare un identificativo stabile per i campioni aggiuntivi, mantenere retry e cancellazione coerenti e testare i permessi parziali. La mancata autorizzazione di un dato aggiuntivo va resa visibile senza bloccare una registrazione alimentare già consentita.

## Monitoraggio micronutrienti — proposta

In Salute, aprire **Micronutrienti** da un collegamento nella scheda Nutrienti. Mostrare prima i preferiti modificabili. Selezione proposta: vitamina C e zinco per l’interesse per pelle e capelli, poi ferro, B12, magnesio e vitamina D per il quadro generale. Offrire il resto dei nutrienti quando la fonte li copre.

Ogni riga mostra apporto registrato oggi, unità, riferimento giornaliero per il gruppo pertinente e media dei giorni registrati negli ultimi 7 giorni, con indicatore visibile di copertura. Un giorno non registrato non entra nella media come zero. Se mancano nutrienti nel diario, mostrare «Dati parziali» o «Dati insufficienti», senza segnalare una carenza. Nel dettaglio, distinguere gli apporti calcolati dal catalogo e le eventuali fonti Apple Salute, senza contare due volte la stessa porzione.

I riferimenti possono partire dai [LARN V revisione](https://sinu.it/wp-content/uploads/2025/07/Tabelle-riassuntive_online.pdf) o dai [DRV EFSA](https://multimedia.efsa.europa.eu/drvs/index.htm). Indicare la fonte, il gruppo e il tipo di valore. Un riferimento alimentare non misura lo stato clinico, non assegna un punteggio estetico e non premia l’eccesso. La vitamina D alimentare non rappresenta lo stato della vitamina D, che dipende anche dall’esposizione solare.

Audit sul dataset Ciqual 2025 per 192 voci LifeOS. Valori numerici disponibili per calcio 181, magnesio 178, zinco 166, ferro 165, B12 152, vitamina C 121, D 104 e vitamina E 17. I valori sotto soglia, le tracce e quelli assenti vanno mantenuti distinti. La copertura del catalogo non implica la copertura del diario dell’utente.

Dipendenze: ampliare le colonne del catalogo, scalare i nutrienti per parte edibile, salvare una copia per porzione, autorizzare le letture e scritture necessarie in HealthKit, rispettare gli identificativi di sincronizzazione e gestire fonti duplicate. L’IPA 85 non contiene questo incremento.

### Fonte dei dati e scelta dei preferiti

L’inserimento rapido manuale continua a registrare i valori già previsti. I micronutrienti LifeOS vengono aggiunti automaticamente solo quando si sceglie un alimento del catalogo. Una registrazione con soli macro conta come copertura parziale dei micronutrienti.

Per riempire un campo mancante, cercare prima lo stesso alimento e la stessa preparazione in una tabella affidabile. Poi usare un calcolo dagli ingredienti o un alimento comparabile, compatibile per taglio, preparazione e fortificazione. Salvare fonte, unità e stato del dato. Mostrare «Stimato» quando si usa una ricetta o un sostituto. Tracce, limiti di quantificazione, zero e assenza restano distinti. [Linee guida FAO/INFOODS](https://www.fao.org/infoods/infoods/standards-guidelines/en/).

Vitamina C e zinco sono candidati iniziali per la pertinenza a pelle e capelli. Ferro, B12, magnesio e D restano opzioni generali, non preferiti fissi. I riferimenti alimentari sono una guida per l’adeguatezza e non un indice di attrattività. [Vitamina C](https://ods.od.nih.gov/factsheets/VitaminC-HealthProfessional/) · [Zinco](https://ods.od.nih.gov/factsheets/Zinc-HealthProfessional/) · [American Academy of Dermatology](https://www.aad.org/public/diseases/hair-loss/treatment/diagnosis-treat/).

### Riferimenti per profilo, omega-3 e creatina

Selezionare i valori LARN o EFSA dalla fascia di età e dal sesso quando il riferimento varia, con stato fisiologico pertinente su scelta dell’utente. Conservare fonte e tipo di riferimento. Mostrare l’apporto reale e un indicatore di riferimento raggiunto. Un limite superiore di sicurezza è un concetto distinto. [Riferimenti EFSA](https://www.efsa.europa.eu/en/topics/topic/dietary-reference-values).

Possibile estensione **Grassi → Omega-3**, con ALA ed EPA+DHA distinti e media settimanale. EFSA usa 250 mg al giorno di EPA+DHA come assunzione adeguata per gli adulti. [EFSA, tabella 2](https://www.efsa.europa.eu/sites/default/files/2017_09_DRVs_summary_report.pdf).

**Creatina** come abitudine o integrazione facoltativa, indipendente dagli obiettivi di adeguatezza. È pertinente soprattutto a sforzi brevi e intensi ripetuti e all’allenamento di forza. Può aumentare il peso per ritenzione d’acqua. Nessuna dose automatica. [NIH ODS](https://ods.od.nih.gov/factsheets/ExerciseAndAthleticPerformance-HealthProfessional/).
