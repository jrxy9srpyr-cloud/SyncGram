import Foundation

/// Ambient background styles drawn by the SyncGram shader. Kept as `Int32` so the raw value can be
/// stored in defaults and in the portable session backup without depending on Swift's enum metadata.
public enum SyncGramShaderStyle: Int32, CaseIterable {
    case aurora = 0
    case waves = 1
    case pattern = 2
    case bubbles = 3
    case dunes = 4

    public var title: String {
        switch self {
        case .aurora:
            return "Аврора"
        case .waves:
            return "Волны"
        case .pattern:
            return "Узор"
        case .bubbles:
            return "Пузыри"
        case .dunes:
            return "Дюны"
        }
    }

    public var subtitle: String {
        switch self {
        case .aurora:
            return "Мягкие пятна тёплого света, медленно перетекающие по экрану."
        case .waves:
            return "Плавные линии, как след на воде."
        case .pattern:
            return "Тонкая геометрическая сетка, которая почти незаметно вращается."
        case .bubbles:
            return "Полупрозрачные пузыри, всплывающие в мягком свете."
        case .dunes:
            return "Тёплые песчаные полосы, как вечерние барханы."
        }
    }
}