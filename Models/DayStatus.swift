import Foundation
import SwiftUI

enum DayStatus: String, Codable, CaseIterable, Identifiable {
    case inOffice = "In Office"
    case remote = "Remote"
    case pto = "PTO"
    case holiday = "Holiday"
    case none = "None"
    
    var id: Self { self }
    
    var color: Color {
        switch self {
        case .inOffice: return Color(red: 0.18, green: 0.80, blue: 0.44)   // Emerald green
        case .remote:   return Color(red: 0.20, green: 0.60, blue: 0.96)   // Vivid blue
        case .pto:      return Color(red: 0.95, green: 0.55, blue: 0.15)   // Warm orange
        case .holiday:  return Color(red: 0.66, green: 0.33, blue: 0.83)   // Rich purple
        case .none:     return Color(red: 0.88, green: 0.88, blue: 0.90)   // Light gray
        }
    }
    
    var icon: String {
        switch self {
        case .inOffice: return "building.2.fill"
        case .remote:   return "house.fill"
        case .pto:      return "airplane"
        case .holiday:  return "star.fill"
        case .none:     return "minus"
        }
    }
    
    /// Only user-selectable statuses (excludes .none)
    static var selectable: [DayStatus] {
        [.inOffice, .remote, .pto, .holiday]
    }
}
