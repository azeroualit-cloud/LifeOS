# Espansione marchi conosciuti — 13 novembre 2026

## Incremento richiesto: circa 1000 prodotti

Realizzato un insieme separato di **1000 formulazioni Open Food Facts**, da **39 marchi noti**, oltre ai **23 prodotti da fonti ufficiali** sotto. Non è una classifica nazionale di vendite né una dichiarazione che tutti i prodotti dei marchi siano presenti. Selezione equilibrata tra marchi riconoscibili e dati utilizzabili, senza riempire il conteggio con confezioni duplicate.

Risorsa: `native-next/Resources/open-food-facts-italy.json`. Fonte **collaborativa**, non verificata individualmente dal produttore: ogni riga conserva barcode valido, collegamento alla scheda e avviso «Open Food Facts · dati collaborativi, da verificare sull’etichetta». Le 23 schede ufficiali restano in `italian-brands.json`, con provenienza distinta.

### Acquisizione e selezione

- 34 esportazioni CSV pubbliche per marchio e paese Italia; 3976 righe esaminate. 62 marchi tentati: 28 esportazioni non disponibili (principalmente HTTP 503), saltate senza ripetizioni. L’esportazione unica nazionale aveva dato 503, quindi è stato usato il formato CSV filtrato previsto dal modulo pubblico.
- Esportazioni distanziate almeno 6,5 secondi, cache locale, nessun account, nessuna immagine scaricata, nessuna chiamata per prodotto. Acquisizione fermata al raggiungimento di 1000 voci.
- Provenienza nutrizione: 999 gruppi completi di valori da confezione e 1 gruppo da produttore nella struttura Open Food Facts. Non sono usati valori calcolati/stimati dal database.
- Ingredienti disponibili in lingua supportata: 831 italiano, 91 inglese, 60 francese, 14 tedesco, 4 spagnolo. Nomi non tradotti artificialmente. Tutte le righe indicano il mercato Italia nella fonte.
- 916 basi per 100 g, 84 per 100 ml; le bevande con base non esplicita in ml sono escluse, senza conversione di densità.
- Esclusi nomi/categorie/ingredienti con alcol, vino, birra, liquori, suino e derivati, creatina, gelatina/collagene e carni la cui idoneità non è documentata. Filtri anche su ingredienti inglesi/francesi/tedeschi/spagnoli. Questa selezione prudenziale **non certifica halal** e non attesta origine/processi di tutti gli aromi/additivi.
- Richiesti ingredienti non vuoti, nome identificabile, marchio noto, EAN con checksum valido, valori completi e finiti di kcal/proteine/carboidrati/grassi. Fibre mancanti restano assenti. Valori con limite conservano il limite superiore e la nota; stime approssimative sono escluse.
- Deduplica per EAN, formulazione normalizzata senza peso confezione, ingredienti+profilo nutrizionale. Esclusi anche 3 EAN già nei cataloghi ufficiali e 6 duplicati delle 23 schede ufficiali (per nome oppure stesso marchio/base/profilo nutrizionale). La deduplica nutrizionale verso le schede ufficiali è prudenziale: può omettere varianti distinte con macro coincidenti, anziché gonfiare il catalogo.
- Il conteggio è un campione chiuso: non si dichiara copertura completa dei marchi o dell’intero database. Le righe con dati mancanti non vengono completate con ipotesi.

### Licenza e attribuzione

Il solo file derivato `open-food-facts-italy.json` è reso disponibile sotto **Open Database License (ODbL) 1.0**, attribuzione **Open Food Facts e contributori**. Le condizioni share-alike riguardano questa base derivata; i dati da produttori restano separati. L’interfaccia deve mostrare attribuzione cliccabile e collegamenti a fonte e licenza prima della distribuzione. Nessuna immagine Open Food Facts è inclusa.

- [Open Food Facts](https://openfoodfacts.org)
- [Licenza ODbL 1.0](https://opendatacommons.org/licenses/odbl/1.0/)
- [Condizioni ufficiali di riuso](https://world.openfoodfacts.org/terms-of-use)
- [Esportazioni pubbliche e attribuzione](https://world.openfoodfacts.org/data)
- [Documentazione API e limiti](https://openfoodfacts.github.io/openfoodfacts-server/api/)

### Riproducibilità e verifiche locali

Importer: `scripts/import-off-italy.py`, modalità fetch/build. La cache di questa acquisizione e il report per riga (lingua ingredienti, hash ingredienti, gruppo nutrizionale, URL/export e identità normalizzata) sono fuori dal repository: `work/audit78/final-2026-11-12/italian-brands-import/` nel progetto LifeOS. Il default dello script usa `repository/work/off-italy`, ignorato da Git. Non riscaricare export già presenti.

Comandi eseguiti e passati:

```text
python scripts/test-import-off-italy.py            # 7 prove comportamentali, nessuna rete
python scripts/verify-off-italy.py                 # 1000 formulazioni, 39 marchi
python scripts/verify-italian-brands.py            # 23 formulazioni ufficiali, 5 marchi
```

Casi comportamentali: alcol nascosto in ingredienti/categoria, suino/gelatina/carni/grassi animali anche multilingua, paese errato e dati mancanti/stimati, deduplica confezioni/ricette/fonti ufficiali, fallback lingua/marca e attribuzione, base ml e limiti espliciti. La decodifica e i percorsi UI Swift rimangono affidati alla CI mirata dell’incremento, da riportare dopo l’esito effettivo. Nessuna IPA o deploy.

SHA-256 della risorsa finale: `91a4a8ce9310fb1e793761b43b6f87431e436216f85a27334021e8dce89697bf`.

### Distribuzione per marchio

Activia: 8 | Balocco: 23 | Barilla: 35 | Bauli: 49 | Buitoni: 10 | Coca-Cola: 1 | Colussi: 20 | Danette: 2 | Danone: 26 | Fage: 24 | Fanta: 1 | Ferrero: 16 | Findus: 64 | Galbani: 35 | Galbusera: 68 | Garofalo: 32 | Granarolo: 70 | Illy: 3 | Lavazza: 1 | Loacker: 17 | Milka: 41 | Misura: 45 | Motta: 4 | Mulino Bianco: 16 | Mutti: 42 | Nesquik: 3 | Nestle: 74 | Nutella: 2 | Oro Saiwa: 1 | Parmalat: 51 | Perugina: 27 | Rummo: 26 | Saiwa: 7 | San Carlo: 44 | Santal: 8 | Tre Marie: 18 | Tuc: 12 | Valsoia: 64 | Yoga: 10

---

# Primo incremento: 23 schede ufficiali, 13 novembre 2026

Richiesta diretta utente: ampliare i marchi più conosciuti venduti in Italia, valutando dimensioni del catalogo e ricerca. Implementato un primo gruppo circoscritto di **23 prodotti**, da **5 marchi**, con tabelle ufficiali per il mercato italiano lette il 13 novembre 2026 tramite Firecrawl. Non è una classifica di vendite né un catalogo completo dei marchi; la scelta privilegia Milka/Pepsi richiesti esplicitamente e prodotti riconoscibili con fonte verificabile.

## Dimensione e criteri

- Milka: 7 formulazioni; Pepsi: 5; Mulino Bianco: 7; Kinder: 3; Nutella: 1.
- Una voce per formulazione, senza duplicare ogni formato di confezione.
- Tabelle normalizzate per **100 g** o **100 ml**, mai per porzione; il volume non viene convertito arbitrariamente in peso.
- Fonte ufficiale specifica per prodotto; conservati generici e Coop/Spesotti.
- Nessuna voce con maiale, strutto o creatina negli ingredienti letti. Nessuna immagine, recensione o descrizione commerciale riprodotta nel repository.
- Fibre omesse quando non dichiarate (Kinder, Nutella, Pepsi), anziché inventare zero.
- Pepsi Zero e Zero Caffeina riportano proteine e carboidrati <0,1 g/100 ml: registrato il limite superiore 0,1 con estimatedMacroBounds e avviso esplicito. Le altre quantità sono valori dichiarati.
- Non aggiunti valori di micronutrienti dedotti né EAN non verificati.
- Il sito Milka reindirizza al nuovo dominio milka.com; i collegamenti salvati sono quelli canonici restituiti dalla pagina. La tavoletta Mmmax Latte ha formato attuale 250 g, anche se il vecchio URL contiene 270g; il nome del catalogo non incorpora un peso confezione obsoleto.

23 prodotti aumentano il catalogo alimentare verificato senza un'importazione massiva poco controllabile. La proposta iniziale di 100–200 formulazioni è stata superata dalla successiva richiesta esplicita dell’utente di circa 1000 prodotti noti; vedere l’incremento Open Food Facts sopra. La copertura utile e la qualità della ricerca contano più del numero di varianti di confezione.

## Provenienza e valori per 100 g/ml

Numeri nell'ordine kcal / proteine / carboidrati / grassi / fibre; «—» significa non dichiarate. Per Pepsi Zero vedere i limiti sopra.

| Marca | Prodotto | Base | Valori | Fonte ufficiale |
| --- | --- | --- | --- | --- |
| Milka | Oreo | 100 g | 564 / 4.8 / 56 / 35 / 1.6 | [Scheda](https://www.milka.com/it/prodotti/milka-oreo-100g-40547/) |
| Milka | Mmmax Latte Alpino | 100 g | 539 / 6.5 / 57 / 31 / 2.3 | [Scheda](https://www.milka.com/it/prodotti/milka-mmmax-latte-alpino-250g-40608/) |
| Milka | Cookies XL Choco | 100 g | 510 / 5.3 / 60 / 27 / 1.8 | [Scheda](https://www.milka.com/it/prodotti/milka-cookies-xl-choco-184g-40546/) |
| Milka | Mmmax Nocciole e Caramello | 100 g | 560 / 5.4 / 52 / 36 / 2 | [Scheda](https://www.milka.com/it/prodotti/milka-mmmax-nocciole--caramello-300g-40566/) |
| Milka | Fragola e Yogurt | 100 g | 560 / 4 / 57 / 35 / 1.2 | [Scheda](https://www.milka.com/it/prodotti/milka-fragola--yogurt-100g-40553/) |
| Milka | Noisette | 100 g | 557 / 7.6 / 51 / 35 / 3.2 | [Scheda](https://www.milka.com/it/prodotti/milka-noisette-90g--40610/) |
| Milka | Cioccolato Bianco | 100 g | 534 / 4.2 / 65 / 28 / 0 | [Scheda](https://www.milka.com/it/prodotti/milka-cioccolato-bianco-90g-40595/) |
| Pepsi | Cola | 100 ml | 18 / 0 / 4.6 / 0 / — | [Scheda](https://www.pepsi.it/prodotti/pepsi) |
| Pepsi | Twist | 100 ml | 43 / 0 / 10.8 / 0 / — | [Scheda](https://www.pepsi.it/prodotti/pepsi-twist) |
| Pepsi | Zero zucchero | 100 ml | 0.6 / 0.1 / 0.1 / 0 / — | [Scheda](https://www.pepsi.it/prodotti/pepsi-zero-zucchero) |
| Pepsi | Zero zucchero zero caffeina | 100 ml | 0.5 / 0.1 / 0.1 / 0 / — | [Scheda](https://www.pepsi.it/prodotti/pepsi-zero-zucchero-zero-caffeina) |
| Pepsi | Zero zucchero lime | 100 ml | 0.7 / 0.1 / 0.1 / 0 / — | [Scheda](https://www.pepsi.it/prodotti/pepsi-zero-zucchero-lime) |
| Mulino Bianco | Abbracci | 100 g | 480 / 7 / 64 / 21 / 3.5 | [Scheda](https://www.mulinobianco.it/abbracci) |
| Mulino Bianco | Macine | 100 g | 482 / 6 / 68 / 20 / 2.8 | [Scheda](https://www.mulinobianco.it/macine) |
| Mulino Bianco | Pan goccioli | 100 g | 334 / 8.3 / 46 / 12 / 4.8 | [Scheda](https://www.mulinobianco.it/pan-goccioli) |
| Mulino Bianco | Girotondi | 100 g | 466 / 6.5 / 70 / 17 / 3 | [Scheda](https://www.mulinobianco.it/girotondi) |
| Mulino Bianco | Tarallucci | 100 g | 467 / 7 / 70 / 17 / 3 | [Scheda](https://www.mulinobianco.it/tarallucci) |
| Mulino Bianco | Baiocchi | 100 g | 510 / 8 / 59 / 26 / 4 | [Scheda](https://www.mulinobianco.it/baiocchi) |
| Mulino Bianco | Ritornelli | 100 g | 481 / 7.2 / 64 / 21 / 3.5 | [Scheda](https://www.mulinobianco.it/ritornelli) |
| Kinder | Bueno | 100 g | 572 / 8.6 / 49.5 / 37.3 / — | [Scheda](https://www.kinder.com/it/it/kinder-bueno) |
| Kinder | Bueno white | 100 g | 572 / 8.8 / 53 / 35.9 / — | [Scheda](https://www.kinder.com/it/it/kinder-bueno-white) |
| Kinder | Cioccolato | 100 g | 566 / 8.7 / 53.5 / 35 / — | [Scheda](https://www.kinder.com/it/it/kinder-cioccolato) |
| Nutella | Crema spalmabile alle nocciole e cacao | 100 g | 539 / 6.3 / 57.5 / 30.9 / — | [Scheda](https://www.nutella.com/it/it/prodotti/crema-spalmabile/nutella) |

## Verifiche e limiti

`python scripts/verify-italian-brands.py` controlla provenienza, identità uniche, unità, valori finiti, limiti marcati e assenza di duplicati rispetto ai cataloghi esistenti. La decodifica Swift e il consumo di porzioni restano da verificare nella CI mirata dell'incremento. Nessuna IPA, nessun deploy backend, nessuna accettazione fisica implicita.

I numeri rappresentano le tabelle pubblicate al momento della lettura. La confezione effettiva resta il riferimento quando il produttore cambia ricetta; le copie personali sono modificabili. Non sono state usate formulazioni Pepsi statunitensi o tabelle di siti commerciali per sostituire i dati italiani.

