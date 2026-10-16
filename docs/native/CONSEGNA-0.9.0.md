# LifeOS 0.9.0 — build 51

[Scarica il pacchetto IPA per Signulous](https://github.com/azeroualit-cloud/LifeOS/actions/runs/38978815976/artifacts/12081542774). Estrarre lo ZIP e caricare **LifeOS-unsigned.ipa** in Signulous sopra l’app esistente, senza disinstallarla. Il pacchetto contiene una sola IPA e SHA256.txt. Bundle: `com.nas.lifeos.probe`.

## Verifica Apple

[Build completata](https://github.com/azeroualit-cloud/LifeOS/actions/runs/38978815976) sul commit `850862bea86cb6dc22ce057874e3057585883c24`. Tutte le fasi sono riuscite: contratto con database condiviso, compilazione, suite completa, iPhone compatto, archivio Release per dispositivo iOS e caricamento dell’IPA.

- 74 test unitari superati.
- 30 test UI principali superati.
- 14 test UI su iPhone SE 3 superati.
- Totale delle suite: **118 esecuzioni, zero fallimenti**. Passata anche la regressione isolata Finanza su compatto.

La toolbar conserva pulsanti realmente premibili di almeno 44 punti con materiale Glass Apple; sono verificati anche i tocchi ai bordi. La prova di Finanza usa trascinamenti controllati e direzionali per raggiungere Spesa e Movimenti con testo grande. Le asserzioni su dimensioni, premibilità e destinazioni restano attive. Dopo la correzione della toolbar, Sources, asset e versione dell’app sono rimasti invariati durante la revisione del test di scorrimento.

## Contenuto

Finanza con panoramica senza card e azioni Budget · Extra · Spesa; Analisi con categorie su 3/6/12 mesi, previsione patrimonio, patrimonio e stipendi per competenza. Calendario compatto con griglia uniforme, colori dei turni conservati e agenda senza card; settimana Home con gli stessi componenti. Home con prossimo orario neutro e riepilogo animato accessibile. Tab bar di sistema e microinterazioni moderate.

Nessuna modifica al codice backend o comando di deploy Cloudflare in questa revisione. Installazione e fluidità sul telefono fisico restano da confermare; l’IPA non è stata scaricata e ispezionata localmente in questo ambiente. Compilazione, test, archivio e presenza del pacchetto sono verificati nella CI Apple.

## Identità degli artefatti

SHA256 ZIP sorgenti: `dd90cdc78d87be0afea5ce909782a8ec85204f895b50dc4d2e3025a26490a8d8`.

SHA256 ZIP dell’artefatto GitHub: `0bc28974e61760941a1b4a5c5947b08d38191fe0546500f68f12a85d1adedde9`. Questo digest riguarda lo ZIP scaricato da GitHub; il digest della IPA è nel suo SHA256.txt.
