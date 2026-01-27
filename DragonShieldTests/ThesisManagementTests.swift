@testable import DragonShield
import XCTest

final class ThesisManagementTests: XCTestCase {
    func testKpiCapsEnforced() throws {
        let store = ThesisStore()
        guard let thesis = store.theses.first else {
            XCTFail("Missing seed thesis")
            return
        }
        var added = thesis.primaryKPIs.count
        while added < 5 {
            let def = KPIDefinition(
                id: "\(thesis.id)_extra_primary_\(added)",
                name: "Extra Primary \(added)",
                unit: "u",
                description: "extra",
                isPrimary: true,
                direction: .higherIsBetter,
                ranges: KPIRangeSet(
                    green: .init(lower: 1, upper: 2),
                    amber: .init(lower: 0.5, upper: 0.99),
                    red: .init(lower: 0, upper: 0.49)
                )
            )
            let result = store.addKPI(to: thesis.id, definition: def)
            XCTAssertTrue(result.isSuccess, "Should allow adding until cap")
            added += 1
        }
        let overflow = KPIDefinition(
            id: "\(thesis.id)_overflow",
            name: "Overflow",
            unit: "u",
            description: "overflow",
            isPrimary: true,
            direction: .higherIsBetter,
            ranges: KPIRangeSet(
                green: .init(lower: 1, upper: 2),
                amber: .init(lower: 0.5, upper: 0.99),
                red: .init(lower: 0, upper: 0.49)
            )
        )
        let capped = store.addKPI(to: thesis.id, definition: overflow)
        if case .failure(let error) = capped {
            XCTAssertEqual(error, .kpiCapExceeded)
        } else {
            XCTFail("Expected cap enforcement")
        }
    }

    func testWeeklyReviewImmutability() throws {
        let store = ThesisStore()
        guard let thesis = store.theses.first else { XCTFail("Missing thesis"); return }
        let week = WeekNumber.current()
        guard var draft = store.startDraft(thesisId: thesis.id, week: week) else { XCTFail("No draft"); return }
        draft.headline = "First"
        fillPrimaryValues(in: &draft, thesis: thesis, value: 10)
        let saveResult = store.save(review: draft, finalize: true)
        guard case .success(let finalized) = saveResult else {
            XCTFail("Finalize failed"); return
        }
        var mutated = finalized
        mutated.headline = "Changed"
        let second = store.save(review: mutated, finalize: false)
        if case .failure(let error) = second {
            XCTAssertEqual(error, .reviewFinalized)
        } else {
            XCTFail("Expected immutable finalized review")
        }
    }

    func testPatchValidationAndIdempotency() throws {
        let store = ThesisStore()
        guard let thesis = store.theses.first,
              let kpiId = thesis.primaryKPIs.first?.id
        else { XCTFail("Missing thesis/kpi"); return }
        let invalidPatch = """
        {"schema":"weekly_review_patch_v1","patch_id":"p-1","generated_at":"2026-01-01T00:00:00Z","model":"gpt","thesis_id":"\(thesis.id)","week":"2026-W04","summary":{"headline":"Invalid","overall_status":"green","confidence_score":4,"assumptions_status":[]},"kpis":[{"kpi_id":"unknown","current_value":1.0}],"events":{"macro_events":[],"micro_events":[]},"decision":{"action":"Hold","rationale":[],"watch_items":[]},"integrity":{"incomplete_kpis":[],"range_breaches":[],"notes":""}}
        """
        let invalidResult = store.validatePatch(json: invalidPatch)
        XCTAssertFalse(invalidResult.errors.isEmpty)

        let validDict: [String: Any] = [
            "schema": "weekly_review_patch_v1",
            "patch_id": "p-2",
            "generated_at": "2026-01-02T00:00:00Z",
            "model": "gpt",
            "thesis_id": thesis.id,
            "week": "2026-W05",
            "summary": [
                "headline": "Valid patch",
                "overall_status": "amber",
                "confidence_score": 4,
                "assumptions_status": []
            ],
            "kpis": [
                [
                    "kpi_id": kpiId,
                    "current_value": 12.3,
                    "trend": "up",
                    "delta_1w": 0.5,
                    "delta_4w": 1.0,
                    "rag_status": "green",
                    "comment": "LLM provided"
                ]
            ],
            "events": ["macro_events": [], "micro_events": []],
            "decision": ["action": "Hold", "rationale": ["stable"], "watch_items": []],
            "integrity": ["incomplete_kpis": [], "range_breaches": [], "notes": ""]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: validDict, options: [])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { XCTFail("Encoding failed"); return }
        let validation = store.validatePatch(json: jsonString)
        XCTAssertTrue(validation.errors.isEmpty)
        let applied = store.applyPatch(json: jsonString, finalize: false)
        XCTAssertNotNil(applied.review)
        let countAfterFirst = store.reviews.count
        let duplicate = store.applyPatch(json: jsonString, finalize: false)
        XCTAssertTrue(duplicate.isDuplicate)
        XCTAssertEqual(countAfterFirst, store.reviews.count, "Duplicate patch should not add review")
    }

    func testRagComputationFromRanges() {
        let ranges = KPIRangeSet(
            green: .init(lower: 10, upper: 20),
            amber: .init(lower: 5, upper: 9),
            red: .init(lower: 0, upper: 4)
        )
        XCTAssertEqual(ranges.status(for: 15), .green)
        XCTAssertEqual(ranges.status(for: 7), .amber)
        XCTAssertEqual(ranges.status(for: 2), .red)
    }

    func testDraftVersusFinalizedBehavior() {
        let store = ThesisStore()
        guard let thesis = store.theses.first else { XCTFail("Missing thesis"); return }
        let week = WeekNumber.current()
        guard var draft = store.startDraft(thesisId: thesis.id, week: week) else { XCTFail("No draft"); return }
        // attempt to finalize with missing primary values
        let failFinalize = store.save(review: draft, finalize: true)
        if case .failure(let error) = failFinalize {
            XCTAssertEqual(error, .primaryKPIIncomplete(thesis.primaryKPIs.map(\.id)))
        } else {
            XCTFail("Expected primary KPI validation to fail")
        }
        fillPrimaryValues(in: &draft, thesis: thesis, value: thesis.primaryKPIs.first?.ranges.green.lower ?? 1)
        let success = store.save(review: draft, finalize: true)
        if case .success(let finalized) = success {
            XCTAssertNotNil(finalized.finalizedAt)
        } else {
            XCTFail("Finalize should succeed once primary KPIs provided")
        }
    }

    private func fillPrimaryValues(in review: inout WeeklyReview, thesis: Thesis, value: Double) {
        for id in thesis.primaryKPIs.map(\.id) {
            if let idx = review.kpiReadings.firstIndex(where: { $0.kpiId == id }) {
                review.kpiReadings[idx].currentValue = value
            }
        }
    }
}

private extension Result where Failure == ThesisStoreError {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
