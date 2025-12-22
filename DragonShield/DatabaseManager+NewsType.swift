import Foundation

extension DatabaseManager {
    func listNewsTypes(includeInactive: Bool = true) -> [NewsTypeRow] {
        NewsTypeRepository(connection: databaseConnection).listNewsTypes(includeInactive: includeInactive)
    }

    func createNewsType(code: String, displayName: String, sortOrder: Int, active: Bool, color: String? = nil, icon: String? = nil) -> NewsTypeRow? {
        NewsTypeRepository(connection: databaseConnection).createNewsType(
            code: code,
            displayName: displayName,
            sortOrder: sortOrder,
            active: active,
            color: color,
            icon: icon
        )
    }

    func updateNewsType(id: Int, code: String?, displayName: String?, sortOrder: Int?, active: Bool?, color: String? = nil, icon: String? = nil) -> Bool {
        NewsTypeRepository(connection: databaseConnection).updateNewsType(
            id: id,
            code: code,
            displayName: displayName,
            sortOrder: sortOrder,
            active: active,
            color: color,
            icon: icon
        )
    }

    func deleteNewsType(id: Int) -> Bool {
        NewsTypeRepository(connection: databaseConnection).deleteNewsType(id: id)
    }

    func reorderNewsTypes(idsInOrder: [Int]) -> Bool {
        NewsTypeRepository(connection: databaseConnection).reorderNewsTypes(idsInOrder: idsInOrder)
    }
}
