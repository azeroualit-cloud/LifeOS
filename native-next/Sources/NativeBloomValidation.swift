import Foundation

enum NativeBloomValidation {
    static func validate(_ archive: NativeBloomArchive) throws {
        func invalid() -> Message { Message(text: "Il backup Bloom contiene metadati non validi o incompleti.") }
        func number(_ row: Record, _ key: String, required: Bool = false) throws {
            guard let value = row[key], value != .null else { if required { throw invalid() }; return }
            guard case .number(let n) = value, n.isFinite else { throw invalid() }
        }
        func string(_ row: Record, _ key: String, required: Bool = false) throws {
            guard let value = row[key], value != .null else { if required { throw invalid() }; return }
            guard case .string = value else { throw invalid() }
        }
        func uuid(_ row: Record, _ key: String, required: Bool = false) throws {
            guard let value = row[key], value != .null else { if required { throw invalid() }; return }
            guard case .string(let raw) = value, UUID(uuidString: raw) != nil else { throw invalid() }
        }
        func ids(_ row: Record, _ key: String) throws -> [String]? {
            guard let value = row[key], value != .null else { return nil }
            guard case .array(let values) = value else { throw invalid() }
            return try values.map { value in
                guard case .string(let raw) = value, UUID(uuidString: raw) != nil else { throw invalid() }; return raw
            }
        }
        func url(_ raw: String) throws {
            guard raw.utf8.count <= 1024 * 1024, let value = URL(string: raw), ["http", "https"].contains(value.scheme?.lowercased() ?? ""), value.host?.isEmpty == false else { throw invalid() }
        }
        func framing(_ value: JSONValue?) throws {
            guard let value, value != .null else { return }
            guard case .object(let row) = value else { throw invalid() }
            for key in ["top", "bottom", "left", "right"] {
                try number(row,key,required: true)
                guard (0...0.8).contains(row.amount(key)) else { throw invalid() }
            }
            guard row.amount("top") + row.amount("bottom") <= 0.9, row.amount("left") + row.amount("right") <= 0.9 else { throw invalid() }
        }
        guard archive.createdAt.isFinite else { throw invalid() }
        let categories = Set(archive.collections.map { $0.text("id") })
        for category in archive.collections {
            try string(category,"name",required:true)
            try uuid(category,"id",required:true); try number(category,"createdAt",required:true); try number(category,"modifiedAt")
            guard category.text("name").utf8.count <= 1024 else { throw invalid() }
        }
        for item in archive.items {
            for key in ["title", "notes", "text", "fileName", "contentType"] { try string(item,key) }
            try string(item,"urlString",required:true)
            try uuid(item,"id",required:true); try uuid(item,"collectionID")
            try number(item,"capturedAt",required:true); try number(item,"modifiedAt"); try number(item,"trashedAt")
            guard case .bool? = item["archived"] else { throw invalid() }
            if let version = item["noteVersion"], version != .null { guard version == .number(1) else { throw invalid() } }
            let tags = try ids(item,"tagIDs") ?? (item.text("collectionID").isEmpty ? [] : [item.text("collectionID")])
            let pinned = try ids(item,"pinnedCategoryIDs") ?? []
            guard tags.allSatisfy(categories.contains), pinned.allSatisfy(tags.contains), item.text("collectionID").isEmpty || categories.contains(item.text("collectionID")) else { throw invalid() }
            for key in ["title", "urlString", "fileName", "contentType"] { guard item.text(key).utf8.count <= 1024 * 1024 else { throw invalid() } }
            try framing(item["imageFraming"])
            if let value = item["place"], value != .null {
                guard case .object(let place) = value, !place.text("name").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, place.text("name").utf8.count <= 4096 else { throw invalid() }
                try string(place,"kind")
                try number(place,"latitude",required:true); try number(place,"longitude",required:true)
                guard (-90...90).contains(place.amount("latitude")), (-180...180).contains(place.amount("longitude")) else { throw invalid() }
            }
            var linkCount = 0
            if let value = item["noteLinks"], value != .null {
                guard case .array(let links) = value else { throw invalid() }
                linkCount = links.count
                for link in links { guard case .string(let raw) = link else { throw invalid() }; try url(raw) }
            }
            var fileIDs = Set<String>()
            if let value = item["noteFiles"], value != .null {
                guard case .array(let files) = value, files.count + linkCount <= 10 else { throw invalid() }
                for file in files {
                    guard case .object(let row) = file, row["lifeosFileSHA256"] == nil else { throw invalid() }
                    try uuid(row,"id",required:true)
                    guard fileIDs.insert(row.text("id")).inserted, !row.text("name").isEmpty, row.text("name").utf8.count <= 1024, !row.text("type").isEmpty, row.text("type").utf8.count <= 1024,
                          case .string(let raw)? = row["data"], Data(base64Encoded: raw) != nil else { throw invalid() }
                    try framing(row["framing"])
                }
            } else if linkCount > 10 { throw invalid() }
            switch item.text("kind") {
            case "link": try url(item.text("urlString")); guard (item["text"] == nil || item["text"] == .null) && (item["data"] == nil || item["data"] == .null) else { throw invalid() }
            case "text":
                guard case .string? = item["text"], item.text("urlString").isEmpty, item["data"] == nil || item["data"] == .null else { throw invalid() }
                guard !item.text("text").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !item.text("title").isEmpty || linkCount > 0 || !fileIDs.isEmpty else { throw invalid() }
            case "file", "image": guard item["text"] == nil || item["text"] == .null, !item.text("fileName").isEmpty, item.text("urlString").isEmpty, case .string(let raw)? = item["data"], Data(base64Encoded: raw) != nil else { throw invalid() }
            default: throw invalid()
            }
        }
    }
}
