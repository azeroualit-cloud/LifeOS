# Life OS — sorgenti nativi

Overlay dei soli sorgenti modificati rispetto al pacchetto verificato 0.9.0 build 51. La CI estrae il pacchetto originale `../lifeos-native.zip` e applica questi file prima di compilare la build 52. Per ottenere tutti i sorgenti: `python3 scripts/prepare-native.py /tmp/lifeos-native-52`. Per un archivio locale: `python3 scripts/package-native.py` (output ignorato da Git in `native/build/`). I moduli invariati non vengono ripubblicati in chiaro.

Build 52: accento blu accessibile, superfici scure uniformi, completamento reversibile nelle sezioni Attivo/In attesa, comandi contestuali sotto la riga e calendario mensile a scorrimento continuo. La conservazione delle attività completate e della sezione In attesa richiede anche il backend aggiornato in `web/worker.mjs`. Non distribuire questa modifica soltanto sul client: il vecchio backend elimina ancora le attività completate dopo cinque giorni.

Le verifiche locali Foundation non compilano SwiftUI. La CI deve validare app, UI e archivio iPhone; fluidità e FPS richiedono una misura sul dispositivo. Nessuna nuova IPA dichiarata pronta prima dell'esito Apple.
