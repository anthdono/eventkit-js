struct JSON_EKSource: Codable {
    var title: String
    var sourceType: String
    var sourceIdentifier: String

    init() {
        sourceIdentifier = ""
        sourceType = ""
        title = ""
    }
}
