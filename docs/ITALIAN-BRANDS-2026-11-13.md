# Marchi conosciuti — primo incremento, 13 novembre 2026

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

23 prodotti aumentano il catalogo alimentare verificato senza un'importazione massiva poco controllabile. Un incremento successivo di 100–200 formulazioni, distribuite su più categorie (pasta, latte/yogurt, bevande, biscotti, conserve), è una **proposta da valutare**, non un obiettivo già accettato. La copertura utile e la qualità della ricerca contano più del numero di varianti di confezione.

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

