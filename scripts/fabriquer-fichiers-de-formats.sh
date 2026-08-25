#!/usr/bin/env bash
#
# fabriquer-fichiers-de-formats.sh
#
# Regenere le jeu de fichiers de test des formats d image, section 5.2 du
# cahier de developpement, dans Packages/ImagePipeline/Tests/Fichiers.
#
# Les fichiers produits sont suivis par git. Ce script ne sert qu a les
# refabriquer, jamais a les produire pendant la suite de tests : une suite qui
# encode ses propres fichiers ne teste que les encodeurs presents sur la
# machine, et laisse passer en silence les formats que la machine ne sait pas
# ecrire. WebP et JPEG XL sont precisement dans ce cas sur macOS, ou Image I/O
# les lit sans savoir les ecrire.
#
# Outils requis, tous absents des machines d integration continue et c est
# voulu, seuls les fichiers produits comptent :
#   python3   image de base, APNG, SVG
#   sips      JPEG, GIF, BMP, TIFF, JPEG 2000, HEIC
#   cwebp     WebP          brew install webp
#   avifenc   AVIF          brew install libavif
#   cjxl      JPEG XL       brew install jpeg-xl
#
# L image de base est une rampe diagonale : noir en haut a gauche, blanc en bas
# a droite, gris moyen aux deux autres coins. Une rampe survit au codage avec
# perte, et ses quatre coins different assez pour qu un retournement vertical,
# un retournement horizontal ou une transposition fassent echouer le test. Une
# mire en bandes symetriques ne le ferait pas.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="$RACINE/Packages/ImagePipeline/Tests/Fichiers"
# Une page de test n a pas besoin d etre grande, le sous echantillonnage a sa
# propre suite. 160 par 240 garde le rapport d une page de manga et laisse le
# BMP, seul format sans compression du lot, sous les 120 kio.
LARGEUR=160
HAUTEUR=240

mkdir -p "$DESTINATION"
cd "$DESTINATION"

exiger() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Outil manquant : %s\n' "$1" >&2
    exit 1
  fi
}

for outil in python3 sips cwebp avifenc cjxl; do
  exiger "$outil"
done

# ---------------------------------------------------------------------------
# Image de base et APNG, ecrits octet par octet.
# ---------------------------------------------------------------------------
python3 - "$LARGEUR" "$HAUTEUR" <<'PYTHON'
import struct
import sys
import zlib

largeur = int(sys.argv[1])
hauteur = int(sys.argv[2])


def rampe(inverse=False):
    """Rampe diagonale en RGB, un octet par composante."""
    lignes = []
    for y in range(hauteur):
        ligne = bytearray()
        for x in range(largeur):
            part = (x / (largeur - 1) + y / (hauteur - 1)) / 2
            if inverse:
                part = 1 - part
            ton = round(part * 255)
            ligne += bytes((ton, ton, ton))
        lignes.append(bytes(ligne))
    return lignes


def morceau(type_, contenu):
    corps = type_ + contenu
    return struct.pack('>I', len(contenu)) + corps + struct.pack('>I', zlib.crc32(corps) & 0xFFFFFFFF)


def compresser(lignes):
    brut = b''.join(b'\x00' + ligne for ligne in lignes)
    return zlib.compress(brut, 9)


SIGNATURE = b'\x89PNG\r\n\x1a\n'
ENTETE = morceau(b'IHDR', struct.pack('>IIBBBBB', largeur, hauteur, 8, 2, 0, 0, 0))

directe = rampe()
inversee = rampe(inverse=True)

with open('base.png', 'wb') as fichier:
    fichier.write(SIGNATURE + ENTETE + morceau(b'IDAT', compresser(directe)) + morceau(b'IEND', b''))

# APNG : la premiere image reste l image de base, portee par IDAT, donc lisible
# par tout decodeur PNG. La seconde, en fdAT, ne l est que par un decodeur qui
# comprend acTL. C est exactement le cas que la lecture doit traiter : rendre la
# premiere image sans se laisser arreter par l animation.
controle = morceau(b'acTL', struct.pack('>II', 2, 0))


def controle_dimage(sequence, retard):
    contenu = struct.pack(
        '>IIIIIHHBB',
        sequence, largeur, hauteur, 0, 0, retard, 1000, 0, 0,
    )
    return morceau(b'fcTL', contenu)


donnees_secondes = compresser(inversee)
image_seconde = morceau(b'fdAT', struct.pack('>I', 2) + donnees_secondes)

with open('page.apng', 'wb') as fichier:
    fichier.write(
        SIGNATURE
        + ENTETE
        + controle
        + controle_dimage(0, 200)
        + morceau(b'IDAT', compresser(directe))
        + controle_dimage(1, 200)
        + image_seconde
        + morceau(b'IEND', b'')
    )

# SVG : Image I/O ne declare aucun type SVG, le paquet le rasterise lui meme.
# Le fichier reprend la rampe sous forme de damier de 8 par 8, dont les quatre
# coins portent les memes tons que l image de base, aux memes endroits.
cellules = 8
pas_x = largeur / cellules
pas_y = hauteur / cellules
rects = []
for ligne in range(cellules):
    for colonne in range(cellules):
        ton = round((colonne + ligne) / (2 * (cellules - 1)) * 255)
        rects.append(
            '  <rect x="{:.4f}" y="{:.4f}" width="{:.4f}" height="{:.4f}" fill="rgb({},{},{})"/>'.format(
                colonne * pas_x, ligne * pas_y, pas_x + 0.5, pas_y + 0.5, ton, ton, ton
            )
        )

with open('page.svg', 'w') as fichier:
    fichier.write(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" width="{0}" height="{1}" '
        'viewBox="0 0 {0} {1}">\n'.format(largeur, hauteur)
        + '\n'.join(rects)
        + '\n</svg>\n'
    )

# Second SVG, celui des primitives : groupe transforme, chemin, cercle,
# ellipse, polygone et ligne. Il sert aux tests de geometrie, pas a la rampe.
with open('formes.svg', 'w') as fichier:
    fichier.write(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">\n'
        '  <rect x="0" y="0" width="400" height="400" fill="white"/>\n'
        '  <g transform="translate(200 0)">\n'
        '    <rect x="0" y="0" width="200" height="200" fill="black"/>\n'
        '  </g>\n'
        '  <circle cx="100" cy="300" r="90" fill="black"/>\n'
        '  <path d="M 220 220 H 380 V 380 Z" fill="black"/>\n'
        '  <polygon points="10,10 90,10 10,90" fill="black"/>\n'
        '</svg>\n'
    )

# SVG sans cadre : ni viewBox, ni largeur, ni hauteur. Le document est du SVG
# valide, mais rien n y dit a quelle taille le rendre. Il sert au test de la
# page de remplacement, ou il doit produire un contenu illisible et non un
# format inconnu.
with open('page-sans-cadre.svg', 'w') as fichier:
    fichier.write(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg">\n'
        '  <rect x="0" y="0" width="10" height="10" fill="black"/>\n'
        '</svg>\n'
    )
PYTHON

# ---------------------------------------------------------------------------
# Conversions, un format par outil.
# ---------------------------------------------------------------------------
cp base.png page.png

sips -s format jpeg   base.png --out page.jpg >/dev/null
sips -s format gif    base.png --out page.gif >/dev/null
sips -s format bmp    base.png --out page.bmp >/dev/null
sips -s format tiff -s formatOptions lzw base.png --out page.tif >/dev/null
sips -s format jp2    base.png --out page.jp2 >/dev/null
sips -s format heic   base.png --out page.heic >/dev/null

cwebp -quiet -lossless base.png -o page.webp
avifenc --lossless base.png page.avif >/dev/null
cjxl --quiet --distance 0 base.png page.jxl >/dev/null

rm -f base.png

# ---------------------------------------------------------------------------
# Fichiers volontairement casses, pour la page de remplacement.
# ---------------------------------------------------------------------------
# Un WebP coupe au quart : l en tete suffit a nommer le format, le corps ne
# suffit pas a decoder. C est le cas reel d un telechargement interrompu.
TAILLE="$(wc -c < page.webp | tr -d ' ')"
head -c "$((TAILLE / 4))" page.webp > page-tronquee.webp

# Des octets qui ne sont d aucun format connu, sous un nom qui promet une image.
printf 'ceci nest pas une image, seulement du texte range sous un nom trompeur' \
  > page-trompeuse.jpg

printf 'Fichiers produits dans %s\n' "$DESTINATION"
ls -1
