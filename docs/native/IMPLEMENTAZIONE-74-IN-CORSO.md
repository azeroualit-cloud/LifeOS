# Implementazione 74 — consegna verificata

La build 0.10.13 (74) è stata pubblicata dopo 240 test unitari e 42 esecuzioni UI senza fallimenti. Download pubblico, integrità e app/widget verificati separatamente. [IPA per Signulous](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.13-build74/LifeOS-74.ipa).

Modifiche, architettura, sorgente, prove e limiti sono in [Revisione 74](REVISIONE-74.md); l’inventario dei movimenti è in [Movimento 74](MOVIMENTO-74.md). Implementati navigazione, calendario, Salute con registro recuperabile e Bloom locale con importazione, conflitti, allegati, Mappa e Riscopri.

SDK 27.2, runtime effettivo 27.0 su iPhone 15 Pro e SE 3 simulati. Restano distinte le prove fisiche HealthKit, provisioning, VoiceOver parlato e il confronto con Apple sullo stesso iPhone con iOS 27.2. Lo ZIP non contiene il database Bloom del telefono: la migrazione reale richiede un backup esportato e la verifica di conteggi, allegati e riapertura offline.
