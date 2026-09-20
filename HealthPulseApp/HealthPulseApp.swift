
import SwiftUI
import Charts

@main
struct HealthPulseApp: App {
    @StateObject private var store = HealthStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}
struct BPEntry: Identifiable, Codable {
    var id = UUID()
    var systolic: Int
    var diastolic: Int
    var heartRate: Int
    var date: Date
    var category: String {
        if systolic < 120 && diastolic < 80 { return "Normal" }
        if systolic < 130 && diastolic < 80 { return "Elevated" }
        if systolic < 140 || diastolic < 90 { return "High Stage 1" }
        return "High Stage 2"
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
class HealthStore: ObservableObject {
    @Published var entries: [BPEntry] = [] { didSet { save() } }
    @Published var isPremium = false
    private let key = "bp_entries_v2"
    init() { load() }
    func add(s: Int, d: Int, hr: Int) { entries.insert(BPEntry(systolic: s, diastolic: d, heartRate: hr, date: Date()), at: 0) }
    func delete(at offsets: IndexSet) { entries.remove(atOffsets: offsets) }
    private func save() { if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) } }
    private func load() { if let data = UserDefaults.standard.data(forKey: key), let dec = try? JSONDecoder().decode([BPEntry].self, from: data) { entries = dec } }
    var avgSys: Int { entries.isEmpty ? 0 : entries.map{ $0.systolic }.reduce(0,+)/entries.count }
    var avgDia: Int { entries.isEmpty ? 0 : entries.map{ $0.diastolic }.reduce(0,+)/entries.count }
    var avgHR: Int { entries.isEmpty ? 0 : entries.map{ $0.heartRate }.reduce(0,+)/entries.count }
}
struct ContentView: View {
    @EnvironmentObject var store: HealthStore
    var body: some View {
        TabView {
            DashboardView().tabItem{ Label("Dashboard", systemImage: "heart.fill") }
            LoggerView().tabItem{ Label("Log", systemImage: "plus.circle.fill") }
            HistoryView().tabItem{ Label("History", systemImage: "list.bullet") }
            PremiumView().tabItem{ Label("Premium", systemImage: "star.fill") }
        }.tint(.pink)
    }
}
struct DashboardView: View {
    @EnvironmentObject var store: HealthStore
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack { Text("HealthPulse").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.pink, .red], startPoint: .leading, endPoint: .trailing)); Text("Track • Analyze • Thrive").font(.subheadline).foregroundColor(.secondary) }.padding(.vertical)
                    if store.entries.isEmpty {
                        VStack(spacing: 16) { Image(systemName: "waveform.path.ecg").font(.system(size: 60)).foregroundColor(.pink); Text("No readings yet").font(.title3).bold(); Text("Tap Log to add first BP reading").foregroundColor(.secondary) }.padding(.top, 60)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            VStack { Text("Systolic").font(.caption).foregroundColor(.secondary); Text("\(store.avgSys)").font(.system(size: 26, weight: .bold)).foregroundColor(.red); Text("mmHg").font(.caption2) }.frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).cornerRadius(14)
                            VStack { Text("Diastolic").font(.caption).foregroundColor(.secondary); Text("\(store.avgDia)").font(.system(size: 26, weight: .bold)).foregroundColor(.orange); Text("mmHg").font(.caption2) }.frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).cornerRadius(14)
                            VStack { Text("Heart Rate").font(.caption).foregroundColor(.secondary); Text("\(store.avgHR)").font(.system(size: 26, weight: .bold)).foregroundColor(.pink); Text("bpm").font(.caption2) }.frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).cornerRadius(14)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("7-Day Trend").font(.headline)
                            if #available(iOS 16.0, *) {
                                Chart(store.entries.prefix(7).reversed()) { e in
                                    LineMark(x: .value("Date", e.date, unit: .day), y: .value("Sys", e.systolic)).foregroundStyle(.red).interpolationMethod(.catmullRom)
                                    LineMark(x: .value("Date", e.date, unit: .day), y: .value("Dia", e.diastolic)).foregroundStyle(.orange).interpolationMethod(.catmullRom)
                                }.frame(height: 150)
                            }
                        }.padding().background(Color(.systemGray6)).cornerRadius(16)
                        VStack(alignment: .leading) {
                            Text("Recent").font(.headline)
                            ForEach(store.entries.prefix(3)) { e in HStack{ Circle().fill(e.color).frame(width: 10, height: 10); VStack(alignment: .leading){ Text("\(e.systolic)/\(e.diastolic) mmHg").bold(); Text(e.date, style: .relative).font(.caption).foregroundColor(.secondary) }; Spacer(); Text("\(e.heartRate) bpm").font(.caption) }.padding(.vertical, 2) }
                        }
                    }
                }.padding()
            }.navigationTitle("Your Health")
        }
    }
}
struct LoggerView: View {
    @EnvironmentObject var store: HealthStore
    @State private var sys="120"; @State private var dia="80"; @State private var hr="72"; @State private var saved=false
    var body: some View {
        NavigationView {
            Form {
                Section("Blood Pressure") {
                    HStack{ Text("Systolic"); Spacer(); TextField("120", text: $sys).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 60); Text("mmHg").foregroundColor(.secondary) }
                    HStack{ Text("Diastolic"); Spacer(); TextField("80", text: $dia).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 60); Text("mmHg").foregroundColor(.secondary) }
                }
                Section("Heart Rate") { HStack{ Text("Pulse"); Spacer(); TextField("72", text: $hr).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 60); Text("bpm").foregroundColor(.secondary) } }
                Section { Button{ guard let s=Int(sys), let d=Int(dia), let h=Int(hr) else { return }; store.add(s: s, d: d, hr: h); saved=true } label:{ HStack{ Spacer(); Text("Save Reading").bold(); Spacer() } } }.listRowBackground(Color.pink).foregroundColor(.white)
            }.navigationTitle("Log Vitals").alert("Saved!", isPresented: $saved){ Button("OK"){} } message:{ Text("Added to dashboard") }
        }
    }
}
struct HistoryView: View {
    @EnvironmentObject var store: HealthStore
    var body: some View {
        NavigationView {
            Group {
                if store.entries.isEmpty { VStack{ Image(systemName: "clock").font(.largeTitle).foregroundColor(.secondary); Text("No history").foregroundColor(.secondary) } }
                else { List { ForEach(store.entries){ e in HStack{ VStack(alignment: .leading){ Text("\(e.systolic)/\(e.diastolic) mmHg").bold().foregroundColor(e.color); Text(e.date, style: .date).font(.caption).foregroundColor(.secondary) }; Spacer(); VStack(alignment: .trailing){ Text("\(e.heartRate) bpm").font(.caption); Text(e.category).font(.caption2).padding(4).background(e.color.opacity(0.2)).cornerRadius(4) } } }; onDelete(perform: store.delete) } }
            }.navigationTitle("History")
        }
    }
}
struct PremiumView: View {
    @EnvironmentObject var store: HealthStore
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "star.circle.fill").font(.system(size: 80)).foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                Text("HealthPulse Premium").font(.largeTitle).bold()
                VStack(alignment: .leading, spacing: 14) {
                    Label("Advanced Analytics & PDF Export", systemImage: "chart.bar.fill")
                    Label("Apple Watch & HealthKit Sync", systemImage: "applewatch")
                    Label("Smart Reminders & Insights", systemImage: "bell.badge.fill")
                    Label("iCloud Backup & Doctor Reports", systemImage: "lock.shield.fill")
                }.padding().background(Color(.systemGray6)).cornerRadius(16)
                if store.isPremium { Label("Premium Active", systemImage: "checkmark.seal.fill").foregroundColor(.green).bold() }
                else {
                    VStack(spacing: 12){
                        Button{ store.isPremium=true }{ Text("Unlock Premium — $4.99/mo").bold().frame(maxWidth: .infinity).padding().background(Color.pink).foregroundColor(.white).cornerRadius(12) }
                        Text("Mock purchase for demo — replace with StoreKit2 for App Store").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }.padding()
        }
    }
}
