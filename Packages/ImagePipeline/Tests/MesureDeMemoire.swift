import Darwin
import Foundation

/// Port de la tache courante, lu une seule fois.
///
/// Meme raison que dans `EmpreinteMemoire` : lire `mach_task_self_` a chaque
/// appel passe ici et echoue sur le compilateur de l integration continue, qui
/// applique la concurrence stricte de Swift 6 a la lettre.
private let tacheCourante: task_t = mach_task_self_

//
// MesureDeMemoire
//
// Empreinte memoire physique du processus, telle que le systeme la compte.
//
// C est la meme grandeur que celle affichee par Instruments sous le nom de
// footprint, et celle sur laquelle porte le budget de 400 Mo en lecture de la
// section 12. Mesurer la somme des tailles annoncees par nos structures ne
// dirait rien des matrices allouees par Image I/O, qui sont precisement ce que
// la fonctionnalite doit contenir.
//

enum MesureDeMemoire {
    /// Empreinte physique du processus en octets, zero si le noyau refuse.
    static func octets() -> Int {
        var informations = task_vm_info_data_t()
        var nombreDeChamps = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )

        let resultat = withUnsafeMutablePointer(to: &informations) { pointeur in
            pointeur.withMemoryRebound(to: integer_t.self, capacity: Int(nombreDeChamps)) { champs in
                task_info(tacheCourante, task_flavor_t(TASK_VM_INFO), champs, &nombreDeChamps)
            }
        }

        guard resultat == KERN_SUCCESS else {
            return 0
        }

        return Int(informations.phys_footprint)
    }

    /// Variation d empreinte pendant l execution du bloc, en octets.
    ///
    /// La variation peut etre negative, un autre fil pouvant liberer de la
    /// memoire pendant la mesure. L appelant compare donc a un seuil, il ne
    /// suppose jamais un signe.
    static func variation(pendant bloc: () throws -> Void) rethrows -> Int {
        let avant = octets()
        try bloc()

        return octets() - avant
    }
}
