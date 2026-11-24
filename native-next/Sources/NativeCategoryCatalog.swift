import Foundation

/// Presentation only. Never changes a category key, label or stored transaction.
/// Overrides the base copy (CATEGORY-ADMIN-2026-11-24): the choices follow the list edited in Admin on the site.
enum NativeCategoryCatalog {
    static var incomeChoices: [String] { NativeFinanceCategories.incomeChoices }
    static func choices(type: String, current: String) -> [String] {
        var result = type == "Entrata" ? incomeChoices : NativeFinanceCategories.expenseChoices
        if !result.contains(current) { result.append(current) }
        return result
    }
    static func symbol(for category: String) -> String {
        let normalized = category.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "it_IT")).lowercased()
        let words = Set(normalized.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        func has(_ aliases: String...) -> Bool { aliases.contains(where: words.contains) }
        // Specific meanings precede broad ones. Word matching avoids Barbiere → Bar and Gastronomia → Gas.
        if has("imposta", "imposte", "tassa", "tasse", "tributi") { return "building.columns" }
        if has("gas") { return "flame" }
        if has("acqua", "idrico", "idrica") { return "drop" }
        if has("luce", "elettricita", "elettrico", "elettricità", "utenze", "energia") { return "bolt" }
        if has("benzina", "carburante", "carburanti") { return "fuelpump" }
        if has("auto", "bollo", "trasporti", "trasporto", "parcheggio") { return "car" }
        if has("affitto", "casa", "condominio") { return "house" }
        if has("salute", "farmacia", "farmaci", "medico", "dentista") { return "cross.case" }
        if has("palestra", "sport", "fitness") { return "dumbbell" }
        if has("ristorazione", "ristorante", "ristoranti", "pasti") { return "fork.knife" }
        if has("bar", "caffe", "caffetteria") { return "cup.and.saucer" }
        if has("stipendio", "stipendi", "entrata", "entrate") { return "banknote" }
        if has("interessi") { return "percent" }
        if has("rimborso", "rimborsi") { return "arrow.uturn.backward" }
        if has("trasferimento", "trasferimenti") { return "arrow.left.arrow.right" }
        if has("abbonamento", "abbonamenti") { return "repeat" }
        if has("shopping", "abbigliamento", "vestiti") { return "bag" }
        if has("svago", "intrattenimento") { return "ticket" }
        if has("viaggio", "viaggi") { return "airplane" }
        if has("alimentari", "supermercato", "supermercati") || (has("spesa") && !has("extra")) { return "cart" }
        return "tag"
    }
}
