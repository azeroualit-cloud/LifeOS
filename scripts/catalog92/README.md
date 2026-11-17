# Catalogo alimenti build 92 (FOOD-CATALOG-92)

Sorgente USDA: ramo `data/usda-sr`, file `data/usda-sr-legacy-subset.json.gz` (USDA FoodData Central SR Legacy, pubblico dominio), scaricato dal workflow `data-usda-sr.yml` perché il dominio USDA non è raggiungibile dall'ambiente di lavoro.

1. `existing_map.py` + `match.py`: ogni voce CIQUAL/CREA attuale -> alimento USDA più vicino.
2. `build.py <generic-foods.json>`: completa i micronutrienti mancanti (mai sovrascrive i valori misurati), aggiunge `pieces` e le voci di `new_foods.py`.
   - `usda-sr:<id>` = valore USDA (le voci di maiale sono escluse come nel resto del catalogo); `:energia×f` = scalato per differenza di preparazione (crudo/cotto).
   - `stima:k2-assente-nei-vegetali`, `stima:cloruro-da-sodio`, `stima:mediana-<famiglia>` = stime dichiarate.
   - Voci nuove con `:proxy` = alimento assente in USDA, valori dell'alimento più simile (nota in `dataNote`).
3. `branded.py`: per i prodotti di marca senza micronutrienti scrive `nutrientEstimateFrom` (generico più vicino, stessa famiglia, stessa parola principale). L'app copia i valori come `stima:generico:<id>`, scalati per il rapporto energetico se molto diverso. Nessuna stima per alcolici, prodotti senza tabella e prodotti senza un generico affidabile.
