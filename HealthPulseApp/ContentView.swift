import SwiftUI
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("HealthPulse").font(.largeTitle).bold()
            Text("Vitals Tracker Ready").foregroundColor(.green)
            Text("v1.0.0").font(.caption).foregroundColor(.gray)
        }
    }
}
