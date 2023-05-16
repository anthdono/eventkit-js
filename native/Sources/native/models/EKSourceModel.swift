import EventKit

struct EKSourceModel: Codable {
    var title: String
    var sourceType: Int
    var sourceIdentifier: String

    init() {
        sourceIdentifier = ""
        sourceType = -1
        title = ""
    }

    init(from: EKSource) {
        sourceType = from.sourceType.rawValue
        sourceIdentifier = String(describing: from.sourceIdentifier)
        title = from.title
    }

    public func toBuiltin() -> EKSource? {
        for source in EKEventStore().sources {
            if sourceIdentifier == source.sourceIdentifier {
                return source
            }
        }
        return nil
    }
}
