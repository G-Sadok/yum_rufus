#!/usr/bin/env python3
"""
fabriquer-fond-dmg.py
Fabrique le fond de la fenetre du DMG a partir des jetons du systeme de design.

Le fond du DMG n est pas une vue de l application, mais il porte des couleurs,
et la regle 4 du projet veut qu aucune valeur visuelle ne vive hors de
DesignSystem. Les trois couleurs employees sont donc lues dans les jetons Swift
au moment de la fabrication, jamais recopiees ici. Si un jeton change de nom ou
disparait, le script echoue au lieu de peindre une couleur inventee.

Le fichier produit fait 660 par 400 points, soit exactement la zone de contenu
de la fenetre posee par lib-dmg.sh. Toute autre taille decalerait le fond par
rapport aux deux icones.

Usage :
  ./scripts/fabriquer-fond-dmg.py [chemin de sortie]
"""

import re
import struct
import sys
import zlib
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
JETONS_SURFACE = RACINE / "Packages/DesignSystem/Sources/JetonsDeSurface.swift"
JETONS_SEMANTIQUES = RACINE / "Packages/DesignSystem/Sources/JetonsSemantiques.swift"

LARGEUR = 660
HAUTEUR = 400

# Position des deux icones dans la fenetre, en points, origine en haut a gauche.
# Ces memes coordonnees sont posees par lib-dmg.sh. Les deux doivent bouger
# ensemble, sinon la fleche ne relie plus rien.
CENTRE_APPLICATION = (170, 200)
CENTRE_APPLICATIONS = (490, 200)


def lire_jeton_de_surface(nom: str) -> tuple:
    """Lit une couleur du theme midnight en variante sombre."""
    texte = JETONS_SURFACE.read_text(encoding="utf-8")
    debut = texte.find("static let midnightSombre")
    if debut < 0:
        raise SystemExit(f"Jeton midnightSombre introuvable dans {JETONS_SURFACE}")
    # Le bloc s arrete au theme suivant. Chercher la premiere parenthese
    # fermante ne marcherait pas : c est celle de CouleurHexadecimale, sur la
    # premiere ligne du bloc.
    suite = texte.find("static let", debut + 10)
    bloc = texte[debut:suite if suite > 0 else len(texte)]
    trouve = re.search(rf"\b{nom}: CouleurHexadecimale\(0x([0-9A-Fa-f]{{6}})\)", bloc)
    if not trouve:
        raise SystemExit(f"Jeton surface.{nom} introuvable dans {JETONS_SURFACE}")
    return depuis_hexadecimal(trouve.group(1))


def lire_jeton_semantique(nom: str) -> tuple:
    """Lit une couleur semantique, accent par exemple."""
    texte = JETONS_SEMANTIQUES.read_text(encoding="utf-8")
    trouve = re.search(rf"\b{nom}: CouleurHexadecimale\(0x([0-9A-Fa-f]{{6}})\)", texte)
    if not trouve:
        raise SystemExit(f"Jeton {nom} introuvable dans {JETONS_SEMANTIQUES}")
    return depuis_hexadecimal(trouve.group(1))


def depuis_hexadecimal(valeur: str) -> tuple:
    entier = int(valeur, 16)
    return ((entier >> 16) & 0xFF, (entier >> 8) & 0xFF, entier & 0xFF)


def melanger(fond: tuple, dessus: tuple, alpha: float) -> tuple:
    alpha = max(0.0, min(1.0, alpha))
    return tuple(
        int(round(fond[i] * (1.0 - alpha) + dessus[i] * alpha)) for i in range(3)
    )


def distance(point: tuple, x: int, y: int) -> float:
    return ((x - point[0]) ** 2 + (y - point[1]) ** 2) ** 0.5


def peindre() -> bytearray:
    haut = lire_jeton_de_surface("card")
    bas = lire_jeton_de_surface("canvas")
    accent = lire_jeton_semantique("accent")

    pixels = bytearray(LARGEUR * HAUTEUR * 3)
    centre_x = LARGEUR / 2.0
    centre_y = HAUTEUR / 2.0
    rayon_maximal = (centre_x**2 + centre_y**2) ** 0.5

    for y in range(HAUTEUR):
        progression = y / (HAUTEUR - 1)
        ligne = melanger(haut, bas, progression)
        for x in range(LARGEUR):
            couleur = ligne

            # Assombrissement radial. Il tient les deux icones au centre du
            # regard sans dessiner de cadre, ce que la section 2.6 du cahier
            # de design refuse.
            rayon = distance((centre_x, centre_y), x, y) / rayon_maximal
            couleur = melanger(couleur, (0, 0, 0), 0.22 * rayon * rayon)

            # Halo accentue derriere l icone de l application. Il designe la
            # source du geste de glisser sans ajouter de texte a traduire.
            halo = distance(CENTRE_APPLICATION, x, y)
            if halo < 150:
                intensite = (1.0 - halo / 150.0) ** 2
                couleur = melanger(couleur, accent, 0.10 * intensite)

            decalage = (y * LARGEUR + x) * 3
            pixels[decalage] = couleur[0]
            pixels[decalage + 1] = couleur[1]
            pixels[decalage + 2] = couleur[2]

    dessiner_fleche(pixels, accent)
    return pixels


def poser(pixels: bytearray, x: int, y: int, couleur: tuple, alpha: float) -> None:
    if not (0 <= x < LARGEUR and 0 <= y < HAUTEUR):
        return
    decalage = (y * LARGEUR + x) * 3
    fond = (pixels[decalage], pixels[decalage + 1], pixels[decalage + 2])
    melange = melanger(fond, couleur, alpha)
    pixels[decalage] = melange[0]
    pixels[decalage + 1] = melange[1]
    pixels[decalage + 2] = melange[2]


def dessiner_fleche(pixels: bytearray, accent: tuple) -> None:
    """Trace la fleche qui relie l application au dossier Applications."""
    depart = CENTRE_APPLICATION[0] + 95
    arrivee = CENTRE_APPLICATIONS[0] - 95
    hauteur = CENTRE_APPLICATION[1]

    for x in range(depart, arrivee):
        # La fleche s efface a ses deux extremites pour ne pas heurter les
        # icones. Une ligne franche donnerait un trait de tableau blanc.
        position = (x - depart) / float(max(1, arrivee - depart - 1))
        attenuation = min(1.0, 4.0 * min(position, 1.0 - position))
        for epaisseur in (-1, 0, 1):
            alpha = 0.55 if epaisseur == 0 else 0.25
            poser(pixels, x, hauteur + epaisseur, accent, alpha * attenuation)

    # La pointe se pose a l extremite droite du trait, au plus pres du dossier
    # Applications, et les deux branches s ouvrent vers la gauche. Une pointe
    # posee a l envers designerait l application au lieu de sa destination.
    for pas in range(16):
        for epaisseur in (0, 1):
            poser(pixels, arrivee - pas, hauteur - pas + epaisseur, accent, 0.5)
            poser(pixels, arrivee - pas, hauteur + pas - epaisseur, accent, 0.5)


def ecrire_png(chemin: Path, pixels: bytearray) -> None:
    brut = bytearray()
    for y in range(HAUTEUR):
        brut.append(0)  # filtre nul, la compression zlib suffit sur un degrade
        debut = y * LARGEUR * 3
        brut.extend(pixels[debut:debut + LARGEUR * 3])

    def morceau(nom: bytes, donnees: bytes) -> bytes:
        entete = struct.pack(">I", len(donnees)) + nom + donnees
        return entete + struct.pack(">I", zlib.crc32(nom + donnees) & 0xFFFFFFFF)

    entete = struct.pack(">IIBBBBB", LARGEUR, HAUTEUR, 8, 2, 0, 0, 0)
    contenu = (
        b"\x89PNG\r\n\x1a\n"
        + morceau(b"IHDR", entete)
        + morceau(b"IDAT", zlib.compress(bytes(brut), 9))
        + morceau(b"IEND", b"")
    )
    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_bytes(contenu)


def main() -> int:
    sortie = Path(sys.argv[1]) if len(sys.argv) > 1 else RACINE / "Ressources/fond-dmg.png"
    ecrire_png(sortie, peindre())
    print(f"Fond du DMG ecrit dans {sortie}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
