"""Build cocktail estimates from documented serving assumptions.

Ingredient entries are (typical ABV percent, approximate carbs per 100 ml).
Serving volumes exclude ice and garnishes. An IBA slug points to the reference
for ingredient measures; a dash denotes a common bar pour assumed by LifeOS.
"""
import json
from pathlib import Path

INGREDIENTS = {
    "vodka": (40, 0), "gin": (40, 0), "rum": (40, 0), "tequila": (40, 0), "whiskey": (40, 0),
    "triple": (40, 25), "peach": (20, 25), "aperol": (11, 22), "campari": (25, 25),
    "vermouth": (16, 15), "prosecco": (11, 2), "coffee liqueur": (20, 40),
    "blue curacao": (21, 30), "coconut rum": (21, 20), "amaretto": (28, 30),
    "tonic": (0, 8.5), "cola": (0, 10.6), "lemon soda": (0, 9.5),
    "energy": (0, 11), "ginger beer": (0, 9), "soda": (0, 0), "espresso": (0, 0),
    "orange": (0, 9), "cranberry": (0, 12), "lime": (0, 8), "lemon": (0, 7),
    "pineapple": (0, 13), "tomato": (0, 4), "grenadine": (0, 65),
    "syrup": (0, 65), "coconut cream": (0, 30),
}

RECIPES = [
    ("gin-tonic", "Gin Tonic", ["gin e tonic", "gin & tonic", "gin tonica"], "-", {"gin": 50, "tonic": 150}),
    ("sex-on-the-beach", "Sex on the Beach", ["sex beach"], "sex-on-the-beach", {"vodka": 40, "peach": 20, "orange": 40, "cranberry": 40}),
    ("long-island", "Long Island Iced Tea", ["long island", "long island ice tea"], "long-island-iced-tea", {"vodka": 15, "tequila": 15, "rum": 15, "gin": 15, "triple": 15, "lemon": 25, "syrup": 30, "cola": 50}),
    ("vodka-lemon", "Vodka Lemon", ["vodka e limonata"], "-", {"vodka": 50, "lemon soda": 150}),
    ("vodka-red-bull", "Vodka Red Bull", ["vodka energy", "vodka redbull"], "-", {"vodka": 50, "energy": 150}),
    ("vodka-tonic", "Vodka Tonic", ["vodka tonica"], "-", {"vodka": 50, "tonic": 150}),
    ("vodka-orange", "Vodka Orange", ["screwdriver", "vodka arancia"], "-", {"vodka": 50, "orange": 150}),
    ("vodka-cranberry", "Vodka Cranberry", ["cape codder"], "-", {"vodka": 50, "cranberry": 150}),
    ("rum-cola", "Rum e Cola", ["rum coca", "rum coke"], "-", {"rum": 50, "cola": 150}),
    ("cuba-libre", "Cuba Libre", [], "cuba-libre", {"rum": 50, "cola": 120, "lime": 10}),
    ("whiskey-cola", "Whiskey e Cola", ["whisky cola", "jack e coca", "jack coke"], "-", {"whiskey": 50, "cola": 150}),
    ("mojito", "Mojito", [], "mojito", {"rum": 45, "lime": 20, "syrup": 12, "soda": 60}),
    ("moscow-mule", "Moscow Mule", [], "moscow-mule", {"vodka": 45, "ginger beer": 120, "lime": 10}),
    ("aperol-spritz", "Spritz Aperol", ["aperol spritz", "spritz"], "spritz", {"prosecco": 90, "aperol": 60, "soda": 20}),
    ("campari-spritz", "Spritz Campari", ["campari spritz"], "spritz", {"prosecco": 90, "campari": 60, "soda": 20}),
    ("negroni", "Negroni", [], "negroni", {"gin": 30, "campari": 30, "vermouth": 30}),
    ("americano", "Americano", [], "americano", {"campari": 30, "vermouth": 30, "soda": 30}),
    ("margarita", "Margarita", [], "margarita", {"tequila": 50, "triple": 20, "lime": 15}),
    ("tequila-sunrise", "Tequila Sunrise", [], "tequila-sunrise", {"tequila": 45, "orange": 90, "grenadine": 15}),
    ("espresso-martini", "Espresso Martini", [], "espresso-martini", {"vodka": 50, "coffee liqueur": 30, "syrup": 10, "espresso": 30}),
    ("cosmopolitan", "Cosmopolitan", ["cosmo"], "cosmopolitan", {"vodka": 40, "triple": 15, "lime": 15, "cranberry": 30}),
    ("daiquiri", "Daiquiri", [], "daiquiri", {"rum": 60, "lime": 20, "syrup": 10}),
    ("caipirinha", "Caipirinha", [], "caipirinha", {"rum": 60, "lime": 30, "syrup": 12}),
    ("caipiroska", "Caipiroska", ["caipirosca"], "-", {"vodka": 50, "lime": 30, "syrup": 12}),
    ("blue-lagoon", "Blue Lagoon", [], "-", {"vodka": 40, "blue curacao": 20, "lemon soda": 100}),
    ("malibu-ananas", "Malibu e Ananas", ["malibu pineapple", "malibu ananas"], "-", {"coconut rum": 50, "pineapple": 120}),
    ("bloody-mary", "Bloody Mary", [], "bloody-mary", {"vodka": 45, "tomato": 90, "lemon": 15}),
    ("amaretto-sour", "Amaretto Sour", [], "-", {"amaretto": 50, "lemon": 25, "syrup": 10}),
    ("mimosa", "Mimosa", [], "mimosa", {"prosecco": 75, "orange": 75}),
    ("tequila-shot", "Shot di tequila", ["shot tequila", "shottino tequila"], "-", {"tequila": 30}),
]


def entry(identifier, name, aliases, slug, recipe):
    alcohol = round(sum(volume * INGREDIENTS[key][0] / 100 * 0.789 for key, volume in recipe.items()), 2)
    carbs = round(sum(volume * INGREDIENTS[key][1] / 100 for key, volume in recipe.items()), 2)
    return dict(id="cocktail-" + identifier, name=name, detail="Cocktail · Stima", family="drink",
                aliases=aliases, protein=0, carbohydrate=carbs, fat=0, calories=round(alcohol * 7 + carbs * 4),
                cocktail=dict(volumeML=sum(recipe.values()), alcoholGrams=alcohol,
                              source="https://iba-world.com/iba-cocktail/" + slug + "/" if slug != "-" else "LifeOS · porzione da bar stimata"))


if __name__ == "__main__":
    target = Path(__file__).resolve().parents[1] / "native-next/Resources/cocktails.json"
    rows = [entry(*recipe) for recipe in RECIPES]
    target.write_text("[\n" + ",\n".join("  " + json.dumps(row, ensure_ascii=False) for row in rows) + "\n]\n",
                      encoding="utf-8", newline="\n")
