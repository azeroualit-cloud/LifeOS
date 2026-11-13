# Sei destinazioni Liquid Glass — 13 novembre 2026

Richiesta esplicita e conferma NAVIGATION-SIX-GLASS-2026-11-13: tutte sei visibili senza Altro, ordine Dashboard/Attività/Salute/Bloom/Finanza/Calendario. Nessuna IPA o deploy autorizzati.

## Implementazione

La barra nativa UITabBarController introduceva automaticamente Altro per sei destinazioni. Sostituita la composizione visibile con NativeSixTabBar: materiale Liquid Glass ufficiale su iOS26,materiale di sistema sui precedenti;target tattili e label accessibili,stato selezionato. A dimensioni testo accessibili restano sei icone con etichette VoiceOver complete. Si nasconde quando compare la tastiera e si ripristina dopo la chiusura.

NativeTabContainer usa controller SwiftUI creati al primo accesso e mantenuti per conservare ciascuno stack senza montare tutte le schermate contemporaneamente. Inoltra l’intero EnvironmentValues e gli oggetti store/router/health; bilancia la comparsa/scomparsa nei cambi visibili. Percorsi Dashboard e deep link conservati; riselezionare Dashboard torna alla radice.

## Catalogo alcolici

Conferma utente: mantenere quelli da discoteca,escludere quelli da supermercato. NativeFoodCatalogPolicy filtra128vociCoop:123bevande alcoliche in categorie ufficiali e5alimenti con liquore esplicito.30cocktail da discoteca rimangono. Policy applicata alla lista pubblica combinata,non ai file originali acquisiti,alle voci personali o agli snapshot storici. Catalogo fonteCoop2893rimane documentato completo;voci visibili ridotte da policy.

Non eliminare per sottostringhe:aceti,lievito di birra,acqua e bibite non sono alcolici. Prodotti dichiarati0,0/analcolici/dealcolizzati non vengono trattati automaticamente come bevande alcoliche certe;nessuna certificazionehalal. L’esclusione non cancella registrazioni pregresse.

## Prove

Validazioni locali cataloghi e8test selettore passati;conteggio128esclusioni riprodotto sulla fonte. CI six-glass preparata su simulatore compatto:3unitari policy e3UI(navigazione/stati,testo grande/tastiera,catalogo integratori). Compilazione,esito e nuove catture da acquisire dal run. Non dichiarare il comportamento fisico o l’accettazione sulla sola compilazione.

Catalogo1000già provato su20f604a,run43448734353:2unitari e1UI passati,catture fonte/licenza/porzione ispezionate. Non ripetere quelle prove senza cambiamenti rilevanti. Il recupero precedente43446654736ha superato1unitario+1UI;21casi del precedente run conservati.
