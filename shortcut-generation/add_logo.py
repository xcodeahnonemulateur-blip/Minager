#!/usr/bin/env python3
"""Ajoute une image PNG/JPEG dans une recette JSON locale (jamais publiée automatiquement).
L'image devient une séquence Text(Base64) -> Decode Base64 -> Quick Look.
Ne change PAS l'icône de la tuile Raccourcis ou de l'écran d'accueil.
"""
import argparse
import base64
import json
from pathlib import Path

MAX_BYTES = 400_000

def add_logo(recipe, image: bytes):
    if len(image) > MAX_BYTES:
        raise ValueError("Logo trop volumineux (limite 400 Ko). Réduire la résolution.")
    if not (image.startswith(b"\x89PNG\r\n\x1a\n") or image.startswith(b"\xff\xd8\xff")):
        raise ValueError("Format non pris en charge : utiliser PNG ou JPEG")
    menus = [a["menu"] for a in recipe["actions"] if isinstance(a, dict) and "menu" in a]
    if len(menus) != 1:
        raise ValueError("La recette doit contenir un seul menu principal")
    menu = menus[0]
    if any(case["title"] == "Afficher mon logo" for case in menu["cases"]):
        raise ValueError("Le logo est déjà ajouté")
    encoded = base64.b64encode(image).decode("ascii")
    menu["cases"].append({
        "title":"Afficher mon logo",
        "actions":[
            {"action":"comment","params":{"text":"Image embarquée sous forme de texte Base64, décodée localement."}},
            {"action":"text","as":"logo_base64","params":{"text":encoded}},
            {"action":"base64_decode","as":"logo_image","params":{"source":{"ref":"logo_base64"}}},
            {"action":"preview","params":{"source":{"ref":"logo_image"}}},
            {"action":"share","params":{"source":{"ref":"logo_image"}}}
        ]
    })
    return recipe

def main():
    p = argparse.ArgumentParser(description="Intégrer une image au raccourci expérimental")
    p.add_argument("recipe", type=Path)
    p.add_argument("image", type=Path)
    p.add_argument("-o","--output", type=Path, required=True)
    args = p.parse_args()
    try:
        data = json.loads(args.recipe.read_text(encoding="utf-8"))
        output = add_logo(data,args.image.read_bytes())
        args.output.write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding="utf-8")
    except (OSError,ValueError) as exc:
        p.exit(1, "ERREUR : "+str(exc)+"\n")
    print("Recette avec logo sauvegardée localement :",args.output)
    print("Attention: le fichier contient l'image en clair (base64). Ne le publiez pas sans autorisation.")

if __name__ == "__main__":
    main()
