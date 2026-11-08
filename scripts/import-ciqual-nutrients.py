import argparse
import hashlib
import json
import re
from pathlib import Path
from xml.etree import ElementTree
from zipfile import ZipFile

WORKBOOK_MD5 = "a953e8c473d8cee24a32f89a48fbd54d"
NS = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
COLUMNS = {
    "vitaminC": "BU", "zinc": "BJ", "calcium": "AY", "chloride": "AZ",
    "copper": "BA", "iron": "BB", "iodine": "BC", "magnesium": "BD",
    "manganese": "BE", "phosphorus": "BF", "potassium": "BG",
    "selenium": "BH", "sodium": "BI", "vitaminA": "BK", "vitaminD": "BN",
    "vitaminE": "BR", "vitaminK1": "BS", "vitaminK2": "BT",
    "vitaminB1": "BV", "vitaminB2": "BW", "vitaminB3": "BX",
    "vitaminB5": "BY", "vitaminB6": "BZ", "folate": "CA", "folateMass": "CB", "vitaminB12": "CE",
    "ala": "AS", "epa": "AU", "dha": "AV",
}
# Dry white rice is comparable to dry basmati for the missing zinc value.
SUBSTITUTES = {("9119", "zinc"): "9100"}
# Closely matched food/preparation pairs; used only where a direct value is absent.
COMPARABLE = {
    "36019": "36024",  # raw chicken leg meat, without skin
    "36024": "36019",
    "36022": "36002",  # raw chicken leg with skin, for raw drumstick
    "36004": "36006",  # roasted leg: lean tissue nutrients only
    "36006": "36004",
    "36030": "36031",  # boiled leg: lean tissue nutrients only
    "36031": "36030",
    "40402": "40409",  # raw beef/veal kidney
    "40409": "40402",
    "40403": "40408",  # cooked beef/veal kidney
    "40408": "40403",
}
LEAN_TISSUE_KEYS = {"iron", "zinc", "phosphorus", "potassium", "magnesium", "vitaminB12"}

# The closest Ciqual entry supplies estimated composition and an approximate edible yield.
CUTS = {
    "sovracoscia-cruda-pelle": ("Sovracoscia di pollo cruda con pelle", "36002", ["sovracoscia con pelle"]),
    "sovracoscia-forno": ("Sovracoscia di pollo al forno senza pelle", "36006", ["sovracoscia al forno"]),
    "sovracoscia-forno-pelle": ("Sovracoscia di pollo al forno con pelle", "36004", []),
    "sovracoscia-lessa": ("Sovracoscia di pollo lessa senza pelle", "36030", ["sovracoscia bollita"]),
    "sovracoscia-lessa-pelle": ("Sovracoscia di pollo lessa con pelle", "36031", []),
    "fuso-crudo": ("Fuso di pollo crudo senza pelle", "36024", ["fusello crudo senza pelle"]),
    "fuso-forno": ("Fuso di pollo al forno senza pelle", "36006", []),
    "fuso-forno-pelle": ("Fuso di pollo al forno con pelle", "36004", ["fusello arrosto"]),
    "fuso-lesso": ("Fuso di pollo lesso senza pelle", "36030", []),
    "fuso-lesso-pelle": ("Fuso di pollo lesso con pelle", "36031", ["fuso bollito con pelle"]),
}
EXTRA = {
    "40402": ("Rene di manzo crudo", "meat", ["rognone di manzo crudo"]),
    "40403": ("Rene di manzo cotto", "meat", ["rognone di manzo", "rognone"]),
    "40408": ("Rene di vitello cotto", "meat", ["rognone di vitello"]),
    "25221": ("Kefta di manzo e agnello cotta", "meal", ["kofta", "polpette marocchine"]),
    "25194": ("Kefta di manzo e agnello cruda", "meal", ["kefta cruda"]),
    "30155": ("Merguez di manzo e montone cotta", "meat", ["merguez"]),
    "30156": ("Merguez di manzo e montone cruda", "meat", ["merguez cruda"]),
    "25924": ("Zuppa marocchina", "meal", ["zuppa alla marocchina"]),
    "16401": ("Burro chiarificato", "fat", ["ghee"]),
}
NUMBER = r"\d+(?:\.\d+)?"


def read_workbook(path):
    if hashlib.md5(path.read_bytes()).hexdigest() != WORKBOOK_MD5:
        raise ValueError("Expected the Ciqual 2025 English workbook from Zenodo record 17550133.")
    with ZipFile(path) as workbook:
        strings = [
            "".join(part.text or "" for part in item.findall(".//x:t", NS))
            for item in ElementTree.fromstring(workbook.read("xl/sharedStrings.xml"))
        ]
        sheet = ElementTree.fromstring(workbook.read("xl/worksheets/sheet1.xml"))
    rows = {}
    for row in sheet.findall(".//x:row", NS):
        cells = {}
        for cell in row:
            value = cell.find("x:v", NS)
            if value is not None:
                column = re.match(r"[A-Z]+", cell.attrib["r"])[0]
                cells[column] = strings[int(value.text)] if cell.get("t") == "s" else value.text
        if "G" in cells:
            rows[cells["G"]] = cells
    return rows


def nutrient_value(rows, code, column):
    raw = rows[code].get(column, "-").strip().replace(",", ".")
    if re.fullmatch(NUMBER, raw):
        return {"amount": float(raw)}
    if re.fullmatch(r"<\s*" + NUMBER, raw):
        return {"amount": float(raw[1:]) / 2, "estimateSource": f"ciqual-{code}:limite"}
    return None


def main():
    parser = argparse.ArgumentParser(description="Add Ciqual 2025 nutrients to the LifeOS food catalog.")
    parser.add_argument("workbook", type=Path)
    rows = read_workbook(parser.parse_args().workbook)
    catalog = Path(__file__).resolve().parents[1] / "native-next/Resources/generic-foods.json"
    foods = [food for food in json.loads(catalog.read_bytes()) if not food["id"].startswith("estimate-")]
    existing = {food["id"]: food for food in foods}
    for code, (name, family, aliases) in EXTRA.items():
        identifier = f"ciqual-{code}"
        if identifier in existing:
            continue
        macros = {
            key: nutrient_value(rows, code, column)
            for key, column in {"calories": "K", "protein": "O", "carbohydrate": "Q", "fat": "R", "fibre": "AA"}.items()
        }
        food = dict(id=identifier, name=name, detail="Generic", family=family, aliases=aliases)
        food.update({key: value["amount"] if value else (None if key == "fibre" else 0) for key, value in macros.items()})
        foods.append(food)
        existing[identifier] = food
    existing["ciqual-36022"].update(
        name="Fuso di pollo crudo con pelle", aliases=["fuso di pollo", "fusello di pollo", "drumstick"], boneInEdiblePercent=70
    )
    for food in foods:
        code = food["id"].removeprefix("ciqual-")
        values = {}
        for key, column in COLUMNS.items():
            value = nutrient_value(rows, code, column)
            if value is None and key == "folateMass":
                intrinsic = nutrient_value(rows, code, "CC")
                enrichment = nutrient_value(rows, code, "CD")
                if intrinsic is not None and enrichment is not None:
                    value = {"amount": intrinsic["amount"] + enrichment["amount"]}
                    sources = [amount["estimateSource"] for amount in (intrinsic, enrichment) if "estimateSource" in amount]
                    if sources:
                        value["estimateSource"] = ", ".join(sources)
            substitute = SUBSTITUTES.get((code, key)) or (COMPARABLE.get(code) if key in LEAN_TISSUE_KEYS else None)
            if value is None and substitute is not None:
                match = nutrient_value(rows, substitute, column)
                if match is not None and "estimateSource" not in match:
                    value = {"amount": match["amount"], "estimateSource": f"ciqual-{substitute}"}
            if value is None:
                continue
            if key in {"ala", "epa", "dha"}:
                value["amount"] = round(value["amount"] * 1000, 9)
            values[key] = value
        food["nutrientValues"] = values

    for key, (name, code, aliases) in CUTS.items():
        source = existing[f"ciqual-{code}"]
        values = {nutrient: dict(value, estimateSource=f"ciqual-{code}")
                  for nutrient, value in source["nutrientValues"].items()}
        foods.append(dict(source, id=f"estimate-{key}", name=name, aliases=aliases,
                          detail="Generic · Valori stimati", nutrientValues=values))

    lines = ",\n".join("  " + json.dumps(food, ensure_ascii=False) for food in foods)
    catalog.write_text(f"[\n{lines}\n]\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
