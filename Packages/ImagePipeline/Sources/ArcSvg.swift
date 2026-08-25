import CoreGraphics
import Foundation

//
// ArcSvg
//
// Conversion d un arc elliptique SVG en arc de Core Graphics.
//
// SVG decrit un arc par son point d arrivee, ses deux rayons, la rotation de
// l ellipse et deux drapeaux. Core Graphics le decrit par un centre, un rayon
// et deux angles. Le passage d une forme a l autre est celui de l annexe F.6.5
// de la specification SVG, et il n a rien d evident : c est lui qui decide
// laquelle des quatre ellipses possibles est tracee.
//
// L ellipse est obtenue en tracant un arc de cercle unite sous une
// transformation qui l etire aux deux rayons puis la fait tourner. Core
// Graphics applique la transformation aux points de l arc, la courbe reste
// donc exacte au lieu d etre approchee par des segments.
//

/// Arc elliptique tel que la commande `A` le decrit.
struct ArcSvg {
    let depart: CGPoint
    let arrivee: CGPoint
    let rayonX: Double
    let rayonY: Double

    /// Rotation de l ellipse, en degres.
    let rotation: Double

    /// Vrai pour l arc de plus de 180 degres.
    let grandArc: Bool

    /// Vrai pour le sens des angles croissants.
    let sensPositif: Bool

    /// Ajoute l arc au chemin, en partant du point courant.
    ///
    /// Un rayon nul degrade en segment, comme la specification l impose.
    func ajouter(a chemin: CGMutablePath) {
        guard rayonX != 0, rayonY != 0, depart != arrivee else {
            chemin.addLine(to: arrivee)
            return
        }

        guard let centre = centre() else {
            chemin.addLine(to: arrivee)
            return
        }

        var transformation = CGAffineTransform(translationX: centre.abscisse, y: centre.ordonnee)
        transformation = transformation.rotated(by: rotation * .pi / 180)
        transformation = transformation.scaledBy(x: centre.rayonX, y: centre.rayonY)

        chemin.addArc(
            center: .zero,
            radius: 1,
            startAngle: centre.angleDeDepart,
            endAngle: centre.angleDeDepart + centre.balayage,
            clockwise: centre.balayage < 0,
            transform: transformation
        )
    }

    /// Parametrage par le centre, annexe F.6.5.
    private struct Parametrage {
        let abscisse: Double
        let ordonnee: Double
        let rayonX: Double
        let rayonY: Double
        let angleDeDepart: Double
        let balayage: Double
    }

    private func centre() -> Parametrage? {
        let angle = rotation * .pi / 180
        let cosinus = cos(angle)
        let sinus = sin(angle)

        let demiEcartX = (depart.x - arrivee.x) / 2
        let demiEcartY = (depart.y - arrivee.y) / 2

        let xPrime = cosinus * demiEcartX + sinus * demiEcartY
        let yPrime = -sinus * demiEcartX + cosinus * demiEcartY

        // Deux rayons trop petits pour joindre les deux points sont agrandis
        // jusqu a ce qu ils y arrivent, plutot que refuses.
        var rx = abs(rayonX)
        var ry = abs(rayonY)
        let debordement = xPrime * xPrime / (rx * rx) + yPrime * yPrime / (ry * ry)

        if debordement > 1 {
            let facteur = debordement.squareRoot()
            rx *= facteur
            ry *= facteur
        }

        guard let centrePrime = centrePrime(rx: rx, ry: ry, xPrime: xPrime, yPrime: yPrime) else {
            return nil
        }

        let angleDeDepart = Self.angle(
            de: (1, 0),
            vers: ((xPrime - centrePrime.x) / rx, (yPrime - centrePrime.y) / ry)
        )

        return Parametrage(
            abscisse: cosinus * centrePrime.x - sinus * centrePrime.y + (depart.x + arrivee.x) / 2,
            ordonnee: sinus * centrePrime.x + cosinus * centrePrime.y + (depart.y + arrivee.y) / 2,
            rayonX: rx,
            rayonY: ry,
            angleDeDepart: angleDeDepart,
            balayage: balayage(rx: rx, ry: ry, xPrime: xPrime, yPrime: yPrime, centre: centrePrime)
        )
    }

    /// Centre exprime dans le repere de l ellipse redressee.
    private func centrePrime(rx: Double, ry: Double, xPrime: Double, yPrime: Double) -> CGPoint? {
        let carreRx = rx * rx
        let carreRy = ry * ry
        let denominateur = carreRx * yPrime * yPrime + carreRy * xPrime * xPrime

        guard denominateur > 0 else { return nil }

        let numerateur = max(0, carreRx * carreRy - denominateur)
        let signe: Double = grandArc == sensPositif ? -1 : 1
        let facteur = signe * (numerateur / denominateur).squareRoot()

        return CGPoint(
            x: facteur * rx * yPrime / ry,
            y: -facteur * ry * xPrime / rx
        )
    }

    /// Balayage angulaire, ramene dans l intervalle voulu par le drapeau de sens.
    private func balayage(
        rx: Double,
        ry: Double,
        xPrime: Double,
        yPrime: Double,
        centre: CGPoint
    ) -> Double {
        var valeur = Self.angle(
            de: ((xPrime - centre.x) / rx, (yPrime - centre.y) / ry),
            vers: ((-xPrime - centre.x) / rx, (-yPrime - centre.y) / ry)
        )

        if sensPositif == false, valeur > 0 {
            valeur -= 2 * .pi
        } else if sensPositif, valeur < 0 {
            valeur += 2 * .pi
        }

        return valeur
    }

    /// Angle oriente entre deux vecteurs.
    private static func angle(de premier: (Double, Double), vers second: (Double, Double)) -> Double {
        let produitScalaire = premier.0 * second.0 + premier.1 * second.1
        let normes = (premier.0 * premier.0 + premier.1 * premier.1).squareRoot()
            * (second.0 * second.0 + second.1 * second.1).squareRoot()

        guard normes > 0 else { return 0 }

        let cosinus = min(1, max(-1, produitScalaire / normes))
        let signe: Double = premier.0 * second.1 - premier.1 * second.0 < 0 ? -1 : 1

        return signe * acos(cosinus)
    }
}
