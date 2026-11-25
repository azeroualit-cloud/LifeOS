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
92. SITE-GRAPHICS-STYLE-2026-11-24 (sito c95e068): livello grafico v4 su tutto il sito: superfici a 4 gradini, ombre su 3 livelli (schede, hover/menu, fogli), niente aloni; campi incassati con anello di fuoco; mappa dello stipendio con la tavolozza dell'app; barra del telefono con 7 voci su una riga. Corretto: le modifiche a `web/ui.css` vanno incorporate con `web/apply-ui.py` (avvisi, micronutrienti e contrasto non erano arrivati al sito pubblicato).
93. Test (REVIEW-95B 14): tour che ora torna da Avvisi col pulsante indietro; macro 2×2 anche con testo grande; identificativi propri per la ricerca del foglio rapido; bolletta verificata su «Budget mensile»; suite completa `lifeos-full95.yml` in corso.
94. REVIEW-95C (24/11, «ci sono 3 pulsanti tutti diversi e tutti asimmetrici»): in Aggiungi alimento Nuova stack, Macro a mano e Nuovo alimento sono una riga di tre riquadri uguali (stessa altezza 55 pt, stessa superficie, icona sopra l'etichetta); le stack salvate restano come scorciatoie sotto, solo se esistono. Interruttori «acceso» in grigio neutro (in scuro il pallino bianco spariva).
95. REVIEW-95C (24/11, lineetta del giorno «disegnata da python turtle»): nella barra del budget la parte di mese trascorsa è una banda tenue sotto la spesa, con legenda «giorno 24 di 30»; stessa barra sul sito (a4cf27e).
96. REVIEW-95C (24/11, «Tutte le categorie» messo a caso): in Spese per categoria la scelta delle categorie è un controllo compatto a destra del titolo («Tutte ⌄»), il periodo (set – nov) sotto il titolo; sotto restano solo 3/6/12 mesi e le barre.
97. REVIEW-95C (24/11, «Novem-bre» spezzato): i selettori mese/anno dei piani non vanno mai a capo; se la riga è stretta i selettori scendono sotto il titolo (come nella bolletta).
98. Suite completa 95 (24/11, prima esecuzione su 9499419): 493 test passati, 19 falliti. 11 già corretti (tour, alimento rapido, bollette); 4 del Calendario provavano la vecchia vista del giorno (striscia «Tutto il giorno», blocchi annidati) e sono stati riscritti sull'elenco del giorno attuale, uno ritirato; 2 di Finanza con selettori vecchi corretti; 2 legati ai piani e a Registra pagamento saranno riscritti con FINANCE-ENTRY-SIMPLIFY. Seconda esecuzione avviata.
99. CATEGORY-ADMIN (24/11): impostazione «finance-categories» (gruppi, voci, entrate) nei due Worker; Admin sul sito (3325576) con modifica di gruppi e voci, «Carica la proposta» (11 gruppi, tra cui Regali, Persona con Cura personale, Tasse e banca), ricerca delle categorie non attive negli ultimi 3 anni e spostamento dei loro movimenti con classifyMovement; l'app legge l'elenco a ogni aggiornamento (serve questa IPA una volta). ANALYSIS-START-PICKER: mese e anno liberi dentro Ritmo (app e sito).
100. FINANCE-ENTRY-SIMPLIFY, in corso (24/11): Nuovo piano con tre tipi (Anticipo, Fondo, Ricorrente con importo fisso/stimato); Obiettivo e Spesa a rate non si creano più. Da fare: elenco Budget con sezione «Spese a rate» (i 6 piani a rate e le rate dei movimenti, solo vista), Nuova spesa Budget/Risparmi/Piano con «Già registrato», «Paga con Nuova spesa» al posto di Registra pagamento, parità sul sito, confronto dei numeri con la fotografia di nov–feb (scratchpad finance-baseline-2026-11-24.json).
101. FINANCE-ENTRY-SIMPLIFY passo 2–3 (24/11): Budget con sezione «Spese a rate» (i piani a rate e le rate dei movimenti, «rata k di N», stessi importi); Nuova spesa con Budget / Risparmi / Piano e «Già registrata? Collega la spesa esistente»; nel piano «Paga con Nuova spesa» al posto di «Registra un pagamento». Test e tour aggiornati (Obiettivo non si crea più). Seconda suite completa: 503 passati, 7 falliti, corretti. Da fare: sito, confronto numeri.
102. Sito 50631fd: parità di FINANCE-ENTRY-SIMPLIFY (tre tipi di piano, Paga con Nuova spesa, Già registrata?, rate come spese a rate in Budget).
103. REVIEW-95C (24/11): Nuova spesa senza il tasto galleggiante «nascondi tastiera» (copriva il modulo): la tastiera si chiude scorrendo (scelta 1 dell'utente). Aggiungi alimento: riquadri con lo stesso box icona, stessa dimensione del testo e margine interno; «Nuovo alimento» → «Crea nuovo» (il testo lungo veniva rimpicciolito e si spostava).
104. UTILITY-LEVELLING (24/11): quota auto-livellante per i piani Ricorrente stimato. Dopo ogni bolletta (pagamento, eliminazione, correzione del periodo) la quota = media degli ultimi 12 mesi + recupero dello scarto (bollette dei mesi coperti meno quanto il budget ha accantonato per quei mesi), spalmato su almeno 3 mesi o sulla durata tipica della bolletta, poi torna alla media. `backend/utilities/levelling.mjs` (6 test), deploy su entrambi i Worker con `scripts/deploy-levelling-95.py` (385507a, verificato). Si applica dalla prossima bolletta registrata; i numeri attuali non cambiano. Sito d2b64af: nel dettaglio del piano «Quota livellata fino a …, poi … (la media)». App: da aggiungere la stessa riga (build 95). La vista «risparmi liberi / già destinati» è esclusa dall'utente.
105. REVIEW-95D (24/11), sito ecddd67: interruttori come nell'app (una regola generica dei pulsanti li allungava a 36 px e il pomello stava in alto; tinta neutra al posto del verde di sistema); scheda «Orari» e testi neutri (NEUTRAL-TIMES-WORDING, anche nella nota dell'app); calorie: arco anche senza obiettivi, obiettivi letti da `nutrition-targets` pubblicati dall'iPhone (vuoti finché non c'è l'IPA 95), macro in % delle calorie con i colori dell'app; micronutrienti a riquadri con % del fabbisogno (riferimenti LARN dell'app), dal più basso, sodio come limite, tocco = alimenti di provenienza.
106. BILL-PAST-MONTHS (24/11, confermata): le bollette non cambiano più i mesi passati. Server (deploy-bills-95b, Attempt 4, verificato su entrambi i Worker; la versione live era 7c24f3f con le rinomine del bundler): il piano paga quanto accantonato, l'eccedenza va su risparmi e/o sui mesi scelti dal mese corrente (`billBudgetMonths`, predefinito il mese del pagamento lato server, «Prossimi mesi» = 3 mesi nell'app e sul sito); le bollette già registrate tengono le loro quote; quota stimata = media 12 mesi senza recupero, mese corrente allineato al budget. Numeri di nov–feb confrontati con la fotografia del mattino: identici (unica differenza la nuova spesa «Recupero · Qoves»). Acqua: periodo risalvato, novembre 73,93 € (prima 221,79 €), quota 73,93 €. App 3b00473 e sito cea11a7 con la scelta dei mesi. Test UI corretti (importo prima di «Già registrata?», righe «Dagli altri risparmi» per la bolletta con piano, fuoco della tastiera, voci di menu con testo grande).
107. REVIEW-95E (24/11): sito b5fb8fa — calendario ridisegnato (scheda con griglia fine, titoli degli eventi nei giorni, turno come etichetta tinta, oggi nel cerchio blu del calendario, pannello del giorno come scheda che non esce dallo schermo); «Orari del mese» (tabella giorno per giorno); Ramadan ed Eid dal calendario Umm al-Qura con nomi espliciti (CALENDAR-RAMADAN-EID, eccezione confermata); nota privata con punto neutro, riepilogo dietro «Mostra», dati solo nell'impostazione server `private-log` (aggiunta a HUB_KEYS di entrambi i Worker); fibre come quarta barra con l'obiettivo di Admin/app; avvisi della Finanza solo in Avvisi; sezione Guida con quattro schede illustrate. App e8181e6/05eb04a — obiettivo fibre in Obiettivi e barra in Micronutrienti; Calendario degli orari dal foglio Orari; Ramadan/Eid nell'agenda con promemoria alle 20 della sera prima; Privato nel giorno (Face ID per il riepilogo, NSFaceIDUsageDescription); Guida in Impostazioni; tour con le nuove schermate. Nessun dettaglio personale nel repository (pubblico).
108. AGENDA-TIMELINE (24/11, scelta dell'utente «Agenda timeline»): nell'agenda un cerchio per evento (pieno se fatto, vuoto se da fare) e una linea che collega gli eventi con orario dello stesso giorno, nel colore del turno; gli eventi di tutto il giorno senza linea; separatori che non attraversano la linea. App (NativeTimelineMark in CalendarScreen) e sito bc53ff4. Colori tolleranti della nutrizione (NUTRITION-TOLERANT): sito ed9d0e4 e app.
109. Agenda app (25/11, sì dell'utente): «Privato» e le etichette Ramadan/Eid sulla stessa riga del turno, niente spazio vuoto sopra l'elenco; dati demo con due eventi con orario oggi per vedere la linea della timeline nel tour.
110. LIFE-STATS (25/11): Statistiche nell'app (Dashboard, schermata a tutto schermo con periodo 3/6/12 mesi) e sul sito; Privato mostrato nel calendario dell'app come anello neutro sotto il giorno (come il punto del sito); dati demo con nomi neutri per il tour.
111. Sito 96c447d: vista Statistiche (stesse regole dell'app), privato dietro «Mostra»; verificata nel banco di prova con dati di test neutri.
112. INCONTRI-NAME (25/11): «Privato» diventa «Incontri» con icona sparkles nell'app (riga del turno, foglio, Statistiche, Guida) e sul sito c49c56f (verificato nel banco di prova). Singolare/plurale («1 incontro», «1 giorno») e testi senza «nota privata»: sito 53b189f.
113. NAV-E-SLOT (25/11, conferma dell'utente): barra Dashboard · Attività · Calendario · Salute + quinto tab Finanza o Bloom scelto in Admin sul sito (impostazione app-layout, sito 28cf15d); l'app lo legge alla prossima apertura (NativeAppLayout), l'altro si apre dalla scheda in Dashboard. Predefinito Finanza; nei test visivi Bloom salvo «-lifeos.tab.slot finance». Non ancora verificato su iPhone.
114. Gateway dell'app: impostazione app-layout (senza, il quinto tab non arrivava al telefono). FOOD-SYNC-DELTA: listFoodChanges(stamp) con indice su updated_at e tombstone via trigger (vale anche per le cancellazioni dal sito); app con copia locale, controllo ogni 5 minuti o subito se ci sono modifiche da inviare, unione che conserva le modifiche non ancora inviate. Test backend 11/11 in locale.
115. FOOD-DB-RESET (25/11): base curata `native-next/Resources/base-foods.json` da `scripts/build-food-base.py` (304 alimenti, 38 gruppi con varianti Stato/Pelle, id `base-…`, origin «base»). App: elenco una riga per alimento («N varianti»), nel foglio scelte segmentate Stato/Pelle e Pesatura senza/con osso; i cataloghi di marca/OFF non sono più nell'elenco. Server: `scripts/reset-food-base-95.py` (backup `web_foods_backup_20261125`, tiene gli integratori, importa la base) pronto ma NON ancora eseguito: il workflow è in `scripts/lifeos-food-reset95.yml.pending` finché l'utente non sceglie quando (con l'app vecchia la base comparirebbe tra i Personali). Sito con varianti: da fare.
116. TRANSCRIBE-SITE (25/11): sito, sezione Trascrivi (whisper-base/small via transformers.js 3.0.2 in un Web Worker, WebGPU se c'è). Provata nel banco di prova con un audio sintetico italiano: trascrizione corretta salvo «trascriptore»/«LiveOS» con il modello veloce. Incorporato anche il CSS della scheda Barra dell'iPhone in Admin, che mancava. Non verificato sul sito pubblicato (eventuali blocchi CSP del Worker).
