import Core
import SwiftUI

//
// MenuDAjoutDeSourceBouton
//
// Le menu d ajout de source de la section 5.3, pose dans la barre d outils.
//
// Il vit a part de l ecran Parcourir parce que la coquille dessine sa propre
// barre d outils. Un `.toolbar` pose par l ecran s en irait dans la barre
// native de la fenetre, a cote des feux de circulation, ou il resterait visible
// pendant la lecture alors que la section 5.7 veut que rien d autre ne le soit.
//
// Le menu porte les douze entrees dans l ordre impose, avec le separateur apres
// la premiere. Cet ordre n est pas decoratif : il place les sources les plus
// courantes en tete, et le transfert Wi-Fi a part parce qu il n installe rien.
//

/// Menu d ajout de source, commande de barre d outils de la section 5.3.
public struct MenuDAjoutDeSourceBouton: View {
    private let libelles: LibellesDeParcourir
    private let ajouter: @MainActor (TypeDeSource) -> Void

    public init(
        libelles: LibellesDeParcourir,
        ajouter: @escaping @MainActor (TypeDeSource) -> Void
    ) {
        self.libelles = libelles
        self.ajouter = ajouter
    }

    public var body: some View {
        Menu {
            ForEach(Array(MenuDAjoutDeSource.entrees.enumerated()), id: \.element.id) { rang, entree in
                Button(libelles.libelle(de: entree)) {
                    ajouter(entree.type)
                }

                if rang == MenuDAjoutDeSource.tailleDuPremierGroupe - 1 {
                    Divider()
                }
            }
        } label: {
            Label(libelles.ajouter, systemImage: "plus")
        }
        .menuIndicator(.visible)
        .fixedSize()
        .accessibilityLabel(libelles.ajouter)
    }
}
