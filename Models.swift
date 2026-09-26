import Foundation

public struct Flight: Identifiable, Codable, Equatable {
    public var id: String
    public var airline: String
    public var provider: String
    public var origin: String
    public var destination: String
    public var date: Date
    public var departureHour: Int
    public var duration: Int
    public var stops: Int
    public var price: Double
    public init(id: String, airline: String, provider: String, origin: String, destination: String, date: Date, departureHour: Int, duration: Int, stops: Int, price: Double) {
        self.id = id; self.airline = airline; self.provider = provider; self.origin = origin; self.destination = destination; self.date = date; self.departureHour = departureHour; self.duration = duration; self.stops = stops; self.price = price
    }
}
public struct PricePoint: Codable, Identifiable {
    public var id = UUID()
    public var date: Date
    public var price: Double
    public init(date: Date = Date(), price: Double) { self.date = date; self.price = price }
}
public struct Watch: Codable, Identifiable {
    public var id: String { flight.id }
    public var flight: Flight
    public var history: [PricePoint]
    public var lastSummary: Date
    public init(flight: Flight) { self.flight = flight; history = [PricePoint(price: flight.price)]; lastSummary = Date() }
    public mutating func record(_ price: Double, now: Date = Date()) -> Bool {
        guard price.isFinite, price > 0 else { return false }
        let dropped = price < flight.price
        flight.price = price
        history.append(PricePoint(date: now, price: price))
        return dropped
    }
}
public enum FlightSort: String, CaseIterable { case price = "Lowest price", stops = "Fewest stops", departure = "Earliest departure" }
public func filterFlights(_ flights: [Flight], maxStops: Int, startHour: Int, endHour: Int, sort: FlightSort) -> [Flight] {
    flights.filter { $0.stops <= maxStops && $0.departureHour >= startHour && $0.departureHour <= endHour }.sorted {
        switch sort {
        case .price: return $0.price < $1.price
        case .stops: return $0.stops == $1.stops ? $0.price < $1.price : $0.stops < $1.stops
        case .departure: return $0.departureHour == $1.departureHour ? $0.price < $1.price : $0.departureHour < $1.departureHour
        }
    }
}
public enum DemoSearch {
    public static func flights(origin: String, destination: String, date: Date) -> [Flight] {
        (0..<12).map { i in
            Flight(id: "\(origin)-\(destination)-\(Int(date.timeIntervalSince1970 / 86400))-\(i)", airline: ["United", "Delta", "Lufthansa", "American"][i % 4], provider: ["Sample engine A", "Sample engine B"][i % 2], origin: origin, destination: destination, date: date, departureHour: 6 + i, duration: 480 + (i % 3) * 130, stops: i % 3, price: Double(420 + (i * 73) % 490))
        }
    }
}
