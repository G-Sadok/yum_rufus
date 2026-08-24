//
// DesignSystem
//
// Jetons generes depuis DESIGN-SPEC.md et composants d interface.
// Seul paquet du projet autorise a importer SwiftUI, et seul endroit du projet
// ou une couleur, une police, un rayon, un espacement ou une duree peut etre
// ecrit en clair.
//
// Les jetons couvrent la section 1 de DESIGN-SPEC.md, de 1.1 a 1.10 : surfaces
// des quatre themes dans les deux apparences, texte, semantique, fonds du
// lecteur, typographie, rayons, espacements, elevation, mouvement, icones.
// Chaque valeur est verifiee contre le document par la suite JetonsTests, qui
// lit DESIGN-SPEC.md sur disque au lieu d en recopier les valeurs.
//
// Les valeurs visuelles portees par un composant precis, comme le voile de bas
// de couverture de la section 3 ou le filet sous la barre de titre de la
// section 2.1, arrivent avec le composant qui les utilise. Elles resteront
// dans ce paquet.
//
// Depend de Core uniquement.
//

/// Espace de nommage des jetons de design.
///
/// Une vue n ecrit jamais une valeur visuelle. Elle passe par `Jetons`, ou par
/// la `Palette` resolue pour le theme et l apparence courants.
public enum Jetons {}
