# Build 93 - piano di implementazione e stato

Ramo `codex/build93`, base build 92 pubblicata (0.10.30 build 92). Obiettivo 0.10.31 build 93.
Autorizzazione IPA: `IPA-DELIVERY-93-2026-11-21` ("Sì IPA 93"), una sola IPA a gate verdi sullo stesso commit.
Riferimento visivo approvato: https://claude.ai/artifact/QAanqSYRowbYWgUKV8n271 (`BUILD93-PREVIEW-FINAL-2026-11-21`).
Inventario da rispettare: [BUILD-93-FEATURES.md](BUILD-93-FEATURES.md). Nessuna funzione della 92 può mancare.

## Come si compila

Su Linux non c'è Xcode. La CI assembla lo zip di base fissato (`lifeos-native.zip` al commit 02c2c08) più l'overlay `native-next/`
(vedi `.github/actions/native-compat76`). Un file della base si modifica copiandolo in `native-next/Sources`.
- `lifeos-compile93.yml`: compila e lancia i soli test unitari a ogni push su `native-next/**`. Mai IPA.
- `lifeos-candidate93.yml` (da creare alla fine): gate completo come la 92, poi IPA 0.10.31 build 93.

## Fasi

| Fase | Contenuto | Stato |
|---|---|---|
| 1 Dati online | Modulo `backend/bloom-foods` (stesse tabelle del sito, campi solo-app in `web_foods_app` e `web_bloom_app`, date Apple convertite anche per `trashedAt` con riparazione idempotente). `NativeOnlineSync`: il server decide, il telefono tiene cache e byte degli allegati; trasferimento automatico una tantum ripetibile senza doppioni; vince la modifica più recente; Worker vecchio = nessun cambiamento. Impostazioni: Dati sul server, Esporta backup completo (Bloom con allegati, alimenti, dati app). | Codice e test scritti, in attesa di CI |
| 1b Deploy Worker | `lifeos-bloomfoods-deploy93.yml` (solo avvio manuale) cambia solo `lifeos-native-test`. Lo avvia Nas. | Pronto, non distribuito |
| 2 Schede approvate | Dashboard, Attività, Calendario, Agenda, Dipingi turni, Salute (Cronologia a barre verticali, Simulazione peso, TDEE con criteri), fogli alimento/quantità/macro/obiettivi/peso/evento/abitudine/orari | Da fare |
| 3 Finanza | Panoramica, Analisi interattiva (ordine Ritmo, Fondo con € al mese, Stima patrimonio con uscite programmate, Spese per categoria, Entrate e uscite, Stipendi, Giorno per giorno da luglio), Avvisi regolabili (`FINANCE-ALERTS-2026-11-21`), Budget, Movimenti, fogli con blocco "Da dove arrivano i soldi" (`FUNDING-BLOCK-2026-11-21`) | Da fare |
| 4 Bloom | Mappa con pin per categoria, gruppi, filtro a tendina, scheda con frecce; schede | Da fare |
| 5 Gate e IPA | Versione 0.10.31/93, workflow candidate93, controlli scala aurea e continuità linee, suite UI completa, 4 avvii Release, IPA | Da fare |

## Regole di lavoro

- Conservare identificativi di accessibilità e titoli di navigazione usati dai test UI; cambiare l'aspetto, non i percorsi.
- Nessun testo esplicativo nelle schermate (decisione dell'anteprima).
- Gli allegati di Bloom restano sul telefono: il server conserva il nome. Una nota creata sul sito con un file non presente sul telefono appare come nota.
- La CI verde non è accettazione del prodotto (la build 78 fu rifiutata nonostante i test verdi).
