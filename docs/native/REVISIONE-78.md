> **Documento storico / evidenza tecnica.** Lo stato corrente e l’accettazione del prodotto sono in [docs/STATUS.md](../STATUS.md). Leggere anche [AI-HANDOFF.md](../AI-HANDOFF.md). La build 78 non è accettata dall’utente come pronta per la produzione.

# Revisione 78 — contratto e verifiche

Versione verificata: 0.10.17 (78), base consegnata 0.10.16 (77).
Sorgente applicativa: 33574a2114ea6e0d378f69d06aadf60378cf55e9.

| Area | Comportamento | Verifica |
|---|---|---|
| Dashboard | Solo HH:mm accanto alla data anche la sera; tocco apre tutti gli orari | Geometria e apertura su 15 Pro |
| Toolbar | Cerchio visivo 36 pt, area tattile 44 pt | Misure UI reali |
| Attenzione | Eventi di oggi, abitudini di oggi, eventi domani/dopodomani; nessuna attività generica | Ordinamento, esclusioni, eventi già iniziati |
| Finanza | Titolo/icona/freccia; numero e Budget; Aggiungi spesa a destra | Geometria e apertura editor |
| Nutrizione | P/C/G/fibre/kcal etichetta per 100 g, porzione effettiva, sola data | Calcolo, round trip, HealthKit, retry e tastiera |
| Salute | Somma di tutte le registrazioni energetiche, nessun selettore fonte o pulsante di collegamento | Query e aggregazione; assenza controlli UI |
| Riepilogo Salute | Quattro schede uniformi TDEE/Peso/Calorie/Simulazione, colori e simboli nativi | Riferimento Apple misurato; testo normale e accessibilità |
| Azioni Salute | Due icone Liquid Glass sopra la tab bar, peso e macro | 44 pt, posizione e apertura editor |
| Bloom | File → anteprima → conferma → dati visibili dopo riavvio | Prova UI reale con JSON sintetico e allegato di 6 MiB |

## Integrità

Le registrazioni nutrizionali precedenti mantengono il calcolo 4/4/9. Le nuove
usano le kcal esplicite scalate sulla porzione, senza riaggiungere le fibre.
Gli identificativi HealthKit originali restano agli indici 0–3; fibre all’indice 4.
I dati vengono salvati localmente prima dell’invio; retry e cancellazioni mantengono
identificativo e revisione per evitare duplicati creati da LifeOS.

Gli eventi di oggi sono cercati anche nell’intervallo operativo, perché la risposta
upcoming esclude gli appuntamenti già iniziati. L’ordinamento della dashboard non
dipende dal mese esplorato nel calendario.

Bloom coordina il risultato del selettore e la sua chiusura in entrambi gli ordini.
Solo dopo entrambi prepara l’anteprima, validando fuori dal main actor. L’importazione
conserva categorie, allegati e cestino e verifica una copia di sicurezza prima della
scrittura. Il backup personale originale non è modificato o caricato su GitHub.
Il suo controllo locale non equivale a un’importazione già eseguita sul telefono.

## Riferimento Apple Salute e REA

Skill ufficiale REA 49 da rea-agents@6.8.0 (morluto/rea), eseguita in checkout
temporaneo con Node 24.22.1. Nessun motore o server MCP globale installato.
REA ha letto Info.plist e 929 record di Assets.car del simulatore iOS 27.0,
com.apple.Health versione 7027.0.72.2.7. Nessun asset o binario Apple è distribuito
nell’app LifeOS.

La cattura popolata verificata proviene dal test AppleHealthReference del run
[41706031951](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41706031951).
Quel caso è passato; il run complessivo era fallito per il selettore di test Bloom.
Dati HealthKit sintetici: 7 giorni di peso e calorie. Geometria accessibile su
393 × 852 pt: margini esterni/interni 16 pt, scheda peso 132 pt, calorie 133 pt,
grafici larghi 80 pt e alti 44/50 pt. Energia alimentare verde con asset interno apple.slice,
non disponibile come SF Symbol pubblico su questo runtime. LifeOS usa quindi
un glifo vettoriale originale a forma di mela per intestazione e azione macro;
peso viola con figure; valore grande e unità secondaria. LifeOS uniforma le
schede a minimo 132 pt; TDEE arancio e simulazione blu distinguono metriche proprie.

Il riferimento viene fissato tramite checksum della schermata popolata
8eb8449e5838068c4e019389952a8873ecfce36645c6608e06ed034fd45e9793.
Il controllo obbligatorio confronta runtime, versione e hash del binario Apple
attuale con il riferimento. Questa scelta evita di ricatturare a ogni build il
catalogo Apple, che su un successivo avvio è rimasto vuoto nel suo editor.
La suite LifeOS resta interamente rieseguita sulla sorgente da consegnare.

## Evidenza finale

[Run completo 41721041653](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41721041653),
sorgente 33574a2114ea6e0d378f69d06aadf60378cf55e9: validazione e packaging riusciti.

- 267 test unitari e 15 prove UI su iPhone 15 Pro simulato, zero fallimenti.
- File → JSON sintetico con allegato di 6 MiB → anteprima → importazione →
  riavvio → nota ancora visibile. Annullamento e riapertura del selettore verificati.
- Testo normale, modalità chiara/scura e testo accessibile: schede uniformi,
  azioni grafiche compatte con area tattile 44 pt; controllo visivo delle schermate.
- Caso serale della preghiera: il testo visibile è solo l’ora. Il giorno resta
  nella descrizione VoiceOver e nella schermata degli orari.
- Quattro avvii Release reali, ciascuno osservato per 25 secondi: installazione
  nuova, aggiornamento, archivio sintetico popolato, sessione sintetica salvata.
  Nessun flag DEBUG utilizzato per questi avvii.
- Nuova ispezione REA di Info.plist e catalogo completo di 929 risorse, medesimo
  hash Assets.car del riferimento. Il timeout di compilazione del suo helper
  Swift è configurato a 300 secondi per i runner Xcode appena inizializzati.
- IPA arm64 app e widget 0.10.17 (78), package verifier e startup-import verifier
  riusciti anche sul file scaricato localmente. Nessun import debole del confronto
  Date incompatibile con il runtime usato; SDK/runtime 27.0.

SHA-256 IPA: d281d9d885ea4cc221022d3c52bf3fe00b876f77273821867d617a2be2b911e7.

[IPA diretta](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.17-build78/LifeOS-78.ipa).
Aggiornare senza disinstallare. Il backup personale va importato dal menu Archivio
in Bloom; non è incluso nell’IPA. Il controllo del file personale è stato locale
e in lettura, mentre le prove UI hanno utilizzato esclusivamente dati sintetici.
Nessuna prova fisica è stata eseguita sull’iPhone dell’utente.
