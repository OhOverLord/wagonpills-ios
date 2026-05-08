struct Region: Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    let isEnabled: Bool

    var id: String { code }
}
