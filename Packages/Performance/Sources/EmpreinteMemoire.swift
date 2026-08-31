// `mach_task_self_` est une variable globale du noyau, et la concurrence
// stricte de Swift 6 refuse d en lire une depuis un contexte concurrent. Le
// compilateur local l accepte, celui de l integration continue non, et le
// fichier ne compilait donc que sur la machine de developpement.
//
// L import en mode pre concurrence leve le diagnostic la ou il est infonde :
// ce port ne change jamais de la vie du processus. Le declarer sur non verifie
// aurait aussi marche, mais le compilateur local juge alors la mention inutile
// et l avertit, ce que le controle de compilation refuse.
@preconcurrency import Darwin
import Foundation

//
// EmpreinteMemoire
//
// L empreinte physique du processus, celle que le systeme regarde avant de tuer
// une application.
//
// C est `phys_footprint` de `TASK_VM_INFO` et pas `resident_size`. La taille
// residente ignore la memoire compressee et la memoire des surfaces graphiques,
// que le decodage d une page produit en quantite. Un lecteur peut donc franchir
// la limite du systeme avec une taille residente rassurante, ce qui rendrait le
// budget de 400 Mo de la section 12 inoperant.
//

/// Ce qui empeche une mesure d aboutir.
public enum ErreurDeMesure: Error, Sendable, Equatable {
    /// Le noyau a refuse de rendre l empreinte du processus. La mesure est
    /// abandonnee plutot que remplacee par une valeur inventee, qui ferait
    /// passer un budget memoire sans rien avoir mesure.
    case empreinteIndisponible(code: Int32)

    /// Le jeu de test attendu a cet emplacement n a pas ete trouve. Il se
    /// genere avec scripts/generer-jeu-de-test.sh.
    case jeuDeTestAbsent(chemin: String)

    /// Le corpus existe mais ne porte pas ce que la mesure attend.
    case jeuDeTestIncomplet(raison: String)
}

/// Empreinte memoire du processus courant.
public enum EmpreinteMemoire {
    /// Octets que le systeme impute au processus a cet instant.
    ///
    /// - Throws: `ErreurDeMesure.empreinteIndisponible` quand le noyau refuse.
    public static func octetsUtilises() throws -> Int {
        var info = task_vm_info_data_t()
        var nombre = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )

        let code = withUnsafeMutablePointer(to: &info) { pointeur in
            pointeur.withMemoryRebound(to: integer_t.self, capacity: Int(nombre)) { reinterprete in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reinterprete, &nombre)
            }
        }

        guard code == KERN_SUCCESS else {
            throw ErreurDeMesure.empreinteIndisponible(code: code)
        }

        return Int(info.phys_footprint)
    }

    /// La meme empreinte, en mega octets, unite du tableau de la section 12.
    public static func megaOctetsUtilises() throws -> Double {
        try Double(octetsUtilises()) / 1_000_000
    }
}
