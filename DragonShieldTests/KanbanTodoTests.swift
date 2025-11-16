@testable import DragonShield
import XCTest

@MainActor
final class KanbanTodoTests: XCTestCase {
    func testKanbanTodoDecodingDefaults() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "description": "Legacy todo",
            "priority": "medium",
            "dueDate": "2024-12-31T00:00:00Z",
            "column": "backlog",
            "tagIDs": [],
            "sortOrder": 0,
            "createdAt": "2024-12-01T00:00:00Z"
        }
        """
        let data = Data(json.utf8)

        let todo = try JSONDecoder.iso8601Decoder().decode(KanbanTodo.self, from: data)

        XCTAssertFalse(todo.isCompleted)
        XCTAssertNil(todo.repeatFrequency)
    }

    func testRepeatCompletionReschedulesFromToday() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = KanbanBoardViewModel(userDefaults: defaults)

        let due = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        viewModel.create(description: "Weekly invoice",
                         priority: .medium,
                         dueDate: due,
                         column: .doing,
                         tagIDs: [],
                         isCompleted: false,
                         repeatFrequency: .weekly)

        guard let todoID = viewModel.allTodos.first?.id else {
            XCTFail("Expected freshly created todo")
            return
        }

        let completionDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 10))!
        viewModel.setCompletion(for: todoID, isCompleted: true, completionDate: completionDate)

        guard let updated = viewModel.allTodos.first else {
            XCTFail("Missing todo after completion")
            return
        }

        let expectedDue = KanbanRepeatFrequency.weekly.nextDueDate(from: completionDate)
        guard let dueDate = updated.dueDate else {
            XCTFail("Expected repeating todo to reschedule with new due date")
            return
        }
        XCTAssertEqual(dueDate.timeIntervalSince1970,
                       expectedDue.timeIntervalSince1970,
                       accuracy: 1.0,
                       "Expected due date plus seven days")
        XCTAssertFalse(updated.isCompleted, "Repeating todo should reset completion flag")

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testArchiveBlockedWhenRepeatingTodoInDone() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = KanbanBoardViewModel(userDefaults: defaults)

        let due = Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 1))!
        viewModel.create(description: "Repeating done item",
                         priority: .high,
                         dueDate: due,
                         column: .done,
                         tagIDs: [],
                         isCompleted: false,
                         repeatFrequency: .monthly)

        viewModel.archiveDoneTodos()

        XCTAssertTrue(viewModel.archiveBlockedByRepeatingTodos)
        XCTAssertEqual(viewModel.todos(in: .done).count, 1, "Repeating todo should stay in Done column")

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testArchiveSucceedsForNonRepeatingTodos() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = KanbanBoardViewModel(userDefaults: defaults)

        let due = Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 1))!
        viewModel.create(description: "Done item",
                         priority: .low,
                         dueDate: due,
                         column: .done,
                         tagIDs: [],
                         isCompleted: true,
                         repeatFrequency: nil)

        guard let todoID = viewModel.allTodos.first?.id else {
            XCTFail("Expected todo identifier")
            return
        }

        viewModel.setCompletion(for: todoID, isCompleted: true, completionDate: due)
        viewModel.archiveDoneTodos()

        XCTAssertFalse(viewModel.archiveBlockedByRepeatingTodos)
        XCTAssertEqual(viewModel.todos(in: .done).count, 0)
        XCTAssertEqual(viewModel.todos(in: .archived).count, 1, "Todo should move to archived once not repeating")

        defaults.removePersistentDomain(forName: suiteName)
    }
}

private extension JSONDecoder {
    static func iso8601Decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
