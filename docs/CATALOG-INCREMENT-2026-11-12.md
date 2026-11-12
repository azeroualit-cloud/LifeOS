# Catalogo, unità e cronologia — incremento del 12 novembre

Decisione: CATALOG-BRANDS-UNITS-HISTORY-2026-11-12. Marche confermate tramite META-01; generici, esclusioni maiale/creatina e gate IPA conservati. Questa pagina descrive un incremento in verifica, non un prodotto accettato.

## Flussi e dati

- Tutti contiene cataloghi generici e con marca, insieme alle voci personali. La ricerca comprende la marca. Personali resta separato.
- Modifica aggiorna la stessa identità personale; Personalizza crea una copia del catalogo. Le registrazioni già salvate conservano il loro snapshot nutrizionale.
- Integratori: capsule/softgel, compresse/pillole o grammi. Polveri generiche convertite dalla precedente dose convenzionale ai grammi. Vecchie voci personali senza unità conservano esplicitamente la vecchia base fino alla modifica dell’utente.
- Dati di etichetta per 100 ml restano ml; nessuna conversione arbitraria in grammi. Le registrazioni persistono unità e quantità.
- Tabelle assenti: prodotto e quantità registrabili localmente, energia e macro non dichiarati; nessun campione macro/energia zero inviato ad Apple Salute. I nutrienti disponibili si condividono solo con permesso. I limiti di etichetta sono espliciti e conservativi, mai trasformati in zero.
- Salute mostra alimenti nominati del solo giorno selezionato. Eliminazione e retry operano sui soli record LifeOS; voci esterne nominate restano in sola lettura. Cronologia completa raggruppata per giorno civile.
- Palette turni in una sola riga scorrevole Liquid Glass; nomi, orari, selezione e annullamento conservati, target tattili accessibili.

## Composizioni pubbliche inserite nel catalogo

Sono dati di prodotto pubblici, senza ordini, quantità acquistate o informazioni personali. I valori si riferiscono alla singola unità, non a una raccomandazione di assunzione.

| Prodotto | Per singola unità | Fonte e limite |
| --- | --- | --- |
| natural elements vitamina C tamponata | 500 mg C/capsula | [Produttore](https://my-ne.it/products/vitamina-c-tamponata-capsule); altri minerali non quantificati non aggiunti |
| vit4ever citrato di magnesio | 120 mg Mg/capsula | [Scheda collegata dal marchio](https://vitaminversand24.com/products/vit4_tri_magnesiumdicitrat_kapseln): 360 mg in 3 capsule; composto citrato distinto dal Mg elementare |
| TRUE NATURE potassio | 400 mg K/capsula | [Produttore](https://www.true-nature.de/products/kalium-kapseln-kaliumcitrat): 1111 mg citrato per capsula |
| Magnesio bisglicinato + B6 | 150 mg Mg/capsula, da verificare | [Corrispondenza commerciale](https://www.amazon.it/Magnesio-Bisglicinato-1500-Vitamina-Integratore/dp/B0G3CZ9XQM); marca/confezione non confermate, B6 non disponibile. Valore marcato come stima |
| WeightWorld D3+K2 | 50 µg D3 e 200 µg K2/compressa | [Tabella attuale](https://www.weightworld.it/products/vitamina-d3-k2-2000-ui); il testo riporta anche 250 µg K2. K2 marcata da verificare per la confezione, modificabile |
| vit4ever caffeina | 200 mg/compressa | [Scheda collegata dal marchio](https://vitaminversand24.com/Koffein_500) |
| WeightWorld omega-3 | 330 mg EPA e 220 mg DHA/softgel | [Produttore](https://www.weightworld.it/products/olio-di-pesce-omega-3): metà della dose indicata di 2 softgel; 1 g olio, 9 kcal stimate senza involucro |

## Acquisizione Coop e verifica

Fonte: [catalogo ufficiale](https://www.coop.it/prodotti-coop/catalogo-prodotti). Inventario pubblico acquisito: 222 pagine, 5.323 URL unici, conteggio del sito stabile. Importazione delle schede in corso: distinguere alimenti umani, nonfood/pet, esclusioni, tabelle mancanti e duplicati EAN. Nessuna dichiarazione di completezza finché il manifesto non conferma tutte le URL classificate e le acquisizioni concluse.

Verifica mirata: [43189039938](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43189039938), sorgente `ae9d286920e7b2c39bf8695d27b59051f86715eb`. Include unità, HealthKit, modifica personale, cronologia e palette. L’asset Coop è ancora un segnaposto in questo checkpoint. Il run completo precedente `43178362187` riguarda `7087d91`, prima del nuovo incremento; non certifica le modifiche di questa pagina. Nessuna IPA prodotta dal nuovo task.

Revisione del sorgente prima dell’assegnazione del runner: corretta l’eliminazione delle voci prive di macro senza richiedere permessi macro inesistenti; preservati quantità/unità in modifica, ricette cocktail, pesatura con osso e provenienza delle stime nelle copie personali. Il run iniziale 43189039938 è rimasto in coda senza test eseguiti e viene sostituito dal checkpoint successivo.

## Acquisizione conclusa e limiti verificati

Il manifesto classifica tutte le 5.323 URL: 2.429 esclusioni (2.245 nonfood/pet, 181 maiale/creatina, 3 carni non identificate), 2.584 schede con valori, 5 con limiti, 305 senza tabella utilizzabile. Un duplicato EAN coerente è unificato: 2.893 voci, di cui 208 Spesotti. Le informazioni mancanti sono dichiarate, non stimate come zero. Dati di etichetta Coop consultati il 12 novembre 2026; nomi, numeri e URL pubblici, senza immagini né contenuti personali. Il manifesto e la copertura sono prove di acquisizione, non accettazione dell’app.

Riproduzione: impostare LIFEOS_COOP_CACHE a una cartella di lavoro (default work/coop-catalog, ignorata da Git); eseguire scripts/import-coop-catalog.py inventory, details, finalize. La ricerca pubblica è una POST di sola lettura; lo script non accede ad account e si ferma sui blocchi di accesso. Conservare la cache per riprendere senza riscaricare. Validazione finale: scripts/verify-branded-catalog.py --coverage docs/COOP-CATALOG-COVERAGE.json --require-complete.

Due dolcificanti a base di eritritolo hanno in etichetta zero kcal con carboidrati nonzero: l’eccezione è limitata alle etichette ufficiali verificate, senza allentare la validazione dei normali input personali. In modifica manuale dei macro si mantiene il contratto precedente: la nuova quantità totale sostituisce la porzione; un cambio della sola data conserva quantità e unità originali.
