# LifeOS 0.10.0 (61)

Sorgente verificato: 8b98a3b54716899e76aebb910be1761ffbda268f. IPA iOS non firmata, da firmare con Signulous. App e widget: 0.10.0 (61). Integrità ZIP, Info.plist e SHA256 verificati.

## Evidenza cumulativa

- Run 40219809250: 163 unitari e 40 UI principali superati; due query UI compatte poi corrette per raggiungere le completate spostate in fondo.
- Run 40235736129: 165 unitari, 7 regressioni calendario/attività, 2 UI aggiornate, Finanza e tutte le 14 UI compatte superati; archivio Release riuscito.
- Run 40238702185: 165 unitari, nuovo accesso Esporta turni nelle Impostazioni sui due formati e archivio superati.
- Run finale 40241234494: compilazione, navigazione della pagina esportazione con Form nativo sui due formati e archivio Release superati. Correzione esclusivamente di composizione UI; logica invariata rispetto ai 165 unitari precedenti. Anteprime principale e compatta esaminate.
- Localmente: 59 test Foundation, Worker reale su SQLite (conservazione completate, schedule abitudini, orari notifiche), 2 test dei controlli di deploy, design check e sintassi workflow superati.

Le metriche del simulatore non certificano FPS fisici. Widget e firma Signulous richiedono verifica sul dispositivo.

## Punto aperto

Backend online NON aggiornato. La revisione automatica ha bloccato distribuzione Cloudflare ed esportazione cifrata dei sorgenti live per mancanza di autorizzazione esplicita. Preflight in sola lettura interrotto per contesto live diverso dalla baseline: nessuna scrittura. Le patch locali sono testate, ma non vanno applicate sostituendo una versione live più recente. L'app impedisce conferme di salvataggio inesatte per orari e nuove programmazioni non supportati dal server legacy. La checklist completa resta aperta sul punto server.
