//
// Created by anthdono on 29/1/2023.
//

import EventKit
import Foundation

func EKSourcesToModel(ekSources: [EKSource]) -> [m_EKSource] {
    var sources = [m_EKSource]()
    for src in ekSources {
        var source = m_EKSource()
        source.sourceType = String(describing: src.sourceType)
        source.sourceIdentifier = String(describing: src.sourceIdentifier)
        source.title = src.title
        sources.append(source)
    }
    return sources
}

func ModelToEKSources(m_sources: [m_EKSource]) -> [EKSource] {
    var result = [EKSource]()

    for source in EKEventStore().sources {
        for m_source in m_sources {
            if m_source.sourceIdentifier == source.sourceIdentifier {
                result.append(source)
            }
        }
    }
    return result
}
