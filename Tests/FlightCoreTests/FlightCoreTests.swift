import XCTest
@testable import FlightCore
final class FlightCoreTests: XCTestCase {
    func testFiltersAndSort() {
        let flights = DemoSearch.flights(origin: "ORD", destination: "LHR", date: Date())
        let results = filterFlights(flights, maxStops: 1, startHour: 8, endHour: 16, sort: .price)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.stops <= 1 && (8...16).contains($0.departureHour) })
        XCTAssertEqual(results.map(\.price), results.map(\.price).sorted())
    }
    func testDropUsesPreviousObservation() throws {
        var watch = Watch(flight: DemoSearch.flights(origin: "ORD", destination: "LHR", date: Date())[0])
        XCTAssertFalse(watch.record(500))
        XCTAssertTrue(watch.record(490))
        XCTAssertFalse(watch.record(490))
        XCTAssertFalse(watch.record(-1))
        XCTAssertEqual(watch.history.count, 4)
        let copy = try JSONDecoder().decode(Watch.self, from: JSONEncoder().encode(watch))
        XCTAssertEqual(copy.flight.price, 490)
        XCTAssertEqual(copy.history.count, 4)
    }
}
