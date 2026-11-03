# Revisione 75 — bollette per competenza

Stato: verifica Apple mirata superata; regressione completa e pacchetto finale in preparazione. Nessuna IPA 75 consegnata e nessuna distribuzione backend 75 ancora eseguita.

## Comportamento

La registrazione e la modifica di una bolletta consentono di scegliere mese iniziale e finale, anche negli anni precedenti. Il periodo è esplicito, comprende da uno a dodici mesi e viene conservato anche negli invii locali in attesa. Per i documenti precedenti non si deduce il periodo dal nome o dal numero di mesi: va indicato nell’editor.

221,79 € con competenza agosto–ottobre produce tre costi di 73,93 €. Il movimento bancario resta unico, con importo e data di pagamento originali, anche se novembre. Il budget dei mesi precedenti viene ricalcolato; un mese senza documento conserva la stima. Le quote di documenti distinti nello stesso mese si sommano. Gli eventuali centesimi indivisibili vengono assegnati ai primi mesi, conservando il totale.

Il fondo conserva accantonamenti e disponibilità originali. Per le categorie utenze il budget conta il costo effettivo, oppure la stima, una sola volta: non aggiunge nuovamente l’accantonamento e l’intero pagamento. La modifica del solo periodo conserva anche l’identità del pagamento e lo stato di un fondo già chiuso o interrotto. Richieste ripetute, interruzioni e modifiche concorrenti vengono riconciliate senza un secondo addebito.

## Novembre

Riprodotto su dati sintetici un problema al cambio mese: il calcolo della media degli stipendi includeva il mese nuovo ancora privo di accredito e cadeva sul valore di ripiego. Se il mese immediatamente precedente ha un accredito, la finestra termina su quello; restano necessari dodici mesi consecutivi completi. Non si cercano stipendi arbitrariamente vecchi e un saldo realmente negativo non viene azzerato.

Questa riproduzione non dimostra la causa del valore personale di novembre. La diagnosi proposta sui dati finanziari reali, con indicatori nei log GitHub Actions, è stata bloccata dalla revisione automatica ed è in attesa di autorizzazione esplicita. Nessuna query finanziaria diagnostica è stata eseguita. La verifica separata del contesto di codice Cloudflare, priva di query ai dati finanziari, ha confermato la compatibilità della patch con entrambi i Worker esistenti.

## Integrità e compatibilità

Metadati di competenza nello stato finanziario già esistente; nessun secondo registro bancario e nessuna migrazione automatica dei movimenti storici. API dedicate impediscono a un backend precedente di accettare una bolletta ignorandone il periodo. Le operazioni conservano autenticazione, verifica origine, registrazione locale, ID app/widget e App Group.

La distribuzione prepara una trasformazione verificata del codice Worker esistente, conserva moduli e impostazioni estranei e verifica la rilettura dopo il caricamento. Non crea pagamenti di prova sui dati reali.

## Prove

Test isolati: ripartizione esatta, resto dei centesimi, passaggio d’anno, periodi invalidi, stime, budget completo dei mesi passati, separazione dal conto e dal fondo, fondi di diversi tipi, invii ripetuti, risposta persa, modifica concorrente, fondo chiuso, rollback e autenticazione. Regressioni precedenti finanziarie e attività conservate.

Verifica mirata Apple [41548876009](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41548876009), sorgente `51fd07b2cd1170889158c0651590631001033cfc`: **245 test unitari e 6 UI superati**. Compresi Salute, Bloom, calendario con testo ingrandito, creazione della bolletta con tre quote da 73,93 € e modifica del periodo. Schermate standard e con testo effettivamente ingrandito controllate. Il test di selezione/scorrimento del grafico peso è passato; un’intermittenza osservata nella precedente esecuzione resta registrata, senza attribuirle una causa non dimostrata. La regressione completa sui due dispositivi e i download saranno documentati dopo la loro conclusione. SDK 27.2 disponibile; runtime compatibile con iPhone 15 Pro e SE 3: 27.0. Prova fisica su iPhone 15 Pro con iOS 27.2 e confronto con le app Apple non eseguiti.
