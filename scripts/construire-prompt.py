#!/usr/bin/env python3
"""
construire-prompt.py

Assemble le prompt envoye a Claude Code a partir d un gabarit et de la fiche
de la fonctionnalite. Passer par Python evite tous les problemes de quoting
shell, et fonctionne avec le bash 3.2 livre par macOS.
"""

import argparse
import json
import pathlib
import sys


def principal() -> int:
    a = argparse.ArgumentParser()
    a.add_argument("--gabarit", required=True)
    a.add_argument("--backlog", required=True)
    a.add_argument("--id", required=True)
    a.add_argument("--sortie", required=True)
    a.add_argument("--tentative", default="1")
    a.add_argument("--max-tentatives", default="3")
    a.add_argument("--branche", default="")
    a.add_argument("--extra", default="")
    args = a.parse_args()

    backlog = json.loads(pathlib.Path(args.backlog).read_text(encoding="utf-8"))
    fiche = next((f for f in backlog["features"] if f["id"] == args.id), None)

    if fiche is None:
        print(f"Fonctionnalite introuvable : {args.id}", file=sys.stderr)
        return 1

    extra = ""
    if args.extra and pathlib.Path(args.extra).is_file():
        extra = pathlib.Path(args.extra).read_text(encoding="utf-8", errors="replace")
        # Garder la fin, c est la ou sont les echecs
        lignes = extra.splitlines()
        if len(lignes) > 80:
            extra = "\n".join(["[... debut tronque ...]"] + lignes[-80:])

    remplacements = {
        "{{ID}}": fiche["id"],
        "{{TITRE}}": fiche["titre"],
        "{{ETAPE}}": str(fiche["etape"]),
        "{{DESCRIPTION}}": fiche["description"],
        "{{CRITERES}}": "\n".join("- " + c for c in fiche.get("criteres", [])),
        "{{SKILLS}}": "\n".join("- " + s for s in fiche.get("skills", [])),
        "{{BRANCHE}}": args.branche,
        "{{TENTATIVE}}": args.tentative,
        "{{MAX_TENTATIVES}}": args.max_tentatives,
        "{{SORTIE_VERIFICATIONS}}": extra,
    }

    texte = pathlib.Path(args.gabarit).read_text(encoding="utf-8")
    for cle, valeur in remplacements.items():
        texte = texte.replace(cle, valeur)

    # Garde fou : la regle de redaction s applique aussi au prompt
    texte = texte.replace("\u2014", ", ")

    pathlib.Path(args.sortie).write_text(texte, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
