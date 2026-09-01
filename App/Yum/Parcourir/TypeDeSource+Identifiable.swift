import Core

//
// `sheet(item:)` demande un `Identifiable`, et le type de source en est un
// naturellement : sa representation textuelle est deja son identite, celle qui
// est ecrite en base.
//

extension TypeDeSource: @retroactive Identifiable {
    public var id: String {
        rawValue
    }
}
