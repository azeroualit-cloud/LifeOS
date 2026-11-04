# Inventario delle richieste e delle proposte — 4 novembre 2026

Fonti: questa conversazione, le chat precedenti pertinenti recuperate e i documenti di passaggio/revisione. Le immagini mancanti nelle chat storiche non sono state ricostruite a fantasia. Non certifico l’esaustività rispetto a chat non recuperate o ad allegati non disponibili. Questo elenco non attesta che le correzioni siano già implementate o funzionanti.

U = tua richiesta in questa chat; S = tua richiesta in una chat precedente; H = richiesta ricostruita nell’handoff; D = contratto riportato nei documenti del progetto; P = mia proposta. Le proposte approvate per il mockup non sono automaticamente requisiti approvati per il codice.

🔴 = voce in conflitto o tensione: vedere spiegazione e precedenza.



## Direzione del prodotto e stile



1. **A01** [U] Rendere l’app realmente utilizzabile e sufficientemente curata per la produzione, non soltanto compilabile.

2. **A02** [S5] Ridurre il carico di lettura e permettere di capire i segnali importanti a colpo d’occhio.

3. 🔴 **A03** [S5] Rappresentare evento e abitudini con rettangoli di stato senza testo, colorati quando completati. — K07

4. **A04** [S5] Usare esattamente due barre orizzontali al posto dei grafici a mezza torta.

5. **A05** [S5] Nella barra del turno evidenziare soltanto la fascia oraria del turno attuale, per esempio 06–14.

6. **A06** [S5] Usare transizioni nette nel gradiente del componente indicato, senza sostituirlo con un’immagine decorativa.

7. 🔴 **A07** [S1] Ridurre il blu e rendere più caldi i fondi e l’accento dell’icona. — K01

8. 🔴 **A08** [S1] Sostituire il vecchio logo con la A, rifiutato esplicitamente. — K03

9. 🔴 **A09** [H] Conservare l’icona originale successivamente scelta e rifiutare altre varianti non richieste. — K03

10. 🔴 **A10** [S2] Eliminare l’eccesso di colori, gradienti e glow dei concept iniziali. — K02

11. 🔴 **A11** [S4] Concept storico con dark mode, SF Pro Rounded, vetro, microgradienti e accenti mint/indaco/arancio. — K01, K02

12. 🔴 **A12** [S3] Concept storico light/neo-brutalista, vibrante e con aspetto clay/3D; successivamente esplorato anche dark e minimale. — K02

13. **A13** [S6] Calendario semplice, moderno, utilizzabile, con testi leggibili e senza illustrazioni complesse.

14. **A14** [S1] Far corrispondere il redesign al riferimento fornito, evitando un’estetica percepita come app da caffetteria.

15. **A15** [H] Usare controlli e materiali di sistema quando appropriati, con fallback disponibili e senza inventare API.

16. **A16** [U] Verificare margini, padding e bottoni per proporzioni ed esperienza iOS migliorate.



## Navigazione



17. 🔴 **B01** [D] Struttura storica: Dashboard, Attività, Salute, Altro, con Finanza/Calendario/Bloom in Altro. — K05

18. 🔴 **B02** [H] Sostituire Altro con Bloom direttamente nella tab bar. — K05

19. **B03** [H] Conservare quattro destinazioni principali: Dashboard, Attività, Salute, Bloom.

20. **B04** [H] Separare chiaramente i flussi Calendario, Attività, Salute e Finanza; la frase non conferma una diversa tab bar.

21. **B05** [H] La settimana della Dashboard deve aprire il calendario completo.

22. **B06** [H] Il tocco sulla settimana non deve forzare l’apertura della scheda giornaliera.

23. **B07** [H] Conservare il giorno richiesto come riferimento del calendario quando appropriato.

24. **B08** [H] Tornare alla Dashboard senza stack duplicati o perdita della posizione.

25. **B09** [H] Aprire Salute direttamente sui contenuti, eliminando la porta d’ingresso Peso, calorie, fonti e TDEE.

26. **B10** [H] Conservare deep link, azioni rapide, ritorni e ripristino dello stato.



## Dashboard



27. 🔴 **C01** [U] Mostrare soltanto HH:mm della prossima preghiera a destra della data, anche quando è del giorno dopo. — K09

28. **C02** [U] Aprire tutti gli orari delle preghiere toccando quell’ora.

29. 🔴 **C03** [H] Header storico con data, ora corrente e prossima preghiera compatti. — K09

30. **C04** [U] Ridurre il padding e l’ingombro dei tasti Impostazioni e +.

31. **C05** [U] Mostrare prima gli eventi di oggi.

32. **C06** [U] Mostrare subito dopo le abitudini di oggi.

33. 🔴 **C07** [U] Mostrare poi soltanto gli eventi a meno di tre giorni, senza estendere la lista a tutta la settimana. — K06

34. 🔴 **C08** [U] Escludere dalla Dashboard le attività generiche e tutto ciò che non rientra nella finestra richiesta. — K06

35. 🔴 **C09** [S2] Concept storico: eventi settimanali seguiti da attività non urgenti, massimo tre righe. — K06

36. 🔴 **C10** [H] Unire la presentazione delle cose da fare evitando molti contenitori e raggruppamenti. — K08

37. **C11** [H] Conservare identità, tipo e azioni dei record senza duplicarli nella presentazione unificata.

38. **C12** [H] Rendere chiaramente toccabile la settimana con contenitore discreto e feedback di pressione.

39. **C13** [H] Conservare turni, colori, indicatori e accessibilità della settimana.

40. **C14** [D] Tenere i giorni passati della settimana all’80% di opacità e quelli futuri pienamente visibili anche oltre il mese.

41. 🔴 **C15** [U] Nel blocco Finanza mostrare soltanto titolo, icona e freccia nell’intestazione. — K11

42. **C16** [U] Sotto l’intestazione mostrare il numero del budget con Budget sotto.

43. **C17** [U] Affiancare Aggiungi spesa sulla destra del budget, facilmente raggiungibile con il dito.

44. 🔴 **C18** [S2] Concept storico: widget finanziario con arco del saldo e registrazione rapida delle spese. — K11

45. 🔴 **C19** [H] Togliere il grafico peso dalla Dashboard e trasferirlo in Salute. — K10

46. 🔴 **C20** [D] Contratto storico: scheda peso/calorie e relativo grafico nella Dashboard. — K10

47. 🔴 **C21** [U] Integrare nella Dashboard un inserimento nutrizionale rapido e compatto. — K12

48. **C22** [H] Rendere raggiungibile la cronologia senza espanderla interamente nella home.



## Attività, calendario e turni



49. **D01** [H] Conservare un unico editor per attività ed eventi.

50. 🔴 **D02** [D] L’editor unificato non deve introdurre priorità. — K22

51. 🔴 **D03** [S3] Concept iniziale di task manager con priorità. — K22

52. **D04** [D] Separare il tocco sul titolo, che apre la scheda, dal completamento diretto in lista.

53. **D05** [D] Aprire l’editor come scheda nativa dal basso.

54. **D06** [D] Affiancare data di inizio e scadenza, con orari sotto e categoria/luogo successivi.

55. **D07** [D] Aprire il selettore data al primo tocco e permettere di rimuovere la data con ×.

56. **D08** [D] Il calendario del selettore data deve avere larghezza sufficiente, senza colonne tagliate.

57. **D09** [D] Conservare descrizione, metadati, stato In attesa, completamento, eliminazione e ricorrenze.

58. **D10** [D] Salvare subito localmente e sincronizzare in background senza duplicare operazioni.

59. **D11** [D] Consentire mesi continui e scorrevoli con comandi e intestazioni stabili.

60. 🔴 **D12** [D] Soluzione storica con riquadro giorno fisso sotto il mese. — K20

61. 🔴 **D13** [D] Soluzione successiva con mese a tutta altezza e apertura della giornata. — K20

62. 🔴 **D14** [D] Ultimo contratto documentato: agenda integrata sotto il mese, con chiusura ed espansione esplicite. — K20

63. **D15** [D] Distinguere ritorno a oggi e apertura esplicita del giorno richiesto.

64. **D16** [D] Conservare il mese consultato durante i ridimensionamenti e gli editor, evitando salti indesiderati.

65. **D17** [D] Nella giornata usare una sola intestazione con ritorno, data e +, senza secondo titolo o ingranaggio.

66. **D18** [D] Mostrare tutti e sette i turni della settimana nella vista del giorno.

67. 🔴 **D19** [D] Contratto precedente: griglia oraria proporzionale a minuto e durata. — K19

68. 🔴 **D20** [D] Contratto successivo: agenda compatta senza altezze proporzionali alle ore. — K19

69. **D21** [D] Mostrare eventi contenuti, sovrapposizioni parziali e intervalli identici senza nascondere attività.

70. **D22** [D] Non inventare un’ora finale quando manca; conservare notturni e prosecuzioni da ieri.

71. **D23** [D] Mostrare tutto il giorno in una riga di pillole scorrevole orizzontalmente, senza pannello separato fisso.

72. **D24** [D] Riservare lo swipe di cambio giorno alla settimana per non interferire con le pillole.

73. 🔴 **D25** [D] Numeri del calendario inizialmente semibold. — K21

74. 🔴 **D26** [D] Numeri poi definiti SF Pro Regular 20 pt, scalabili, con selezione blu di sistema. — K21

75. **D27** [D] Eliminare il cerchio grande che si sovrappone al badge del turno.

76. **D28** [D] Usare puntini nel colore del turno, oppure neutri quando il turno manca.

77. **D29** [D] Allineare abbreviazioni dei mesi e separatori alle sette colonne, con evidenza del mese corrente.

78. **D30** [D] Palette Dipingi compatta, orizzontale e ispirata a Supershift, con Liquid Glass nativo dove disponibile.

79. **D31** [D] Conservare la coda locale dei turni e non ricostruire inutilmente tutti gli eventi a ogni pennellata.

80. **D32** [D] Barra del turno attivo nel colore del turno, segmenti di due ore e segmento finale parziale.

81. **D33** [D] Microanimazione una sola volta dell’ultimo segmento completato, rispettando Riduci movimento.

82. **D34** [D] Non mostrare una barra grigia vuota negli stati senza turno attivo.

83. **D35** [D] Colori delle categorie deterministici e identità cromatica stabile fra calendario e Attività.

84. **D36** [D] Sveglie urgenti locali autorizzate: identità stabile, modifica, cancellazione e recupero degli errori.

85. **D37** [D] Non interpretare un mese non caricato come evento eliminato né sincronizzare falsamente le sveglie locali.



## Finanza e bollette



86. **E01** [H] Risolvere il blocco Conferma nell’editor bolletta distinguendo rete e server non compatibile.

87. **E02** [H] Non aggirare il controllo di compatibilità del periodo delle bollette.

88. **E03** [H] Conservare i dati inseriti durante errori e retry.

89. **E04** [H] 221,79 € da agosto a ottobre 2026 devono produrre tre quote da 73,93 €, anche per mesi passati.

90. **E05** [H] Il periodo esplicito prevale sul titolo descrittivo della bolletta.

91. **E06** [H] Il pagamento resta un solo movimento con data e importo effettivi.

92. **E07** [H] Evitare doppi conteggi fra accantonamenti, fondo, costo per competenza e pagamento.

93. **E08** [H] Mantenere le stime nei mesi senza documento e sostituirle con le quote effettive all’arrivo della bolletta.

94. **E09** [H] Conservare l’identità del pagamento durante modifica e retry e gestire centesimi, cambio anno e interruzioni.

95. **E10** [H] Diagnosticare un saldo personale negativo sui dati effettivi senza attribuirgli una causa provata solo su esempi sintetici.

96. **E11** [D] Pagina Finanza aperta, con importi a sinistra, saldo del conto a destra, Budget/Analisi e movimenti con icona.

97. 🔴 **E12** [D] Usare simboli semplici monocromatici bianchi per le icone Finanza. — K23

98. **E13** [D] Ordinare i movimenti per inserimento effettivo senza mostrare l’ora e senza inventare timestamp storici.

99. **E14** [D] Importo principale Finanza 40 pt semibold, rimuovendo i divisori superflui ma conservando quelli fra transazioni.

100. **E15** [S2] Concept storico della pagina Finanza con budget mensile, saldo, disponibilità giornaliera, heatmap, giorni rimanenti e spese straordinarie.

101. **E16** [S1] Rappresentare le uscite effettive di categoria ignota come spese da classificare, invece di ignorarle.

102. **E17** [S1] Correggere la chiamata che passa un argomento a una funzione dichiarata senza argomenti nel Worker.

103. **E18** [S1] Correggere il tipo/contratto finanziario che non espone carCommitments, senza perdere gli impegni auto.

104. **E19** [S1] Correggere il tipo/contratto finanziario che non espone otherCommitments.

105. **E20** [S1] Correggere il tipo/contratto finanziario che non espone advanceOffset.

106. **E21** [S1] Correggere il tipo/contratto finanziario che non espone extraCommitments.

107. **E22** [S1] Correggere il tipo/contratto finanziario che non espone net.

108. **E23** [S1] Correggere i contratti che rifiutano la proprietà estimated nei record previsti.

109. **E24** [S1] Correggere le chiamate che passano Date a parametri numerici, preservando la semantica delle date.

110. **E25** [H] Non creare addebiti o movimenti bancari reali come prova durante la correzione delle bollette.



## Nutrizione



111. 🔴 **F01** [H] Vecchio modulo di pochi dati: tre macro più data e ora, con calorie derivate. — K13, K14, K15

112. 🔴 **F02** [U] Aggiungere il campo fibre. — K13

113. **F03** [U] Inserire i nutrienti come valori per 100 g.

114. **F04** [U] Scegliere sotto i grammi effettivamente consumati.

115. 🔴 **F05** [U] Inserire anche le kcal dell’etichetta per 100 g, come da tua risposta esplicita. — K14

116. **F06** [U] Scalare nutrienti, fibre e kcal sulla porzione effettiva.

117. 🔴 **F07** [U] Esporre soltanto la data, senza campo ora. — K15

118. 🔴 **F08** [H] Calcolo storico immediato P×4+C×4+G×9 con Decimal. — K14

119. **F09** [H] Accettare virgola e punto decimale, trattare vuoto come zero e rifiutare input invalidi o negativi.

120. **F10** [H] Gestire Avanti/Fine fra i campi senza spostare il focus dopo la prima cifra né usare timer arbitrari.

121. **F11** [H] Conservare gli input dopo un errore ed evitare il doppio invio.

122. **F12** [H] Rendere raggiungibili cronologia e modifica delle registrazioni.

123. **F13** [H] Aggiungere eliminazione delle registrazioni create da LifeOS.

124. **F14** [H] Eliminare anche i campioni LifeOS corrispondenti in Apple Salute, lasciando intatti quelli di altre app.

125. **F15** [H] Conservare stato, identità e retry di modifica/eliminazione dopo errori e riavvii.

126. **F16** [H] Non mostrare successo prima della conferma e non presumere una transazione unica fra archivio locale e HealthKit.

127. **F17** [H] Condividere lo stesso archivio fra Dashboard e Salute, evitando due writer incoerenti.

128. **F18** [H] Il vecchio esempio P0/C0,2/G0 = 0,8 kcal deve poter essere eliminato dall’utente, senza cancellazioni automatiche durante sviluppo.



## Salute



129. **G01** [U] Togliere i pulsanti Collega/Gestisci Apple Salute dalla pagina.

130. 🔴 **G02** [U] Togliere la sezione di selezione della fonte calorie. — K16

131. 🔴 **G03** [U] Contare tutte le registrazioni caloriche di tutte le app presenti in Apple Salute. — K16

132. 🔴 **G04** [H] Contratto precedente con gestione fonti e precauzione contro la somma automatica dei duplicati. — K16

133. **G05** [U] Aggiunta peso e registrazione macro come due azioni grafiche senza testo.

134. **G06** [U] Usare omino per peso e mela per nutrizione.

135. **G07** [U] Applicare Liquid Glass alle due azioni e collocarle sopra la barra inferiore.

136. 🔴 **G08** [U] Applicare lo stile della dashboard Apple Salute alle quattro schede. — K04

137. **G09** [U] Dare alle quattro righe la stessa altezza.

138. **G10** [U] Usare icona e titolo piccoli e colorati in alto a sinistra.

139. 🔴 **G11** [U] Usare valore grande e bianco in basso a sinistra, con unità piccola e grigia adiacente. — K17

140. 🔴 **G12** [U] Collocare il mini grafico sulla destra, grigio con l’ultima parte colorata. — K18

141. **G13** [U] Applicare questo trattamento a TDEE, Peso, Calorie e Simulazione.

142. **G14** [U] Usare la skill REA da GitHub per analizzare il riferimento reale Apple Salute.

143. 🔴 **G15** [D] Contratti cromatici precedenti con valori peso grigi e poi valori/arancione Salute. — K17

144. **G16** [D] Calibrare TDEE sullo storico coerente e usare la stessa stima per le proiezioni, senza ancorare tutto alla pesata parziale di oggi.

145. **G17** [H] Conservare selezione dei grafici, scorrimento e aggiunta/modifica del peso.



## Bloom e conservazione dei contenuti



146. **H01** [U] Ridurre dimensioni e padding eccessivi dei pulsanti Bloom.

147. **H02** [U] Correggere selezione del backup in File che si chiude senza procedere.

148. **H03** [U] Rendere trasferibili e visibili in LifeOS i contenuti locali conservati nell’app Bloom originale.

149. **H04** [H] Usare il backup esportato dall’app originale come fonte del trasferimento, senza supporre che lo ZIP dei sorgenti contenga il database personale.

150. **H05** [H] Conservare note, raccolte, immagini, allegati, archiviati e cestino senza perdere gli originali.

151. **H06** [D] Mostrare anteprima dell’importazione e risolvere i conflitti esplicitamente con mantieni/sostituisci/copia.

152. **H07** [D] Evitare duplicazioni in reimportazione tramite identificativi e rimappamenti persistenti.

153. **H08** [D] Verificare allegati e archivio e conservare una copia di sicurezza prima della scrittura.

154. **H09** [D] Conservare un rapporto dell’importazione e renderlo consultabile.

155. **H10** [H] Mantenere Libreria, Mappa e Riscopri già integrati.

156. **H11** [H] Non introdurre una nuova sincronizzazione PKMS/Dropbox né un secondo lifecycle dell’app Bloom.

157. **H12** [D] Conservare ricerca, categorie multiple, fissati, selezione multipla e gestione raccolte.

158. **H13** [D] Conservare testo, link, foto, file, Markdown con tabelle/codice e anteprime degli originali.

159. **H14** [D] Mantenere ritagli non distruttivi, miniature e pager dei contenuti multipli.

160. **H15** [D] Conservare mappa, cluster, luoghi collegati e camera passando fra sezioni, senza obbligo di posizione corrente.

161. **H16** [D] Mantenere Riscopri sullo stesso archivio con giro e filtri persistenti.

162. **H17** [D] Conservare cattura tramite Intent/link e coda locale recuperabile, evitando writer concorrenti.

163. **H18** [D] Nessuna pulizia automatica del cestino e nessuna eliminazione di allegati ancora condivisi da altre note.



## Ulteriori proposte emerse nella conversazione



164. **I01** [P] Correggere la griglia Bloom: due colonne rigorose, nessuna card oltre la colonna e nessuna sovrapposizione.

165. **I02** [P] Gestire le diverse altezze delle card senza grandi vuoti inutili o collisioni.

166. **I03** [P] Uniformare ritaglio, proporzioni e rapporto fra miniatura e titolo.

167. **I04** [P] Aprire a tutto schermo le immagini contenenti testo, con zoom e proporzioni conservate.

168. **I05** [P] Distinguere immagine, link, video e nota con tipo e provenienza leggibili.

169. **I06** [P] Sostituire gli URL grezzi nelle card con titolo comprensibile e dominio.

170. **I07** [P] Ridurre gli strati di controlli sopra i contenuti Bloom e unire filtro/selezione/raccolte in una riga.

171. **I08** [P] Mostrare l’esito dell’importazione come conferma temporanea, lasciando il rapporto consultabile.

172. **I09** [P] Dare contesto al pulsante cartella e alle sue azioni.

173. **I10** [P] Rendere più discreto lo stato selezionato Libreria, evitando una grande pillola bianca dominante.

174. **I11** [P] Valutare una cattura Bloom più vicina al pollice, senza duplicare inutilmente il +.

175. **I12** [P] Rendere chiaramente modificabili i campi nutrizionali, con contorno o fondo distinto.

176. **I13** [P] Aumentare la leggibilità di placeholder, zeri e unità, evitando la lettura ambigua g0.

177. **I14** [P] Compattare il modulo nutrizione e rendere chiaro il percorso etichetta → porzione → totale → aggiunta.

178. **I15** [P] Mostrare un riepilogo effettivo prima del salvataggio, per esempio 20 g e 90 kcal.

179. **I16** [P] Non mostrare Controlla i valori come errore prima che l’utente inizi a scrivere.

180. 🔴 **I17** [P] Sostituire il modulo in Dashboard con una sola scorciatoia Registra un pasto e aprire una pagina dedicata. — K12

181. **I18** [P] Aggiungere Recenti e Preferiti per riutilizzare alimenti o registrazioni.

182. 🔴 **I19** [P] Chiarire l’assenza di calorie odierne senza trasformarla in zero né colorare lo storico come fosse oggi. — K18

183. **I20** [P] Scrivere Tra 8 settimane e Peso stimato per contestualizzare la simulazione.

184. **I21** [P] Mostrare ipotesi e limiti della proiezione e un’indicazione dell’incertezza nel dettaglio.

185. **I22** [P] Rendere leggibili i mini grafici riducendo densità e aumentando riconoscibilità dell’ultimo punto.

186. **I23** [P] Ridurre lo spazio eccessivo fra data e calendario nella Dashboard.

187. **I24** [P] Rendere più informative scadenze e orari e meno ripetitivi i sottotitoli Evento/Abitudine.

188. **I25** [P] Sostituire Gestisci con un’azione che chiarisca la destinazione.

189. **I26** [P] Distinguere visivamente completamento e apertura della riga, con affordance coerenti.

190. **I27** [P] Mostrare al tocco il nome completo del turno e i suoi orari, distinguendo oggi dal giorno selezionato.

191. 🔴 **I28** [P] Rendere esplicito il periodo del budget, se coerente con il calcolo sottostante. — K11

192. **I29** [P] Garantire che ogni ultimo contenuto possa scorrere completamente sopra tab bar e azioni flottanti.

193. **I30** [P] Ridurre il disordine visivo dei contenuti intravisti sotto il materiale della tab bar.

194. 🔴 **I31** [P] Far aiutare la Dashboard a scegliere la prossima azione e distinguere ciò che può aspettare. — K06, K08, K22

195. **I32** [P] Collegare scadenza, pagamento e budget per Affitto e materiali/contatti/prossimo passo per una riparazione.

196. **I33** [P] Catturare rapidamente note, spese e link con organizzazione completabile in seguito.

197. **I34** [P] Far riemergere in Bloom i contenuti utili per attività o progetti, oltre alla semplice archiviazione.

198. **I35** [P] Gestire avanzamento e prossimo passo delle attività senza ridurre tutto a completato/non completato.

199. **I36** [P] Spiegare gli andamenti Salute, il periodo e la sufficienza dei dati, consentendo di risalire alle registrazioni.

200. 🔴 **I37** [P] Aggiungere una revisione breve della giornata e della settimana. — K08

201. **I38** [P] Rendere comprensibile se un contenuto è locale, sincronizzato oppure incluso in un backup, senza inventare sincronizzazioni.

202. **I39** [P] Uniformare superfici e raggi dei componenti equivalenti senza cancellare il significato delle differenze.

203. 🔴 **I40** [P] Usare una gerarchia più netta fra attenzione, riepiloghi e strumenti di inserimento. — K07

204. 🔴 **I41** [P] Ridurre contenitori annidati e riservare le card ai gruppi che ne hanno bisogno. — K04

205. 🔴 **I42** [P] Assegnare accenti riconoscibili alle aree, incluso blu Bloom e arancio Finanza nel concept recente. — K01, K23

206. **I43** [P] Rifinire interlinea, troncamento dei titoli/URL, allineamento cifre-unità e formati numerici.

207. **I44** [P] Uniformare peso e dimensione ottica delle icone.

208. **I45** [P] Progettare stati vuoti, primo utilizzo e ricerca senza risultati con una sola azione chiara.

209. **I46** [P] Usare feedback brevi e coerenti per completamento, aggiunta, cambio sezione e annullamento.

210. **I47** [P] Verificare tastiera, ritorno alla posizione di scorrimento, uso a una mano e possibilità di annullare.

211. 🔴 **I48** [P] Dare a LifeOS una direzione grafica più autonoma e riconoscibile rispetto alla sola somiglianza iOS. — K04



## Qualità, consegna e metodo di lavoro



212. 🔴 **L01** [U] Ricostruire tutte le correzioni di questa conversazione e delle precedenti, una per una, segnalando in rosso i conflitti. — K24

213. 🔴 **L02** [U] Non limitare il lavoro al solo difetto della griglia Bloom. — K24

214. 🔴 **L03** [P] Proposta precedente di iniziare soltanto dalla griglia Bloom, rifiutata nella tua ultima risposta. — K24

215. **L04** [U] Ridurre cicli lunghi di lavoro che terminano con una versione ancora piena di difetti visibili.

216. **L05** [U] Non scaricare sull’utente il collaudo iniziale né costringerlo a ripetere continuamente le stesse correzioni.

217. **L06** [U] Intervenire sull’app installabile effettiva: un mockup non risolve i difetti della build.

218. **L07** [U] La richiesta di rappresentare tutte le migliorie in una sola immagine riguarda il concept, non prova l’implementazione.

219. **L08** [U] Operare autonomamente entro il progetto senza impattare risorse esterne al progetto.

220. **L09** [H] Conservare dati, bundle ID, App Group, compatibilità di avvio e aggiornamento sopra l’app esistente.

221. **L10** [H] Consegnare un’IPA diretta per Signulous, non uno ZIP.

222. **L11** [H] Non disinstallare l’app, svuotare il Portachiavi o cancellare dati per far passare i controlli.

223. **L12** [H] Non riproporre la stessa richiesta di versione iOS o crash report già forniti.

224. **L13** [H] Distinguere prove simulate, demo e prove fisiche e dichiarare soltanto ciò che è effettivamente verificato.

225. **L14** [H] Non pubblicare dati personali, credenziali o diagnostica finanziaria privata nei log.

226. **L15** [D] Widget piccolo 2×2 con settimana, riepiloghi e +, senza esportare saldo, dati Salute o credenziali.

227. **L16** [D] Widget offline con cache atomica e data reale dell’ultimo aggiornamento, senza fingere freschezza.

228. **L17** [P] Mantenere un registro persistente dei difetti con prove e controllo delle regressioni.

229. **L18** [P] Usare casi rappresentativi: librerie popolate, immagini diverse, titoli lunghi, dati mancanti, tastiera e testo grande.

230. **L19** [P] Controllare il risultato renderizzato dell’app reale oltre agli assert automatici.

231. **L20** [P] Eseguire prima verifiche pertinenti e produrre l’IPA dopo la verifica del gruppo di correzioni.

232. **L21** [H] Eliminare il crash immediato di avvio osservato nella build 75, senza attribuirlo automaticamente al certificato.

233. **L22** [D] Conservare il controllo di compatibilità degli import Foundation Date su app e widget e la toolchain compatibile documentata.

234. **L23** [H] Verificare che aggiornamento e riavvio conservino sessione, archivi e dati già salvati.



## Richieste storiche con riferimento incompleto



235. **M01** [S1] Correggere il primo allegato storico indicato con fixalo: dettaglio non ricostruibile dal solo testo disponibile.

236. **M02** [S1] Correggere il secondo allegato storico, definito troppo piccolo e problematico: riferimento visivo oggi mancante.

237. **M03** [S1] Ridurre i troppi colori del terzo allegato storico, conservando la struttura delle carte gradita.

238. **M04** [S1] Aggiungere un accento al quarto allegato storico, definito troppo spento.



## Conflitti e precedenze



- **🔴 K01 — Palette fredda/blu contro palette calda e meno blu.** S1 chiede esplicitamente fondi più caldi e meno blu. I vecchi concept indaco/neon e la mia recente proposta blu/fredda non vanno applicati contemporaneamente come palette dominante. La direzione recente proposta da me non sostituisce la tua preferenza.

- **🔴 K02 — Molti gradienti, glow e colori contro minimalismo.** I primi prompt esplorano neon, microgradienti e clay/3D; S2 li rifiuta poi esplicitamente. Conservare gli accenti semantici non significa reintrodurre effetti decorativi diffusi. Richiesta precedente superata.

- **🔴 K03 — Cambiare icona contro conservare l’icona attuale.** S1 rifiuta il vecchio logo con A; il successivo handoff chiede di conservare l’icona scelta nel frattempo. Non è un divieto retroattivo della modifica originaria: oggi riapplicare il vecchio redesign contraddirebbe il vincolo successivo.

- **🔴 K04 — Conformità Apple esatta contro nuova identità visiva autonoma.** La richiesta esplicita per le quattro schede Salute è di seguire esattamente lo stile Apple. Le mie proposte di nuova identità, nuove forme e minori contenitori sono applicabili altrove; se cambiano quelle schede entrano in conflitto. Non è un’autorizzazione a ridisegnare Salute liberamente.

- **🔴 K05 — Quattro tab con Altro contro quattro tab con Bloom.** La richiesta successiva sostituisce Altro con Bloom. Dashboard, Attività, Salute, Bloom è l’istruzione esplicita più recente. Calendario/Attività/Salute/Finanza nel documento è una divisione dei flussi, non una tab bar alternativa confermata.

- **🔴 K06 — Attività generiche e settimana intera contro finestra breve della dashboard.** I concept precedenti comprendono eventi settimanali e fino a tre attività non urgenti; il successivo messaggio esclude le attività generiche e richiede eventi di oggi, abitudini di oggi, poi eventi entro meno di tre giorni. Prevale quest’ultimo.

- **🔴 K07 — Segnali senza testo contro elenco descrittivo nella home.** S5 chiede rettangoli senza testo per capire tutto a colpo d’occhio. Le successive richieste e le mie proposte introducono titoli, sottotitoli e contesto. Possono convivere in componenti distinti; non sostituirsi nello stesso componente senza decidere quale presentazione usare.

- **🔴 K08 — Una lista compatta contro ulteriori gruppi e sezioni nella dashboard.** L’handoff chiede meno raggruppamenti. Le mie proposte Da fare oggi/In arrivo, riepilogo intelligente e revisione aggiungono gruppi. È una tensione di organizzazione e densità, non un difetto automaticamente risolto da un nuovo mockup.

- **🔴 K09 — Data e ora corrente contro data e sola ora della preghiera.** Il vecchio header comprende data/ora e prossima preghiera. La richiesta successiva vuole solo l’ora della preghiera a destra della data, senza riga autonoma né prefisso Domani. Prevale la richiesta successiva.

- **🔴 K10 — Grafico peso in Dashboard contro trasferimento in Salute.** I vecchi contratti prevedono peso e calorie nella home. L’handoff ne chiede la rimozione e il trasferimento in Salute. Non reintrodurre il grafico nella home per ripristinare un concept passato.

- **🔴 K11 — Widget Finanza con arco e più indicatori contro solo Budget e aggiunta spesa.** I primi concept e l’handoff propongono riepiloghi più ricchi. La richiesta successiva limita il blocco a intestazione, numero, Budget e azione sulla destra. Il cambio di etichetta proposto da me è distinto dalla logica del calcolo.

- **🔴 K12 — Modulo macro nella Dashboard contro sola scorciatoia e pagina separata.** L’inserimento compatto direttamente nella home è richiesto dall’utente. La mia proposta di sostituirlo con Registra un pasto e aprire una pagina separata cambia il flusso: è una proposta in conflitto, non una correzione già approvata.

- **🔴 K13 — Tre macro e pochi campi contro fibre, kcal etichetta e porzione.** Il vecchio modulo di cinque dati viene esteso dalla richiesta successiva. Non si possono eliminare i nuovi campi solo per rispettare il vecchio numero di campi. La compattezza va ottenuta con il layout.

- **🔴 K14 — Calorie sempre 4/4/9 contro kcal dichiarate in etichetta.** Hai scelto esplicitamente le kcal dell’etichetta per 100 g. I vecchi record possono mantenere il calcolo storico, ma i nuovi pasti non devono essere ricalcolati ignorando l’etichetta. Evoluzione risolta dalla tua risposta successiva.

- **🔴 K15 — Data e ora modificabili contro sola data.** L’handoff prevede entrambe; la tua richiesta successiva dice che l’ora non interessa. Il nuovo modulo deve esporre solo la data.

- **🔴 K16 — Selettore/deduplicazione delle fonti contro somma di tutte le registrazioni.** L’handoff conserva le fonti evitando somme automatiche di duplicati; la tua richiesta successiva impone di contare tutte le entry caloriche e togliere il selettore. Prevale l’istruzione successiva, senza cancellare dati delle altre app.

- **🔴 K17 — Numero Salute grigio/arancione contro valore bianco e titolo colorato.** I documenti 70/71 descrivono colori precedenti diversi. Il successivo contratto richiede numero grande bianco, unità grigia, icona/titolo colorati. I contratti visivi precedenti sono superati per queste quattro schede.

- **🔴 K18 — Ultima parte del grafico sempre colorata contro assenza di calorie odierne.** La tua richiesta dice ultima parte colorata; io propongo una deroga: se oggi manca un dato, lo storico resta grigio per evitare di farlo sembrare odierno. È un’eccezione proposta che va resa esplicita, non una tua richiesta originaria.

- **🔴 K19 — Agenda con altezza proporzionale alle ore contro righe compatte.** Il contratto 71 descrive una griglia oraria; il 72 passa a un’agenda non proporzionale. È un’evoluzione documentata: non implementare entrambi i modelli come se fossero la stessa vista.

- **🔴 K20 — Dettaglio giorno fisso contro mese pieno e agenda integrata.** 70: riquadro inferiore fisso; 71: mese pieno e dettaglio; 73: agenda integrata con espansione esplicita. Conservare la successione delle decisioni, privilegiando l’ultima documentata finché non contraddetta da una tua istruzione diretta.

- **🔴 K21 — Numeri calendario semibold contro Regular.** 71 richiede numeri semibold; 72 li riporta a SF Pro Regular 20 pt scalabili. Il secondo è il contratto documentato successivo.

- **🔴 K22 — Interfaccia senza priorità contro priorità nuove.** Un primo concept cita priorità; il contratto dell’editor unificato le esclude. Le mie proposte di evidenziare priorità non autorizzano ad aggiungere automaticamente un campo o algoritmo di priorità.

- **🔴 K23 — Icone Finanza bianche contro nuove icone colorate.** Il contratto 70/71 specifica simboli monocromatici bianchi. Nel mio concept recente l’icona finanziaria è arancione: quel cambio confligge se applicato alle stesse icone. Il colore di un titolo o di un indicatore è un caso diverso.

- **🔴 K24 — Partire soltanto da Bloom contro ricostruire tutte le correzioni.** La mia proposta di cominciare con un solo difetto non risponde alla tua ultima richiesta. Ora il compito è l’inventario globale, senza avviare modifiche al codice.



## Fonti



- **U**: Tua richiesta esplicita in questa conversazione. Questa chat LifeOS, incluse le correzioni numerate e le risposte successive.

- **H**: Richiesta ricostruita nel documento di passaggio. LifeOS-HANDOFF-2026-11-03.md, letto integralmente; non equivale a una citazione diretta dell’utente.

- **D**: Contratto riportato nei documenti del progetto. docs/native/REVISIONE-69…78.md: fonte indiretta, distinta dalle istruzioni dirette.

- **S1**: Tua richiesta precedente. Documento progetto Life OS — https://chatgpt.com/c/6abb7d7c-c5b4-83eb-be8a-9b37bb1250a4

- **S2**: Tua richiesta precedente. Ridisegna app produttività — https://chatgpt.com/c/6acf631c-bc3c-83eb-8012-76fcd087c8ce

- **S3**: Tua richiesta precedente. iOS Productivity Dashboard Design — https://chatgpt.com/c/6acf5c2a-3d08-83eb-80d2-34a9f594de71

- **S4**: Tua richiesta precedente. iOS Dashboard Design — https://chatgpt.com/c/6acf5c35-bd9c-83eb-b0f5-d94d690971ab

- **S5**: Tua richiesta precedente. Genera cinque versioni grafiche — https://chatgpt.com/c/6ae468e9-0838-83eb-a601-1fa51fa606d0

- **S6**: Tua richiesta precedente. Calendar Design Exploration — https://chatgpt.com/c/6ac62a3f-adcc-83ed-a953-2b22676bc566

- **S7**: Tua richiesta precedente. Ricreare Life OS in SwiftUI — https://chatgpt.com/c/6accb466-ce78-83ed-b0f1-fcec94e114db

- **P**: Mia proposta, non requisito di implementazione approvato. Suggerimenti forniti qui dopo le quattro foto della build 78. La richiesta di rappresentarli nel concept autorizzava l’immagine, non automaticamente tutte le modifiche al codice.