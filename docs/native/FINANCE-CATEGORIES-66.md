# Logica finanziaria rilevata nel Worker build 63

Verifica statica del Worker manual/build-63/worker.js e dell’editor nativo corrente; nessun accesso al movimento reale dell’utente, nessuna modifica al database.

## Regola attuale

Il nuovo editor MovementEditor imposta budgetTreatment=ordinary. Il wrapper withFinancePlans trasforma anche auto in ordinary per le nuove spese dirette, salvo savings esplicito. La categoria descrive la spesa ma non collega il movimento a un piano. Non esiste nel form un selettore visibile del trattamento. Questo crea una divergenza rispetto alla precedente logica automatica per categoria.

Tutte le 24 categorie del contratto seguono quindi il budget ordinario se inserite da Aggiungi spesa: Alimentari, Ristorazione, Casa, Affitto, Condominio, Arredamento e casa, Utenze, Elettricità, Gas, Acqua, Abbonamenti, Auto, Assicurazione, Bollo, Manutenzione auto, Benzina, Shopping, Salute, Palestra, Dentista, Farmaci e visite, Svago, Viaggi, Altro.

## Piani e dati precedenti

- Acqua, Gas ed Elettricità: i piani estimated accantonano una quota; i pagamenti collegati usano il fondo e attribuiscono lo scoperto ai risparmi generali. La media ponderata degli ultimi 12 pagamenti, per mesi di competenza, aggiorna la quota dal mese successivo.
- Affitto e ricorrenti vincolate (esclusa Benzina): adottate come piani fixed; i pagamenti dal piano non vengono sottratti di nuovo dal budget.
- Obiettivi e fondi: le quote riducono il budget nei mesi previsti; il pagamento usa savings e il fondo collegato. L’eventuale recupero dello scoperto è un piano separato esplicito, non automatico per categoria.
- Vecchie spese auto senza trattamento esplicito: il calcolo legacy esclude dal budget Assicurazione, Bollo, Manutenzione auto, Dentista e Straordinarie, oppure copre le ricorrenti vincolate. Questa eccezione non si applica alle nuove spese ordinary.
- I macrogruppi Casa, Utenze, Auto e Salute non equivalgono alle relative sottocategorie.
- Entrate: Stipendio, Interessi, Rimborsi, Altro. Il saldo registra il flusso; il budget non aggiunge indiscriminatamente ogni entrata allo stipendio previsto. I rimborsi seguono il percorso dedicato e possono ridurre la spesa netta.

## Riproduzione isolata

Eseguiti gli helper reali monthlyBudgetAmounts e balance del Worker con dati inventati, senza rete né database. Stipendio 1000, quota Acqua 20, bolletta 30:

- ordinary: impegni 20, spesa libera 30, residuo 950;
- auto/savings nel calcolo base: impegni 20, spesa libera 0, residuo 980;
- pagamento collegato al piano: fondo 20, pagamento 30, scoperto da risparmi generali 10.

Non certifica i dati del movimento reale o la versione effettivamente distribuita sul server. Nessuna correzione contabile applicata.

## Correzione proposta

Durante l’inserimento, riconoscere i piani attivi compatibili e mostrare la destinazione (budget o piano). Un piano univoco può essere proposto; casi ambigui richiedono scelta. Collegare lo stesso movimento, preservando idempotenza, modifica, cancellazione e operazioni offline. Mai creare un secondo pagamento per rimediare al primo. Prima di modificare i dati esistenti verificare il movimento e il piano effettivi.

## Percorso attuale per una spesa già inserita

Se esiste un piano Acqua attivo: Finanza → Budget → Acqua → Registra un pagamento → Movimento bancario: Già registrato. Selezionare il movimento compatibile, indicare la competenza e confermare. Il server riusa il movimento, modifica il trattamento e registra il collegamento, senza un secondo addebito. I vincoli di collegabilità (conto, mese, trattamento e collegamenti esistenti) restano applicati. Nessuna di queste operazioni è stata eseguita sui dati dell’utente durante l’audit.
