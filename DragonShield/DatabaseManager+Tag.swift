import Foundation

extension DatabaseManager {
    func listTags(includeInactive: Bool = true) -> [TagRow] {
        TagRepository(connection: databaseConnection).listTags(includeInactive: includeInactive)
    }

    func createTag(code: String, displayName: String, color: String?, sortOrder: Int, active: Bool) -> TagRow? {
        TagRepository(connection: databaseConnection).createTag(
            code: code,
            displayName: displayName,
            color: color,
            sortOrder: sortOrder,
            active: active
        )
    }

    func updateTag(id: Int, code: String?, displayName: String?, color: String?, sortOrder: Int?, active: Bool?) -> Bool {
        TagRepository(connection: databaseConnection).updateTag(
            id: id,
            code: code,
            displayName: displayName,
            color: color,
            sortOrder: sortOrder,
            active: active
        )
    }

    func deleteTag(id: Int) -> Bool {
        TagRepository(connection: databaseConnection).deleteTag(id: id)
    }

    func reorderTags(idsInOrder: [Int]) -> Bool {
        TagRepository(connection: databaseConnection).reorderTags(idsInOrder: idsInOrder)
    }
}
