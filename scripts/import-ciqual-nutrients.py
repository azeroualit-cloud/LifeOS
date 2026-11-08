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
    "vitaminB5": "BY", "vitaminB6": "BZ", "folate": "CA", "vitaminB12": "CE",
    "ala": "AS", "epa": "AU", "dha": "AV",
}
# Dry white rice is comparable to dry basmati for the missing zinc value.
SUBSTITUTES = {("9119", "zinc"): "9100"}
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
    foods = json.loads(catalog.read_bytes())
    for food in foods:
        code = food["id"].removeprefix("ciqual-")
        values = {}
        for key, column in COLUMNS.items():
            value = nutrient_value(rows, code, column)
            substitute = SUBSTITUTES.get((code, key))
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

    lines = ",\n".join("  " + json.dumps(food, ensure_ascii=False) for food in foods)
    catalog.write_text(f"[\n{lines}\n]\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
