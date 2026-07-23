import Foundation

@testable import DiskMeerkatApp

let englishLocalization = DiskMeerkatLocalization.english

func resolvedEnglish(_ resource: LocalizedStringResource) -> String {
    englishLocalization.resolve(resource)
}

func resolvedEnglish(_ resource: LocalizedStringResource?) -> String? {
    resource.map(resolvedEnglish)
}
