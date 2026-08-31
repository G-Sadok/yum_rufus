import BudgetsDePerformance
import Foundation

//
// mesurer-budgets
//
// Genere le corpus de la section 12, mesure les sept budgets, et sort en erreur
// des qu un seul deborde.
//
// Trois sous commandes :
//
//   generer <racine>          materialise le corpus depuis le manifeste suivi
//   mesurer <racine>          lance les sept mesures, une par processus fils
//   mesurer-une <cle> <racine>  une seule mesure, dans ce processus
//
// La troisieme existe pour la deuxieme. Deux des sept budgets sont des budgets
// memoire, et une empreinte se mesure sur un processus entier : mesurer la
// memoire au repos apres avoir lu un chapitre dans le meme processus releverait
// l empreinte du chapitre. Chaque budget est donc mesure dans un processus qui
// n a rien fait d autre, et le processus pere se contente de comparer.
//

/// Ce que la ligne de commande demande.
enum Commande {
    case generer(racine: URL)
    case mesurer(racine: URL)
    case mesurerUne(cle: CleDeBudget, racine: URL)
}

/// Sortie standard, sans tampon, pour que la progression suive l execution.
func afficher(_ ligne: String) {
    print(ligne)
    fflush(stdout)
}

func afficherSurLErreur(_ ligne: String) {
    FileHandle.standardError.write(Data((ligne + "\n").utf8))
}

func lireLaCommande(_ arguments: [String]) -> Commande? {
    guard arguments.count >= 3 else {
        return nil
    }

    let racine = URL(fileURLWithPath: arguments[2], isDirectory: true)

    switch arguments[1] {
    case "generer":
        return .generer(racine: racine)
    case "mesurer":
        return .mesurer(racine: racine)
    case "mesurer-une":
        guard arguments.count >= 4, let cle = CleDeBudget(rawValue: arguments[2]) else {
            return nil
        }

        return .mesurerUne(cle: cle, racine: URL(fileURLWithPath: arguments[3], isDirectory: true))
    default:
        return nil
    }
}

func mode(_ arguments: [String]) -> String {
    """
    Usage :
      \(arguments[0]) generer <racine du depot>
      \(arguments[0]) mesurer <racine du depot>
      \(arguments[0]) mesurer-une <\(CleDeBudget.allCases.map(\.rawValue).joined(separator: "|"))> <racine>
    """
}

// MARK: Generation

func generer(racine: URL) throws {
    let emplacement = EmplacementDuJeuDeTest.parDefaut(racineDuDepot: racine)
    let manifeste = try emplacement.lireLeManifeste()

    afficher("Corpus de \(manifeste.series) series et \(manifeste.chapitres) chapitres")

    let resultat = try GenerateurDeJeuDeTest.materialiser(manifeste, vers: emplacement, journal: afficher)

    afficher("Corpus ecrit dans \(resultat.base.path)")
}

// MARK: Mesure d un seul budget

func mesurerUne(cle: CleDeBudget, racine: URL) throws {
    let emplacement = EmplacementDuJeuDeTest.parDefaut(racineDuDepot: racine)
    let campagne = CampagneDeBudgets(emplacement: emplacement)
    let mesure = try campagne.mesurer(cle)
    let octets = try JSONEncoder().encode(mesure)

    guard let texte = String(data: octets, encoding: .utf8) else {
        throw ErreurDeMesure.jeuDeTestIncomplet(raison: "mesure inencodable")
    }

    afficher(texte)
}

// MARK: Campagne complete

/// Lance la mesure d un budget dans un processus fils et lit son rapport.
func mesurerDansUnFils(_ cle: CleDeBudget, racine: URL, executable: URL) throws -> MesureDeBudget {
    let processus = Process()
    let tuyau = Pipe()

    processus.executableURL = executable
    processus.arguments = ["mesurer-une", cle.rawValue, racine.path]
    processus.standardOutput = tuyau
    processus.standardError = FileHandle.standardError

    try processus.run()
    let sortie = tuyau.fileHandleForReading.readDataToEndOfFile()
    processus.waitUntilExit()

    guard processus.terminationStatus == 0 else {
        throw ErreurDeCampagne.mesureInterrompue(cle: cle, code: processus.terminationStatus)
    }

    guard let texte = String(bytes: sortie, encoding: .utf8),
          let derniere = texte.split(separator: "\n").last.map({ Data($0.utf8) })
    else {
        throw ErreurDeCampagne.mesureMuette(cle: cle)
    }

    return try JSONDecoder().decode(MesureDeBudget.self, from: derniere)
}

/// Ce qui peut faire echouer la campagne elle meme, avant tout depassement.
enum ErreurDeCampagne: Error {
    case mesureInterrompue(cle: CleDeBudget, code: Int32)
    case mesureMuette(cle: CleDeBudget)
}

func mesurerTout(racine: URL, executable: URL) throws -> Int32 {
    var lignes: [LigneDeRapport] = []

    for budget in BudgetDePerformance.section12 {
        afficher("Mesure : \(budget.libelle)")

        let mesure = try mesurerDansUnFils(budget.cle, racine: racine, executable: executable)
        lignes.append(LigneDeRapport(budget: budget, mesure: mesure))
    }

    let rapport = RapportDeBudgets(lignes: lignes)

    afficher("")
    afficher("Budgets de la section 12")
    afficher("")

    for ligne in rapport.lignes {
        afficher("  " + ligne.texte)
        afficher("           \(ligne.mesure.detail)")
    }

    afficher("")

    guard rapport.completEtTenu else {
        for ligne in rapport.depassements {
            afficherSurLErreur("Budget depasse : \(ligne.texte)")
        }

        for cle in rapport.nonMesures {
            afficherSurLErreur("Budget non mesure : \(cle.rawValue)")
        }

        return 1
    }

    afficher("Les sept budgets de la section 12 sont tenus.")

    return 0
}

// MARK: Point d entree

let arguments = CommandLine.arguments

guard let commande = lireLaCommande(arguments) else {
    afficherSurLErreur(mode(arguments))
    exit(2)
}

do {
    switch commande {
    case let .generer(racine):
        try generer(racine: racine)
    case let .mesurerUne(cle, racine):
        try mesurerUne(cle: cle, racine: racine)
    case let .mesurer(racine):
        // Le pere relance sa propre image pour chaque budget. Le chemin vient du
        // paquet et non de arguments[0], qui peut n etre qu un nom trouve dans
        // le PATH, donc inutilisable comme executable de processus fils.
        let executable = Bundle.main.executableURL
            ?? URL(fileURLWithPath: arguments[0]).resolvingSymlinksInPath()

        try exit(mesurerTout(racine: racine, executable: executable))
    }
} catch {
    afficherSurLErreur("La campagne a echoue : \(error)")
    exit(1)
}
