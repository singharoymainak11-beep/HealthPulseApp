import SwiftUI
import Charts

@main
struct HealthPulseApp: App {
    @StateObject private var store = HealthStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

// MARK: - Models
struct BPEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var systolic: Int
    var diastolic: Int
    var heartRate: Int
    var date: Date
    var notes: String = ""
    var category: String {
        switch systolic {
        case ..<120 where diastolic < 80: return "Normal"
        case 120..<130 where diastolic < 80: return "Elevated"
        case 130..<140, _ where diastolic >= 80 && diastolic < 90: return "High Stage 1"
        default: return "High Stage 2"
        }
    }
    var color: Color {
        switch category {
        case "Normal": return .green
        case "Elevated": return .yellow
        case "High Stage 1": return .orange
        default: return .red
        }
    }
}

// MARK: - Store
class HealthStore: ObservableObject {
    @Published var entries: [BPEntry] = [] {
        didSet { save() }
    }
    @Published var isPremium = false
    private let key = "bp_entries_v2"
    init() { load() }
    func add(s: Int, d: Int, hr: Int) {
        let e = BPEntry(systolic: s, diastolic: d, heartRate: hr, date: Date())
        entries.insert(e, at: 0)
    }
    func delete(at offsets: IndexSet) { entries.remove(atOffsets: offsets) }
    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([BPEntry].self, from: data) {
            entries = decoded
        }
    }
    var avgSystolic: Int { entries.isEmpty ? 0 : Int(entries.map{ $0.systolic }.reduce(0,+)/entries.count) }
    var avgDiastolic: Int { entries.isEmpty ? 0 : Int(entries.map{ $0.diastolic }.reduce(0,+)/entries.count) }
    var avgHR: Int { entries.isEmpty ? 0 : Int(entries.map{ $0.heartRate }.reduce(0,+)/entries.count) }
}

// MARK: - Main Tabs
struct ContentView: View {
    @EnvironmentObject var store: HealthStore
    @State private var selected = 0
    var body: some View {
        TabView(selection: $selected) {
            DashboardView().tabItem{ Label("Dashboard", systemImage: "heart.fill") }.tag(0)
            LoggerView().tabItem{ Label("Log", systemImage: "plus.circle.fill") }.tag(1)
            HistoryView().tabItem{ Label("History", systemImage: "list.bullet") }.tag(2)
            PremiumView().tabItem{ Label("Premium", systemImage: "star.fill") }.tag(3)
        }
        .tint(Color(red: 0.95, green: 0.2, blue: 0.3))
    }
}

// MARK: - Dashboard
struct DashboardView: View {
    @EnvironmentObject var store: HealthStore
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if store.entries.isEmpty { emptyState } else { statsGrid; chart; latestList }
                }.padding()
            }
            .navigationTitle("Your Health")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    var header: some View {
        VStack(spacing: 8) {
            Text("HealthPulse").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.pink, .red], startPoint: .leading, endPoint: .trailing))
            Text("Track • Analyze • Thrive").font(.subheadline).foregroundColor(.secondary)
        }.padding(.vertical)
    }
    var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Systolic", value: "\(store.avgSystolic)", unit: "mmHg", color: .red)
            StatCard(title: "Diastolic", value: "\(store.avgDiastolic)", unit: "mmHg", color: .orange)
            StatCard(title: "Heart Rate", value: "\(store.avgHR)", unit: "bpm", color: .pink)
        }
    }
    var chart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trend").font(.headline)
            if #available(iOS 16.0, *) {
                Chart(store.entries.prefix(7).reversed()) { e in
                    LineMark(x: .value("Date", e.date, unit: .day), y: .value("Sys", e.systolic)).foregroundStyle(.red).interpolationMethod(.catmullRom)
                    LineMark(x: .value("Date", e.date, unit: .day), y: .value("Dia", e.diastolic)).foregroundStyle(.orange).interpolationMethod(.catmullRom)
                }.frame(height: 160)
            } else {
                Text("Chart requires iOS 16+").font(.caption).foregroundColor(.secondary)
            }
        }.padding().background(Color(.systemGray6)).cornerRadius(16)
    }
    var latestList: some View {
        VStack(alignment: .leading) {
            Text("Recent Readings").font(.headline)
            ForEach(store.entries.prefix(3)) { e in
                HStack {
                    Circle().fill(e.color).frame(width: 12, height: 12)
                    VStack(alignment: .leading) { Text("\(e.systolic)/\(e.diastolic) mmHg").bold(); Text(e.date, style: .relative).font(.caption).foregroundColor(.secondary) }
                    Spacer(); Text("\(e.heartRate) bpm").font(.caption)
                }.padding(.vertical, 4)
            }
        }
    }
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 60)).foregroundColor(.pink)
            Text("No readings yet").font(.title3).bold()
            Text("Tap Log to add your first BP reading and see your dashboard come alive.").multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)
        }.padding(.top, 60)
    }
}
struct StatCard: View { var title: String; var value: String; var unit: String; var color: Color
    var body: some View {
        VStack(spacing: 4) { Text(title).font(.caption).foregroundColor(.secondary); Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(color); Text(unit).font(.caption2).foregroundColor(.secondary) }
        .frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).cornerRadius(14)
    }
}

// MARK: - Logger
struct LoggerView: View {
    @EnvironmentObject var store: HealthStore
    @State private var sys = "120"; @State private var dia = "80"; @State private var hr = "72"
    @State private var showingSaved = false
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Blood Pressure")) {
                    HStack { Text("Systolic"); Spacer(); TextField("120", text: $sys).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80); Text("mmHg").foregroundColor(.secondary) }
                    HStack { Text("Diastolic"); Spacer(); TextField("80", text: $dia).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80); Text("mmHg").foregroundColor(.secondary) }
                }
                Section(header: Text("Heart Rate")) {
                    HStack { Text("Pulse"); Spacer(); TextField("72", text: $hr).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80); Text("bpm").foregroundColor(.secondary) }
                }
                Section { Button(action: save) { HStack{ Spacer(); Text("Save Reading").bold(); Spacer() } } }.listRowBackground(Color.pink).foregroundColor(.white)
            }
            .navigationTitle("Log Vitals")
            .alert("Saved!", isPresented: $showingSaved) { Button("OK"){} } message: { Text("Your reading was added to dashboard.") }
        }
    }
    func save() {
        guard let s = Int(sys), let d = Int(dia), let h = Int(hr) else { return }
        store.add(s: s, d: d, hr: h); sys="120"; dia="80"; hr="72"; showingSaved=true
    }
}

// MARK: - History
struct HistoryView: View {
    @EnvironmentObject var store: HealthStore
    var body: some View {
        NavigationView {
            Group {
                if store.entries.isEmpty {
                    VStack(spacing: 12){ Image(systemName: "clock").font(.largeTitle).foregroundColor(.secondary); Text("No history yet").foregroundColor(.secondary) }
                } else {
                    List { ForEach(store.entries) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 4){
                                Text("\(e.systolic)/\(e.diastolic) mmHg").bold().foregroundColor(e.color)
                                Text(e.date, style: .date).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing){ Text("\(e.heartRate) bpm").font(.caption); Text(e.category).font(.caption2).padding(4).background(e.color.opacity(0.2)).cornerRadius(4) }
                        }.padding(.vertical, 2)
                    }.onDelete(perform: store.delete) }
                }
            }.navigationTitle("History")
        }
    }
}

// MARK: - Premium
struct PremiumView: View {
    @EnvironmentObject var store: HealthStore
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "star.circle.fill").font(.system(size: 80)).foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                Text("HealthPulse Premium").font(.largeTitle).bold()
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "chart.bar.fill", text: "Advanced Analytics & PDF Export")
                    FeatureRow(icon: "applewatch", text: "Apple Watch & HealthKit Sync")
                    FeatureRow(icon: "bell.badge.fill", text: "Smart Reminders & Insights")
                    FeatureRow(icon: "lock.shield.fill", text: "iCloud Backup & Doctor Reports")
                }.padding().background(Color(.systemGray6)).cornerRadius(16)
                if store.isPremium { Label("Premium Active", systemImage: "checkmark.seal.fill").foregroundColor(.green).bold() }
                else {
                    VStack(spacing: 12){
                        Button(action: { store.isPremium = true }) {
                            Text("Unlock Premium — $4.99/mo").bold().frame(maxWidth: .infinity).padding().background(Color.pink).foregroundColor(.white).cornerRadius(12)
                        }
                        Button(action: { store.isPremium = true }) {
                            Text("Restore Purchase")
                        }.font(.caption)
                        Text("Mock purchase for demo — replace with StoreKit2 for App Store").font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                }
            }.padding()
        }
    }
}
struct FeatureRow: View { var icon: String; var text: String
    var body: some View { HStack(spacing: 12){ Image(systemName: icon).foregroundColor(.pink).frame(width: 24); Text(text).font(.subheadline) } }
}
