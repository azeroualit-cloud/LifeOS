import SwiftUI

/// GUIDES-INFOGRAPHICS-2026-11-24: the same four illustrated sheets as the site's «Guida».
struct NativeGuideScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.section) {
                Text("Le parti principali di LifeOS, spiegate con un disegno e tre passi. Le stesse schede sono sul sito, in Guida.")
                    .font(.subheadline).foregroundStyle(NativeDesign.secondary)
                ForEach(NativeGuideTopic.all) { topic in NativeGuideCard(topic: topic) }
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.large)
        }
        .background(NativeDesign.canvas)
        .navigationTitle("Guida")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("guide-screen")
    }
}

struct NativeGuideTopic: Identifiable {
    let id: String
    let title: String
    let lead: String
    let tint: Color
    let steps: [(String, String)]

    static let all: [NativeGuideTopic] = [
        .init(id: "finanza", title: "Finanza", lead: "Ogni spesa entra da una sola porta e tu scegli da dove arrivano i soldi.", tint: NativeDesign.financeBudget[0],
              steps: [("Nuova spesa", "Importo, Categoria e Voce. Poi «Da dove arrivano i soldi»: Budget, Risparmi o Piano."),
                      ("Piani", "Anticipo, Fondo, Ricorrente (fisso o stimato). La quota stimata segue la media delle bollette."),
                      ("Bollette", "I mesi passati non cambiano mai: il piano paga quanto ha messo da parte, il resto lo scegli tu.")]),
        .init(id: "calendario", title: "Calendario", lead: "Turni, eventi, orari del mese e date importanti nello stesso posto.", tint: NativeDesign.calendarAccent,
              steps: [("Dipingi turni", "Tocca il pennello, scegli il turno e tocca i giorni."),
                      ("Orari del mese", "Dashboard › prossimo orario › «Calendario degli orari», con Ramadan ed Eid segnati."),
                      ("Incontri", "Nel giorno scelto: una nota che nel calendario non mostra testo; il riepilogo si apre con Face ID.")]),
        .init(id: "nutrizione", title: "Nutrizione", lead: "Calorie nel range consigliato, macro, fibre e micronutrienti a colpo d’occhio.", tint: NativeDesign.nutritionTitle,
              steps: [("Obiettivi", "Calorie, proteine, grassi e fibre in Obiettivi; valgono anche sul sito."),
                      ("Alimento", "Aggiungi dal pulsante Alimento: arco e barre si aggiornano subito."),
                      ("Micronutrienti", "Tocca un nutriente per vedere da quali alimenti arriva.")]),
        .init(id: "avvisi", title: "Avvisi", lead: "Avvisi tuoi e della Finanza, con suono, ore di silenzio e un limite al giorno.", tint: NativeDesign.healthAccent,
              steps: [("Modelli", "Sul sito, in Avvisi: parti da un modello e regola soglia e orario."),
                      ("Come arrivano", "Su questo iPhone come notifica con suono; nessuna sveglia."),
                      ("Silenzio", "Nelle ore di silenzio non arriva nulla; gli orari giornalieri arrivano sempre se accesi.")]),
    ]
}

private struct NativeGuideCard: View {
    let topic: NativeGuideTopic

    var body: some View {
        NativeCard {
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                    Text(topic.title).font(.headline.weight(.bold)).foregroundStyle(topic.tint)
                    Text(topic.lead).font(.subheadline).foregroundStyle(NativeDesign.secondary)
                }
                NativeGuideArt(topic: topic)
                ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: NativeDesign.Space.small) {
                        Text(String(index + 1)).font(.footnote.weight(.bold)).foregroundStyle(topic.tint)
                            .frame(width: NativeDesign.Space.xLarge, height: NativeDesign.Space.xLarge)
                            .background(topic.tint.opacity(0.18), in: Circle())
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                            Text(step.0).font(.subheadline.weight(.semibold))
                            Text(step.1).font(.footnote).foregroundStyle(NativeDesign.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("guide-" + topic.id)
    }
}

/// Small drawings: the salary bar, a week with shifts, the calorie arc with macro bars, an alert.
private struct NativeGuideArt: View {
    let topic: NativeGuideTopic

    var body: some View {
        Group {
            switch topic.id {
            case "finanza":
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    GeometryReader { proxy in
                        HStack(spacing: NativeDesign.Space.none) {
                            ForEach(Array(zip(NativeDesign.salaryGroups, [0.4, 0.13, 0.29, 0.18])), id: \.1) { color, share in
                                Rectangle().fill(color).frame(width: proxy.size.width * share)
                            }
                        }.clipShape(Capsule())
                    }.frame(height: NativeDesign.Space.medium)
                    HStack(spacing: NativeDesign.Space.small) {
                        ForEach(["Budget", "Risparmi", "Piano"], id: \.self) { title in
                            Text(title).font(.footnote.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, NativeDesign.Space.small).loTileSurface()
                        }
                    }
                }
            case "calendario":
                HStack(spacing: NativeDesign.Space.xs) {
                    ForEach(Array(["morning", "afternoon", "afternoon", "night", "", "rest", "rest"].enumerated()), id: \.offset) { index, kind in
                        VStack(spacing: NativeDesign.Space.xxs) {
                            Text(String(23 + index)).font(.footnote.weight(.semibold))
                            Capsule().fill(kind.isEmpty ? Color.clear : LifeOSShiftPalette.color(kind).opacity(0.5)).frame(height: NativeDesign.Space.small)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, NativeDesign.Space.small).loTileSurface()
                    }
                }
            case "nutrizione":
                VStack(spacing: NativeDesign.Space.small) {
                    NativeCalorieGauge(calories: 2050, goal: 2200)
                    HStack(spacing: NativeDesign.Space.small) {
                        ForEach(Array(zip(["P", "C", "G", "F"], [0.8, 0.6, 0.4, 0.5])), id: \.0) { label, value in
                            VStack(spacing: NativeDesign.Space.xxs) {
                                Text(label).font(.caption2).foregroundStyle(NativeDesign.secondary)
                                ProgressView(value: value).tint(NativeDesign.nutritionTitle)
                            }
                        }
                    }
                }
            default:
                HStack(spacing: NativeDesign.Space.small) {
                    Image(systemName: "bell.badge.fill").font(.headline).foregroundStyle(topic.tint)
                    VStack(alignment: .leading, spacing: NativeDesign.Space.none) {
                        Text("Budget sotto 50 €").font(.subheadline.weight(.semibold))
                        Text("Con suono · alle 20:00").font(.footnote).foregroundStyle(NativeDesign.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(NativeDesign.Space.medium).loTileSurface()
            }
        }
        .accessibilityHidden(true)
    }
}
