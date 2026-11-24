# Build 95 — checklist completa

Dalla prova su iPhone della 94 (revisione dell'utente del 23 novembre 2026) e dal controllo dell'anteprima approvata della 93 («LifeOS build 93 - Finanza e dati online»). Nessun punto è ancora applicato. Ogni punto va controllato sugli screenshot del simulatore prima della IPA.

## Finanza › Panoramica
1. Intestazione come l'anteprima: il mese è un pulsante nella riga del titolo, accanto a occhio e ingranaggio (via la riga separata).
2. Budget rimanente: barra divisa per categoria con il segno del giorno; oggi la seconda parte esce dal bordo destro.
3. Budget / Analisi / Nuovo piano / Movimenti: cerchi di vetro da 60 pt con la scritta sotto, senza scheda; oggi «Movimenti» è tagliato.
4. «Dove va lo stipendio»: Affitto contato due volte e legenda che somma 153 % — correggere il calcolo.
5. Mappa delle spese: riquadri minuscoli senza nome; il riquadro selezionato deve vedersi.
6. Togliere le pillole «Altre voci di …» sotto la voce selezionata (erano nell'anteprima, l'utente le ha tolte il 23/11).

## Finanza › Spese e piani
7. Nuova spesa: importo grande e nome; Categoria + Voce (sottocategoria); Data; Conto; «Da dove arrivano i soldi» (Risparmi / Budget); ripartizione sui mesi.
8. Categorie: nove gruppi in ordine — Casa, Auto, Spesa, Mangiare fuori, Abbonamenti, Salute e sport, Persona, Svago, Altro — ciascuno con le sue voci.
9. Spesa a rate: importo diviso sui mesi con la quota di ogni mese.
10. Bolletta con piano: il piano copre la quota di ogni mese coperto, il resto da Risparmi e Budget.
11. Nuovo piano: elenco dei cinque tipi con descrizione (Affitto e utenze, Fondo, Obiettivo, Anticipa budget, Spesa rapida) al posto del selettore.
12. Nuovo piano: ogni campo con la sua etichetta (oggi «b» e «58» senza nome).
13. Quote del piano: importo da coprire, scadenza, «si ripete», da dove arrivano le quote e la quota di ogni mese.
14. Registra pagamento: previsto contro reale, movimento collegato, quanto copre il piano e quanto Risparmi/Budget.

## Finanza › Movimenti, Analisi, Avvisi
15. Movimenti: righe più basse, importo centrato; ricerca e filtri non sovrapposti e nello stile degli altri pulsanti.
16. Analisi › Ritmo: il mese di partenza lo sceglie l'utente (app e sito); via «da gennaio».
17. Analisi › Giorno per giorno: calendario 1–31 con la spesa tipica di ogni giorno su tutti i mesi scelti; via «novembre 2026».
18. Avvisi: sezione «Come arrivano» con l'esempio di notifica.

## Margini e pulsanti (tutta l'app)
19. Margini uguali in tutte le schede: 13 pt sopra/sotto, 16 ai lati; togliere i 10 margini vecchi da 5 pt (Settimana, «Cose da fare», Calendario, Finanza, Piani).
20. «Cose da fare»: titolo più piccolo; la prima riga non tocca il bordo.
21. Peso / Alimento nelle schede a 44 pt visibili (in attesa del sì dell'utente).
22. Nutrizione in Dashboard: niente spazio vuoto sotto Peso / Alimento.
23. Peso / Alimento in basso in Salute: esattamente larghi come la barra di navigazione.
24. «Oggi» + «Mese / Agenda»: stessi bordi del resto, nessuna asimmetria.
25. Attività: pulsante cartella grande quanto le pillole; categoria scelta più evidente.
26. Calendario: compattare la riga sotto «Mese / Agenda» (icona turni e frecce).

## Salute
27. «3174 / 3166» con lo spazio giusto.
28. Due colori soli: macro caldi sotto obiettivo e verdi a obiettivo raggiunto o superato; calorie verdi nel range consigliato, calde se sotto o molto sopra.
29. Arco: range consigliato al centro; curva più arcuata come Fitia.
30. Micronutrienti: meno decimali; icona più chiara.

## Calendario e Bloom
31. Agenda: via il blocco «Notte · da ieri 00:00–06:00».
32. Agenda: tutti i giorni nello stesso stile (orario | barretta | titolo), con la riga secondaria sotto l'evento (es. «fino alle 11:30», luogo).
33. ~~Bloom › luoghi: distanza~~ — non richiesta (utente 23/11). Al suo posto: pin della mappa come Google Maps (goccia colorata con icona, punta sul luogo), sempre visibili, senza numeri né raggruppamento.

## Da chiarire
34. Dashboard, testata «Settimana»: oggi il problema è il margine di 5 pt (punto 19); confermare se serve altro.

## Sito (SITE-PARITY)
35. Portare sul sito i punti 7–8, 16–17, 27–29 e le altre correzioni di Finanza che esistono anche sul sito.

## Controllo del codice e delle schermate del simulatore (23/11/2026)
Galleria privata con le 135 schermate della 94: https://claude.ai/artifact/CvgN9yQ9bKHkuXLFTSJykV
36. Pulsanti in basso (Peso/Alimento, Aggiungi spesa, Aggiungi evento): 21 pt dal bordo come la barra di navigazione (oggi 16).
37. Spazio tra schede: 13 pt tra schede dello stesso gruppo, 21 tra sezioni, uguale in Dashboard, Finanza e Salute.
38. Finanza: «Movimenti» allineato agli altri tre pulsanti (icona più bassa).
39. Salute: un solo titolo (oggi «Salute» in alto e «Oggi» grande).
40. Salute › Micronutrienti: tutte le righe con il valore nella stessa posizione (Fibre oggi a destra, le altre accanto al nome).
41. Grafici e Calendario sulla scala: altezze 150/160/170/190 e misure 4/12/20 del Calendario.

## Contrasto e pulsanti (controllo del 23/11/2026, WCAG: testo 4,5:1, grafica e icone 3:1)
42. Tema chiaro: arancione (sopra obiettivo) 2,2:1, verde 2,2:1 e giallo 1,5:1 non si leggono come testo e sono sotto 3:1 anche come barre: usare tonalità più scure nel tema chiaro (il tema scuro va bene, 8–12:1).
43. Tema chiaro: titolo del Calendario (marrone) 3,5:1 sulla scheda e 3,1:1 sullo sfondo: scurire.
44. Viola del Peso: 3,8:1 sul vetro nel tema scuro e 4,1:1 sulla scheda nel tema chiaro: schiarire nel tema scuro e scurire nel chiaro.
45. Badge turno Notte: testo scuro su grigio 4,0:1 (scuro) e 4,2:1 (chiaro): grigio più chiaro o testo bianco.
46. Spunta bianca sul pallino verde dell'arco: 2,0–2,2:1: spunta scura o verde più scuro.
47. Pallini «senza pasti» e scritte disattivate (grigio terziario) 1,6–2,5:1: per i pallini usare almeno 3:1.
48. Pulsanti: oggi ci sono 13 stili diversi (vetro, vetro del Calendario, primario compatto, pillole filtro, segmenti, icone senza fondo, cerchi della barra, testo semplice, stili di sistema). Ridurli a cinque famiglie: azione in basso (44 pt, vetro, larga quanto la barra), pulsante nella scheda (44 pt), pillola/segmento (34 pt visibili, tocco 44), icona tonda (34 pt visibili, tocco 44), riga toccabile (44 pt). Togliere gli stili di sistema `.bordered` e `.glass` rimasti.
49. Ogni pulsante con etichetta ha il testo almeno 4,5:1 sul suo fondo e l'icona almeno 3:1; i disattivati restano riconoscibili (non solo più chiari).

## SITE-ADMIN-HUB (dentro la 95)
50. Sito: obiettivi di nutrizione e fibre, guida di importazione degli alimenti con prompt per altre AI, pannello Admin, pannello Avvisi con regole per criteri (budget sotto soglia, categoria oltre soglia, budget del giorno, nutrienti sotto obiettivo, evento o turno domani, riepilogo settimanale, personalizzato), notifiche della preghiera (quali, quanti minuti prima, on/off), ore di silenzio, massimo al giorno, registro.
51. App (`NativeHub95.swift`): legge le impostazioni dal server, sincronizza gli obiettivi (vale la modifica più recente), pubblica i target calcolati, programma in locale le notifiche delle regole e della preghiera per i prossimi 2 giorni, invia al sito il registro degli avvisi mostrati. Si aggiorna all'avvio e quando l'app torna attiva.
52. Server: tabelle `web_settings` e `web_alert_log` nel D1 condiviso; metodi `getSettings`, `saveSettings`, `addAlertLog`, `listAlertLog` in entrambi i Worker.

## Correzioni dopo il tour del 23/11/2026 (commit c482496)
53. Chip del mese in Finanza troncato («Nove…»): mese abbreviato, anno solo se diverso.
54. Range calorie: un'unica etichetta centrata «Consigliate X–Y» (app e sito).
55. Agenda: «Giornata» su una riga al posto di «Tutto il giorno» su due.
56. Pillole filtro piatte (la banda grigia sotto le pillole in Movimenti spariva solo togliendo l'ombra).
57. Nuovo movimento: la barra della ripartizione compare solo con un importo.
58. Budget: totale del mese in colore primario; nota demo come piè di sezione (niente divisore a metà).
59. Descrizione di «Fondo senza scadenza» non ripete più il titolo.

## Revisione PDF dell'utente (23/11/2026, REVIEW-95-FEEDBACK-2026-11-23) — commit 381ce82
60. Pillole sottili (Attività, Movimenti, chip mese, Analisi, «Oggi»): causa trovata, `compactControl` era derivato da `Space.section` (passato da 34 a 21). Ora fisso a 34; `actionCircle` fisso a 55. Test `NativeDesignTokensTests` blocca il ritorno dell'errore.
61. Schede 16 pt su tutti i lati (SPACING-SYSTEM-2026-11-23, confermato); 16 pt tra macro e Peso/Alimento nella Dashboard.
62. Calendario: «Oggi» alto come il selettore Mese/Agenda; il tour ora tocca un giorno senza eventi e fotografa l'agenda.
63. Salute: tolta la barra vuota in alto, Cronologia nella riga di «Oggi».
64. Budget: controllo del mese compatto (chip di Finanza).
65. Analisi: titolo, indietro e «Da <mese>» in una riga.
66. Spese per categoria: scelta delle categorie (tutte o alcune), anche sul sito (75f7cc4).
67. Movimenti: ricerca e filtri in un blocco compatto (ricerca 36 pt, pillole 34).
68. Dove va lo stipendio: 4 colori distinti per gruppo (SALARY-MAP-COLORS-2026-11-23, eccezione confermata a FINANCE-PALETTE), un riquadro per gruppo con nome e %, tocco → mappa del gruppo con le voci e il dettaglio.
69. DA FARE: Nuova spesa con ripartizione scelta dall'utente (risparmi −/+, budget per il resto, mesi di budget) come nell'anteprima 93 (FoglioSpesa, FoglioDividi) e FUNDING-BLOCK-2026-11-21. Richiede una modifica al server (routing e calcolo del budget con risparmi parziali); oggi il server accetta una sola destinazione.
70. Ripartizione Nuova spesa (in corso): server `routing.mjs` accetta per una spesa ordinaria `budgetTreatment: recovery` con `recoveryMonths` e `recoveryAmount` (parte dal budget sui mesi scelti, resto sui risparmi), flag `splitDestination`; test 19/19 e verifica del deploy OK in locale. App: `NativeExpenseSplit.swift` (Risparmi −/+, Budget, mesi) e test. Da fare: compilazione, deploy (`lifeos-split-deploy95.yml`, passo di deploy ancora spento), stessa funzione sul sito, screenshot.
71. Ripartizione: server aggiornato su entrambi i Worker (f9155ce, verificato). Online c'era ancora la versione 90 del percorso spese sul sito (la destinazione Risparmi approvata il 16/11 non era mai arrivata): ora sito e app hanno Risparmi e ripartizione. Sito pubblicato a db23013 con la stessa ripartizione.
72. Nuovo movimento senza riga Conto (ACCOUNT-ROW-2026-11-23); legenda della mappa dello stipendio tolta.

## Confronto logico con l'HTML di riferimento (Download/«LifeOS build 93 - Finanza e dati online.html», 37 schermate) — 23/11/2026
Presente nella 95: Panoramica (budget, al giorno, barra con giorno, conto, azioni, ultimi movimenti, mappa stipendio con dettaglio), Analisi (Ritmo, Quanto dura il fondo con −/+, Stima patrimonio, Spese per categoria, Entrate e uscite, Stipendi per competenza, Giorno per giorno), Avvisi (Come arrivano, Quando scattano con −/+, Limiti: al massimo e silenzio; da Impostazioni › Avvisi di Finanza), Dashboard (turno, settimana, prossimo turno, cose da fare, nutrizione, finanza, prossimi appuntamenti), Attività (Completate · Mostra N), Calendario e Agenda, Dipingi turni, Salute e Cronologia, Bloom (catture in sospeso, nuovo giro, luoghi), Movimenti (in attesa di invio, totale del filtro), Budget e piani (obiettivo di risparmio), Nuovo piano, alimenti, obiettivi, peso, eventi, abitudini, orari. Nuova spesa con Risparmi −/+, Budget e mesi (da f9155ce sul server).
Mancano o sono diversi:
73. Bolletta con piano: nel riferimento l'utente sceglie Risparmi (−/+) e i mesi di budget per l'eccedenza oltre al piano; nella 95 l'eccedenza va sui risparmi in automatico.
74. Piano › quote: «Da dove arrivano le quote» (Risparmi / Budget distribuito sui mesi) non c'è.
75. Registra pagamento: nel riferimento la differenza si divide con Risparmi −/+ e mesi; nella 95 c'è solo l'interruttore «Recupera la differenza nei budget futuri».
76. Nuova spesa: il riferimento ha due righe, Categoria (gruppo) e Voce; la 95 ha un solo menu con i 9 gruppi e le voci.
77. Ritmo: «Ultimi 30 / 90 giorni» nel riferimento, «Ultimo mese / Ultimi 3 mesi» nella 95.
78. Impostazioni › Dati sul server: scheda «Trasferimento sul server, una volta sola» e «Fonte dei dati» da verificare nell'app.
79. Fatti (REFERENCE-GAPS-95-2026-11-23, 7e7a5b3; server 95b verificato su entrambi i Worker; sito 20f388b):
   - Nuova spesa: righe Categoria (gruppo) e Voce; sul sito categorie raggruppate per gruppo.
   - Bolletta / spesa con piano: la parte non coperta dal fondo tra «Dagli altri risparmi» (−/+) e mesi di budget.
   - Registra pagamento: la differenza tra risparmi (−/+) e mesi di budget, per ogni tipo di piano (dopo il pagamento, `changeExpenseDestination` con `budgetSplit`).
   - Nuovo piano Obiettivo: «Da dove arrivano le quote», parte dai risparmi; le quote coprono il resto. Per i piani che si ripetono (fisso, fondo) la parte dai risparmi non è disponibile: cambierebbe anche le scadenze future.
   - Ritmo resta «Ultimo mese / Ultimi 3 mesi»: il calcolo è per mesi completi, scrivere 30/90 giorni sarebbe impreciso.

## Conversazione Cowork rivista (23/11/2026, https://claude.ai/share/e27b9431-1f4f-433d-a527-25d58f08f239)
80. Bollette (FUNDING-BLOCK): stessa logica della spesa. Senza piano: Risparmi −/+, il resto sui mesi del periodo di competenza. Con piano: il piano restituisce le quote, dell'eccedenza scegli la parte dai risparmi, il resto sui mesi di competenza. Server: `utilitySavingsCents` su comando o pagamento, la competenza divide solo la parte dal budget (competence.mjs); nessun recupero sopra le bollette (niente doppio conteggio). Deploy verificato (4ec038a) su entrambi i Worker. Nota: online la competenza era ancora la prima versione (solo bollette con piano); ora anche le bollette senza piano pesano sui mesi di competenza.
81. Fogli: X in vetro a sinistra e spunta a destra (titolo al centro) in spesa, piano, pagamento, attività, Bloom, peso, obiettivi, alimento personale.
82. Nuova spesa: importo grande al centro in alto, descrizione sotto.
83. Sito 248d873: bollette nel blocco «Da dove arrivano i soldi» con periodo e parte dai risparmi.
84. Ancora da confrontare con la Cowork: Macro a mano a metà schermo (griglia 2×2 + tastierino), Peso a metà schermo, Spesa a rate con le colonne dei mesi, Cronologia a colonne per macro (giorni/settimane/mesi/trimestri).
85. SUPPLEMENT-STACK-2026-11-23: stack di integratori (nome + dose) registrate con un tocco in Aggiungi alimento; editor nell'app e in Admin sul sito (0137c28); impostazione condivisa «supplement-stacks» (vince la più recente). Siri/Comandi: «Registra la stack», «Ripeti l'ultimo alimento».
86. FOOD-QUICK-ADD-2026-11-23: Alimento apre la ricerca con il campo grammi; il + registra subito con quei grammi (integratori a unità: dose abituale); tocco sul nome = dettaglio; «Inserisci i macro a mano» come link secondario. Diario: «Copia da ieri» e «Ripeti oggi» per voce.

## Revisione del 24/11/2026 (REVIEW-95B, MICRO-BREAKDOWN, SITE-GRAPHICS, ALERTS-CLARITY)
87. Micronutrienti: un tocco su una voce (Micronutrienti fissati, Giorno nella scheda del nutriente) apre «Da quali alimenti» con quantità e quota per alimento. Sito 0c41dce: card «Micronutrienti» sotto il Diario, ogni voce si apre con gli alimenti.
88. Macro a mano: si apre con il tastierino sulle proteine. Ritmo: «1 mese / 3 mesi» (app e sito).
89. Sito, integratori a capsule/compresse: valori mostrati e modificati per 1 unità (omega 3 non più ×100). Dose abituale visibile sul sito, si imposta nell'app (il Worker del sito non scrive la parte app dell'alimento).
90. Avvisi (sito 02ebb81 + app): card «Come arrivano» (solo notifiche iPhone programmate all'apertura dell'app, nessuna sveglia, non superano Concentrazione); scelta per avviso e preghiera «Con suono / Senza suono / Discreta»; 10 modelli pronti; gli avvisi Finanza dell'app sono visibili e modificabili sul sito (copia in `alerts.finance`, vince la più recente); righe con interruttore a destra (prima il testo era centrato lontano dall'interruttore).
91. Da fare: Spesa a rate (proposta visiva), audit contrasto su tutte le schermate, proposta grafica del sito, rivalutazione dei test UI. IPA 95 non ancora (attesa dell'utente).
