# Bloom — revisione della griglia approvata

Requisito H-GRID-01, approvato il 4 novembre 2026: due colonne, immagini contenute nella card e altezza proporzionata al contenuto, anteprime dei link. Accettazione visiva dell’utente ancora pendente.

## Implementazione

- Due colonne LazyVStack indipendenti, larghezze ricavate dalla viewport e vincolate anche sulle card e sulle immagini. Nessuna modifica a note, allegati o ordinamento salvato.
- Miniature locali proporzionate con orientamento rispettato. I titoli e il testo mantengono le anteprime compatte esistenti; il contenuto completo rimane nel dettaglio.
- Link web e primo link allegato: immagine/metadati con LinkPresentation, dominio, titolo salvato senza duplicazioni. Placeholder quando l’immagine non è disponibile. Cache locale separata dall’archivio (7 giorni, fino a 200 file), richieste metadati con timeout di 8 secondi. Non si modificano i backup per memorizzare le anteprime.
- Fixture DEBUG separata di 122 note: immagini verticali/orizzontali, testi lunghi, link con immagine e senza anteprima. Mai dati personali.

## Evidenza e diagnosi

Run [41813899400](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41813899400), sorgente applicativo `315360354363f0ebfcb38db5a0687c5c73caa8d3`: compilazione passata; 19 test archivio passati; 3 UI passati e 1 fallito. Standard: quattro pagine senza card fuori colonna o sovrapposte, immagine link presente. Testo grande: il test falliva dopo lo swipe.

Diagnosi dal filmato e dal record del gesto: swipe iniziale a y=791,17 pt, dentro la tab bar, che apriva Attività. Non un crash della griglia. Test corretto per iniziare sopra la tab bar; controlla anche movimento effettivo e permanenza sulla scheda Bloom. Nessun assert di contenimento/sovrapposizione rimosso.

Verifica corretta PASSATA nel run [41816351684](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41816351684), commit `3a157914` (leggere SHA completo su GitHub). Il codice applicativo è invariato; sono cambiati i gesti e le verifiche del test.

I tentativi superati sono stati annullati; il primo usava una fixture con un campo obbligatorio mancante, poi corretta e coperta dal test di validità dei 122 elementi. I testi sintetici sono stati normalizzati prima delle catture. GitHub ha restituito errori intermittenti di push; nessun force push. La CI ora evita upload nei run annullati (`!cancelled()`), continuando a conservare prove dei test falliti.

## Limiti

Non è una prova di parità del backup personale. Rete reale e disponibilità delle anteprime dei singoli siti (in particolare social con accesso richiesto) non sono certificate dalla fixture deterministica. Nessuna nuova IPA, prova sul telefono, nuova release o distribuzione backend. Dimensione compatta non ancora eseguita. La build 78 rimane non accettata per la produzione. Gli altri difetti UI richiedono modifiche proposte e approvate separatamente.

## Esito finale verificato

Run https://github.com/azeroualit-cloud/LifeOS/actions/runs/41816351684 — sorgente `3a1579147a4959df7eac20f04c103fa195cd4c8f`: SUCCESS. Compilazione, 19 unitari Bloom e 4 UI passati, zero errori. Esportati e scaricati 16 screenshot, inclusi quattro scorrimenti standard e quattro con testo grande. Catture standard pagina 0 e testo grande pagina 1 aperte e controllate visivamente: immagini e card restano nelle colonne, nessuna sovrapposizione; preview del link presente nel caso sintetico. Movimento reale dello scroll e permanenza su Bloom verificati.

QA-001/002: verificati sulla libreria sintetica nel simulatore iPhone 15 Pro, non ancora accettati dall’utente o verificati sul backup personale/telefono. Le proporzioni dell’intestazione con testo molto grande rimangono quelle precedenti e non sono state riprogettate in questa correzione. Cinque test locali di selezione e actionlint del workflow aggiornato passati. Ultima IPA e stato di accettazione globale invariati.
