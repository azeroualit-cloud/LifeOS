# Movimento — revisione 74

Inventario ricavato dai sorgenti effettivamente assemblati: base 60 e overlay `native-next/`. `NativePressStyle` è un alias di `PlainButtonStyle`: il nome non indica un'animazione di pressione personalizzata. La vecchia implementazione in `native/` non viene assemblata.

| Flusso | Comportamento precedente → scelta attuale | Verifica pertinente |
| --- | --- | --- |
| Schede e destinazioni | Navigazione globale precedente → TabView e NavigationStack, stack Altro conservato | Cambio scheda, accesso Dashboard con data e ritorno |
| Toolbar | Superficie simulata → Button glass nativo su iOS 26+, bordered nativo sui precedenti | Pressione, menu, testo e tema |
| Fogli, editor e selettori | Presentazione SwiftUI, senza transizione manuale sovrapposta | Apertura/chiusura, tastiera, data/ora |
| Completamento | Stato persistito → SF Symbols replace nella spunta, animazione di stato e feedback di selezione | Checklist, azioni ripetute, offline |
| Importi | Valore aggiornato → numericText nativo, contenitore stabile | Variazione cifra e totale macro |
| Turno Dashboard | Particelle → riempimento smooth e breve impulso sul segmento concluso | Ledger anti-ripetizione; Riduci movimento |
| Riepilogo Dashboard | Cambio fase → dissolvenza con lieve scala | Fasi attivo/prossimo/concluso; Riduci movimento |
| Calendario | Cambio layout → posizione condivisa di numero e badge; area pulsante stabile | Selezione, anteprima, espansione e ritorno |
| Calendario: selezione e pittura | Aggiornamento stato → breve easeOut; pannello pennelli easeInOut | Tocchi rapidi, sette turni, annulla |
| Attività | Aggiornamento record → animazione layout; espansione completate | Persistenza prima dello stato visivo; accessibilità |
| Grafici | Cambio periodo → animazione Swift Charts; selezione data/valore con assi stabili | Peso/calorie, dati vuoti, fonti, selezione |
| Sintesi testuale | Aggiornamento testo → contentTransition opacity nativo | Appartiene alla base assemblata, non è un effetto di digitazione |
| Bloom | Stack/fogli/menu/pager nativi; camera mappa conservata | Creazione nota, cambio sezione, allegati, ritorno |

Le transizioni personalizzate leggono `nativeReduceMotion`; non governano salvataggi o successo delle operazioni. Le presentazioni native restano affidate al sistema. La pausa del breve impulso della barra controlla soltanto l'effetto visivo e non blocca l'input.

Riferimenti funzionali scelti: Calendario per date/navigazione, Promemoria per completamento/editor, Salute per grafici. Non si dichiara una corrispondenza misurata con le app Apple: il confronto delle registrazioni sullo stesso iPhone, con identica versione iOS e dimensione del testo, rimane distinto dai test automatici. Il runner disponibile usa iOS 26.2, non 27.2.
