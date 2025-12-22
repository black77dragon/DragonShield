import Foundation

extension DatabaseManager {
    func listAlertTriggerTypes(includeInactive: Bool = true) -> [AlertTriggerTypeRow] {
        AlertTriggerTypeRepository(connection: databaseConnection).listAlertTriggerTypes(includeInactive: includeInactive)
    }

    func createAlertTriggerType(code: String, displayName: String, description: String?, sortOrder: Int, active: Bool, requiresDate: Bool) -> AlertTriggerTypeRow? {
        AlertTriggerTypeRepository(connection: databaseConnection).createAlertTriggerType(
            code: code,
            displayName: displayName,
            description: description,
            sortOrder: sortOrder,
            active: active,
            requiresDate: requiresDate
        )
    }

    func updateAlertTriggerType(id: Int, code: String?, displayName: String?, description: String?, sortOrder: Int?, active: Bool?, requiresDate: Bool? = nil) -> Bool {
        AlertTriggerTypeRepository(connection: databaseConnection).updateAlertTriggerType(
            id: id,
            code: code,
            displayName: displayName,
            description: description,
            sortOrder: sortOrder,
            active: active,
            requiresDate: requiresDate
        )
    }

    func deleteAlertTriggerType(id: Int) -> Bool {
        AlertTriggerTypeRepository(connection: databaseConnection).deleteAlertTriggerType(id: id)
    }

    func reorderAlertTriggerTypes(idsInOrder: [Int]) -> Bool {
        AlertTriggerTypeRepository(connection: databaseConnection).reorderAlertTriggerTypes(idsInOrder: idsInOrder)
    }
}
