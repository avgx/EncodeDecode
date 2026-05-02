import Foundation

/// Subset of Axxon list payload; unknown JSON keys are ignored.
struct CameraListPage: Codable, Sendable, Equatable {
    struct Item: Codable, Sendable, Equatable {
        let display_name: String?
        let display_id: String?
    }

    let items: [Item]
    let next_page_token: String?
}
