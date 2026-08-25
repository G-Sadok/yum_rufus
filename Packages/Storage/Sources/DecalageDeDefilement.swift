import GRDB

//
// DecalageDeDefilement
//
// Seconde moitie de la position de reprise de la section 7.5 du cahier de
// developpement.
//
// La table `chapitre` porte deja `pageAtteinte`. Le decalage la rejoint plutot
// que de vivre dans une table dediee : il n existe qu une position par
// chapitre, une table separee imposerait une jointure a chaque ouverture de
// fiche et une seconde ecriture toutes les deux secondes pendant la lecture.
//
// La migration est purement additive, avec une valeur par defaut a zero. Les
// chapitres deja lus reprennent donc en haut de leur page atteinte, ce qui est
// exactement le comportement d avant cette fonctionnalite.
//

/// Ajoute `chapitre.decalageDeDefilement`.
func ajouterLeDecalageDeDefilement(_ base: Database) throws {
    try base.alter(table: "chapitre") { table in
        table.add(column: "decalageDeDefilement", .double).notNull().defaults(to: 0)
    }
}
