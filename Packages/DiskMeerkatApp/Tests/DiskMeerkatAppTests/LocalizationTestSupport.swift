import Foundation

@testable import DiskMeerkatApp

let englishLocalization = DiskMeerkatLocalization.english
let simplifiedChineseLocalization = DiskMeerkatLocalization.simplifiedChinese

func resolvedEnglish(_ resource: LocalizedStringResource) -> String {
    englishLocalization.resolve(resource)
}

func resolvedEnglish(_ resource: LocalizedStringResource?) -> String? {
    resource.map(resolvedEnglish)
}

func resolvedSimplifiedChinese(_ resource: LocalizedStringResource) -> String {
    simplifiedChineseLocalization.resolve(resource)
}

func resolvedSimplifiedChinese(_ resource: LocalizedStringResource?) -> String? {
    resource.map(resolvedSimplifiedChinese)
}
