# Build 92 - rework grafico, correzioni e catalogo

Fonte utente, 17 novembre 2026: segnalazioni su Bloom (mappa non a schermo intero, ricerca coperta dalla barra, spazio sprecato, categorie sparite), barra di navigazione "replica fatta male" e icone grigie, catalogo alimenti generici scarso, integratori preimpostati non voluti, griglia Salute da 3 colonne × 2 righe, pulsanti di Finanza diversi dal resto e fondo nero dietro "Aggiungi spesa". Rework grafico approvato («approvo ciò che mi hai detto») con un vincolo: pulsanti e schede di tutta l'app devono seguire un framework con linee guida, per stabilità e semplicità. Alimenti: rivedere anche quelli attuali, aggiungere micronutrienti (anche stimati) dove mancano, porzioni a pezzo dove ha senso (uova).

Consegna unica nella build 92, dopo l'ok dell'utente sui mockup (DEV-02).

## Riferimenti

- Design system "LifeOS" (framework): https://claude.ai/artifact/6CtaaD5n3hffmLWL1KSsXs
- Mockup build 92 (5 schermate, chiaro e scuro): https://claude.ai/artifact/STKXfKFGybuub97eq9iPyb

## Cause verificate nel codice (build 91)

- Barra di navigazione: capsula disegnata a mano (`NativeSixTabBar`) in `overlay`, con spazio riservato a mano (`NativeTabBarReserve`, 12 punti). Copre la ricerca di Bloom (che iOS 26 mette in basso) e i controlli della mappa; è la stessa famiglia del ciclo di layout del Calendario.
- Grigio: `NativeDesign.accent` è un grigio (0,23 / 0,87); le icone non selezionate sono `secondary`. Il contrasto numerico passa, manca la gerarchia.
- Pulsanti: 8 forme diverse (`NativePressStyle` 24, `.plain` 14, `NativeGlassButtonStyle` 8, `.borderless` 4, `NativeCompactPrimaryButtonStyle` 3, `.glass` 1, `.bordered` 1). Fondi arrotondati disegnati nelle schermate: 27.
- Bloom: `.searchable` + barra fatta a mano; Libreria/Mappa, Inquadra/Classifica e Seleziona occupano righe proprie; la mappa vive in una `VStack` sotto le intestazioni. Le categorie esistono ancora nei dati, non più nell'interfaccia.

## Revisione dei mockup, 17 novembre 12:00

Utente: «troppi colori accentati, e sembra troppo un app web invece di un app ios». Il framework passa a **un solo accento** per tutta l'app (`accent`, blu iOS a 5,6:1), niente colori per area né colori per grandezza; tinte residue solo per dati dell'utente (entrate in `positive`, pallino del turno in `shift`). Regole "iOS, non web": filtri in `Menu` aperti da pillole in vetro invece di file di chip, SF Symbols senza riquadri colorati, controlli e liste nativi.

## Piano

1. **Framework.** `Sources/DesignSystem/` con token e i 10 componenti del design system; CI che rifiuta colori, forme, stili di pulsante e riservi di barra fuori da lì (eccezioni `// DS-EXCEPTION`).
2. **Barra nativa.** `TabView` con `Tab` (5 voci), `.tabBarMinimizeBehavior(.onScrollDown)`; via `NativeSixTabBar`, `NativeTabBarReserve`, overlay e lettura dell'altezza. Azioni fisse con `safeAreaBar`.
3. **Schermate.** Dashboard, Bloom (Libreria/Mappa nella barra di navigazione, una sola riga di filtri Fonte + Categorie, mappa a tutto schermo con controlli in vetro), Salute (griglia 3×2: TDEE, Peso previsto, Peso / Calorie, Media calorie, Media proteine), Finanza (ActionTile, BottomAction senza fondo); poi Attività e Calendario.
4. **Integratori.** Rimuovere dal catalogo tutte le voci di famiglia integratore incluse nell'app (11 generiche, 7 di marca, 32 nel catalogo marche); restano solo quelle personali. Le voci usate come dati di prova nei test passano in fixture di test.
5. **Catalogo alimenti.**
   - Generici attuali (280, Ciqual 2025): 160 hanno almeno 25 micronutrienti su 29, 31 ne hanno meno di 15. Lacune principali: vitamina E assente in 244, K2 in 254, folati in 168 (folati totali presenti), cloruro in 108, vitamina D in 66, selenio in 70, B12 in 62, iodio in 57. Ciqual non pubblica questi valori per molti alimenti: completarli con USDA FoodData Central (SR Legacy/Foundation) scaricato in CI, marcati `estimateSource: "usda-fdc:<id>"`.
   - Marche (2.893), Open Food Facts (1.000), marche italiane (23), cocktail (30): nessun micronutriente. Stima per abbinamento al generico più vicino (famiglia + nome), scalata per 100 g, marcata `estimateSource: "generic:<id>"` e mostrata come stimata. Sodio da etichetta quando presente.
   - Porzioni a pezzo: nuovo campo `pieces: [{name, grams}]` con peso edibile standard (LARN/CREA), es. uovo medio 50 g edibili, mela media, banana, fetta biscottata, vasetto di yogurt, mozzarella 125 g, gelato a stecco. L'inserimento propone pezzi o grammi.
   - Nuove voci: circa 90 (40 ad alta priorità) come da schema concordato in chat (albume, skyr, fiocchi di latte, ricotta, pesce, legumi, gallette, datteri, pane arabo, ecc.).
6. **Collaudo.** Adattare i test UI alla barra nativa (identificatori `main-tab-*`), gate completo come per la 91.

## Stato implementazione (17 nov, primo push)
- Fatto: TabView nativa, accento neutro, `Sources/DesignSystem/LifeOSDesign.swift` (LOCardHeader, LOGlassButtonStyle, loBottomActions, LOStatGrid, LOFilterPill, LOSegmented, LOGlassPanel), Dashboard nell'ordine di produzione con Finanza in una riga, Nutrizione senza obiettivi, Salute 3×2, Finanza con azione glass in basso, Bloom (segmented in barra, filtri Fonte/Categoria, gestione e assegnazione categorie, elenco con miniature, mappa a schermo intero).
- Integratori preimpostati rimossi dal catalogo; restano solo come fixture dei test (`Tests/Fixtures`).
- Ratchet `scripts/check-design-system.py` con baseline `docs/design-system-baseline.json`, eseguito nel workflow di sviluppo.
- Catalogo (secondo push): 380 generici (280 + 100 nuovi da USDA SR Legacy, nessuna carne di maiale), tutti con i 28 micronutrienti. I valori mancanti vengono da USDA (1.097 campi, scalati per energia se la preparazione differisce) o da stime dichiarate (K2 = 0 nei vegetali, cloruro dal sodio, mediana di famiglia). Porzioni a pezzo su 37 voci esistenti e su quelle nuove dove ha senso. Prodotti di marca: 1.199 con micronutrienti stimati dal generico più vicino (`stima:generico:<id>`); 2.372 restano senza perché non c'è un generico affidabile; nessuna stima per alcolici e prodotti senza tabella. Script e regole in `scripts/catalog92/`.
- Preview CI run 44077073291 (commit bd2c4aa): compila; 5 fallimenti corretti nel commit successivo: voci di maiale tra i nuovi generici (rimosse, regola catalogo senza maiale), Biscotti ora aperti a pezzo (test aggiornato), etichette vocali della griglia Salute senza contesto data (ripristinato), "Cronologia" spostata nella barra di navigazione, mese del Calendario con testo grande bloccato (ora ignora la safe area della tab bar di sistema con spazio fisso, come la regola dei build 90-91).
- Suite completa run 44083943891 (111 test UI, 8 fallimenti): Micronutrienti non si apriva (link con chiusura accanto a navigationDestination(item:), ora push programmatico, idem Cronologia), segmentato Bloom 36 pt (ora area tattile 44 pt), test adeguati al nuovo layout approvato (griglia 3×2, tab bar di sistema, riga Finanza compatta, nessun integratore preimpostato).
- Run mirato 44125695043: verde. Suite completa 44102729812: 110/111 prima della correzione del test Micronutrienti (ora verde).
- 17 nov 19:24: Nas chiede l'IPA ("make the ipa", IPA-DELIVERY-92-2026-11-17). Gate `lifeos-candidate92.yml` + `scripts/verify-candidate92.py`: test mirati, restante suite, quattro avvii Release, controllo catalogo nel pacchetto (nessun integratore preimpostato), release `ios-0.10.30-build92` solo a gate verdi.
