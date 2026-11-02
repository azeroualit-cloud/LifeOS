# Implementazione 74 — stato della verifica

Questo documento sostituisce il primo elenco provvisorio. Implementazione, architettura, prove intermedie e limiti sono descritti in [Revisione 74](REVISIONE-74.md); l'inventario effettivo delle animazioni è in [Movimento 74](MOVIMENTO-74.md).

Implementati: navigazione Dashboard/Attività/Salute/Altro, calendario e controlli nativi, modulo nutrizione con writer HealthKit separato e registro recuperabile, archivio Bloom separato, importazione con conflitti espliciti, Libreria/Mappa/Riscopri, allegati originali, backup e cattura LifeOS.

La prima verifica Apple ha superato 230 test unitari e due UI. I successivi controlli della distribuzione hanno rilevato un problema di raggiungibilità della data selezionata dopo il ridimensionamento dell'agenda; la correzione deve superare nuovamente i controlli principali e compatti prima della pubblicazione.

La build 73 resta la consegna verificata finché Revisione 74 non riporta una distribuzione riuscita e un download controllato. Nessuna prova fisica HealthKit o comparazione con iOS 27.2 è stata eseguita. Il database Bloom reale del telefono non è nello ZIP: la sua migrazione richiede un backup esportato e il controllo successivo di conteggi, allegati e riapertura offline.
