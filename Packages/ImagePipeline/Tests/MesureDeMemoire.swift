// Import en mode pre concurrence, pour la meme raison que dans
// `EmpreinteMemoire` : `mach_task_self_` est une variable globale du noyau que
// la concurrence stricte de Swift 6 refuse de lire, ce qui faisait echouer la
// compilation partout sauf sur la machine de developpement.
@preconcurrency import Darwin
import Foundation

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
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), champs, &nombreDeChamps)
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
