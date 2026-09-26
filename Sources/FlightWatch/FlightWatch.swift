import SwiftUI
import UserNotifications
import Charts
import FlightCore

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

@MainActor final class Store: ObservableObject {
    @Published var watches: [Watch] = []
    @Published var notice = ""
    @Published var hours = 24.0 { didSet { UserDefaults.standard.set(hours, forKey: "summaryHours") } }
    private let file: URL
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FlightWatch")
        file = folder.appendingPathComponent("watches.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { watches = try JSONDecoder().decode([Watch].self, from: Data(contentsOf: file)) }
        } catch { notice = "Could not load saved flights: \(error.localizedDescription)" }
        if UserDefaults.standard.double(forKey: "summaryHours") > 0 { hours = UserDefaults.standard.double(forKey: "summaryHours") }
    }
    func save() {
        do { try JSONEncoder().encode(watches).write(to: file, options: .atomic) }
        catch { notice = "Could not save flights: \(error.localizedDescription)" }
    }
    func toggle(_ f: Flight) {
        if let index = watches.firstIndex(where: { $0.id == f.id }) { watches.remove(at: index) }
        else { watches.append(Watch(flight: f)) }
        save()
    }
    func enableNotifications() async {
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            notice = allowed ? "Mac notifications enabled. Try a simulated price drop." : "Notifications are disabled. Enable FlightWatch in System Settings."
        } catch { notice = error.localizedDescription }
    }
    func simulateDrop(_ id: String) async {
        guard let index = watches.firstIndex(where: { $0.id == id }) else { return }
        let old = watches[index].flight.price
        let dropped = watches[index].record((old * 0.9 * 100).rounded() / 100)
        let f = watches[index].flight
        save()
        if dropped {
            let content = UNMutableNotificationContent()
            content.title = "Demo price drop: \(f.origin) → \(f.destination)"
            content.body = String(format: "Sample fare fell from $%.2f to $%.2f. This is a test, not a live fare.", old, f.price)
            content.sound = .default
            do { try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)); notice = "Demo drop recorded; notification requested." }
            catch { notice = "Drop recorded. Notification failed: \(error.localizedDescription)" }
        }
    }
}

@main struct FlightWatchApp: App {
    @StateObject private var store = Store()
    var body: some Scene { WindowGroup { ContentView().environmentObject(store) } }
}
struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var section = "Search"
    @State private var origin = "ORD"
    @State private var destination = "LHR"
    @State private var date = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    @State private var flights: [Flight] = []
    @State private var sort = FlightSort.price
    @State private var stops = 2
    @State private var start = 0
    @State private var end = 23
    @State private var error = ""
    var results: [Flight] { filterFlights(flights, maxStops: stops, startHour: start, endHour: end, sort: sort) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Image(systemName: "airplane.circle.fill").font(.largeTitle).foregroundStyle(.teal); VStack(alignment: .leading) { Text("FlightWatch").font(.largeTitle.bold()); Text("Find your flight. Follow the fare.").foregroundStyle(.secondary) }; Spacer() }
                    Picker("Workspace", selection: $section) { Text("Search flights").tag("Search"); Text("Tracking (\(store.watches.count))").tag("Tracking"); Text("Preferences").tag("Preferences") }.pickerStyle(.segmented)
                    Label("DEMO MODE · Sample fares only · No live monitoring connected", systemImage: "info.circle").font(.callout).foregroundStyle(.orange)
                    if section == "Search" { searchView }
                    else if section == "Tracking" { trackingView }
                    else { preferences }
                    if !store.notice.isEmpty { Text(store.notice).font(.callout).foregroundStyle(.secondary) }
                }.padding(28).frame(maxWidth: 1100)
            }.background(Color.primary.opacity(0.025))
            .navigationTitle("")
        }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 650)
        #endif
    }
    var searchView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Where are you heading?").font(.title2.bold())
            ViewThatFits {
                HStack { routeFields }
                VStack { routeFields }
            }
            DatePicker("Departure", selection: $date, in: Date()..., displayedComponents: .date)
            Button { search() } label: { Label("Search sample flights", systemImage: "magnifyingglass").frame(maxWidth: .infinity).padding(8) }.buttonStyle(.borderedProminent).tint(.teal)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            Divider()
            Picker("Sort by", selection: $sort) { ForEach(FlightSort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Picker("Connections", selection: $stops) { Text("Nonstop").tag(0); Text("Up to 1 stop").tag(1); Text("Up to 2 stops").tag(2) }
            HStack {
                Picker("Depart after", selection: $start) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                Picker("Depart before", selection: $end) { ForEach(0..<24) { Text(String(format: "%02d:59", $0)).tag($0) } }
            }
            Text("Departure times are local to the origin. One adult · Economy · One way · USD").font(.caption).foregroundStyle(.secondary)
            Text("\(results.count) flights").font(.headline)
            if results.isEmpty { Text(flights.isEmpty ? "Choose your route and search to compare sample fares." : "No flights match these filters.").foregroundStyle(.secondary).padding(.vertical, 24) }
            ForEach(results) { flight in flightCard(flight) }
        }
    }
    var routeFields: some View { Group { TextField("From (IATA, e.g. ORD)", text: $origin); Image(systemName: "arrow.right"); TextField("To (IATA, e.g. LHR)", text: $destination) }.textFieldStyle(.roundedBorder) }
    func search() {
        origin = origin.trimmingCharacters(in: .whitespaces).uppercased(); destination = destination.trimmingCharacters(in: .whitespaces).uppercased()
        guard origin.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil, destination.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil, origin != destination else { error = "Enter two different three-letter airport codes."; return }
        guard start <= end else { error = "Departure start must be before the end time."; return }
        error = ""; flights = DemoSearch.flights(origin: origin, destination: destination, date: date)
    }
    func flightCard(_ f: Flight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(f.airline).font(.headline); Spacer(); Text(f.price, format: .currency(code: "USD")).font(.title2.bold()).foregroundStyle(.teal) }
            Text("\(f.origin) → \(f.destination)  ·  \(f.date.formatted(date: .abbreviated, time: .omitted))")
            Text(String(format: "%02d:00 departure · %dh %dm · %@", f.departureHour, f.duration / 60, f.duration % 60, f.stops == 0 ? "Nonstop" : "\(f.stops) stop(s)")).foregroundStyle(.secondary)
            HStack { Text(f.provider).font(.caption); Spacer(); Button(store.watches.contains(where: { $0.id == f.id }) ? "Stop tracking" : "Track flight") { store.toggle(f) }.buttonStyle(.bordered) }
        }.padding(20).background(.background).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.1)))
    }
    var trackingView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your watchlist").font(.title2.bold())
            Text("Saved on this device. Test a price drop to check the history and Mac alert flow.").foregroundStyle(.secondary)
            if store.watches.isEmpty { Label("Track a flight from search results to get started.", systemImage: "bookmark").padding(.vertical, 40) }
            ForEach(store.watches) { watch in
                VStack(alignment: .leading, spacing: 12) {
                    flightCard(watch.flight)
                    if watch.history.count > 1 {
                        Chart(watch.history) { point in LineMark(x: .value("Time", point.date), y: .value("USD", point.price)).foregroundStyle(.teal); PointMark(x: .value("Time", point.date), y: .value("USD", point.price)).foregroundStyle(.teal) }.frame(height: 140)
                    }
                    Text("\(watch.history.count) observations · Initial fare \(watch.history.first!.price, format: .currency(code: "USD"))").font(.caption)
                    Button("Simulate 10% price drop") { Task { await store.simulateDrop(watch.id) } }
                }
            }
        }
    }
    var preferences: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Notifications").font(.title2.bold())
            Button("Enable notifications on this Mac") { Task { await store.enableNotifications() } }.buttonStyle(.borderedProminent).tint(.teal)
            Picker("Price-change summary", selection: $store.hours) { Text("Every hour").tag(1.0); Text("Every 6 hours").tag(6.0); Text("Daily").tag(24.0); Text("Weekly").tag(168.0) }
            Label("Price drops bypass the summary schedule", systemImage: "bolt.fill").foregroundStyle(.teal)
            Text("Your preference is saved. Scheduled summaries and automatic checks become active when a live monitoring service is connected. This demo only sends manually triggered test alerts.").foregroundStyle(.secondary)
            Divider()
            Text("Mac + iPhone").font(.headline)
            Text("Cross-device alerts require the app on each device, notification permission, and a server that sends Apple push notifications to registered devices. Sharing an Apple ID does not automatically share these alerts.").foregroundStyle(.secondary)
        }
    }
}
