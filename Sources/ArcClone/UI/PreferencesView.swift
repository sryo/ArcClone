import SwiftUI
import SwiftData
import WebKit

struct PreferencesView: View {
    var body: some View {
        TabView {
            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
            
            SyncSettingsView()
                .tabItem {
                    Label("Sync", systemImage: "icloud")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

struct PrivacySettingsView: View {
    @State private var clearHistory = true
    @State private var clearCookies = true
    @State private var clearCache = true
    @State private var clearTabs = false
    
    @State private var timeRange: TimeRange = .lastHour
    @State private var isClearing = false
    @State private var showConfirmation = false
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case lastHour = "Last Hour"
        case last24Hours = "Last 24 Hours"
        case last7Days = "Last 7 Days"
        case last4Weeks = "Last 4 Weeks"
        case allTime = "All Time"
        
        var id: String { self.rawValue }
        
        var timeInterval: TimeInterval {
            switch self {
            case .lastHour: return 3600
            case .last24Hours: return 86400
            case .last7Days: return 86400 * 7
            case .last4Weeks: return 86400 * 28
            case .allTime: return 0 // Special case
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Clear Browsing Data")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Browsing History", isOn: $clearHistory)
                Toggle("Cookies and Site Data", isOn: $clearCookies)
                Toggle("Cached Images and Files", isOn: $clearCache)
                Toggle("Close Tabs created in this period", isOn: $clearTabs)
            }
            .padding(.leading)
            
            HStack {
                Text("Time Range:")
                Picker("", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .frame(width: 150)
            }
            .padding(.top, 10)
            
            Spacer()
            
            HStack {
                Spacer()
                if isClearing {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                Button("Clear Data") {
                    showConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(isClearing || (!clearHistory && !clearCookies && !clearCache && !clearTabs))
            }
        }
        .padding()
        .alert("Are you sure?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                performClear()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    @Environment(\.modelContext) var modelContext

    private func performClear() {
        isClearing = true
        
        Task {
            // 1. Clear WebKit Data
            var dataTypes = Set<String>()
            if clearCookies {
                dataTypes.insert(WKWebsiteDataStore.allWebsiteDataTypes().first { $0 == WKWebsiteDataTypeCookies } ?? WKWebsiteDataTypeCookies)
                dataTypes.insert(WKWebsiteDataStore.allWebsiteDataTypes().first { $0 == WKWebsiteDataTypeLocalStorage } ?? WKWebsiteDataTypeLocalStorage)
            }
            if clearCache {
                dataTypes.insert(WKWebsiteDataStore.allWebsiteDataTypes().first { $0 == WKWebsiteDataTypeDiskCache } ?? WKWebsiteDataTypeDiskCache)
                dataTypes.insert(WKWebsiteDataStore.allWebsiteDataTypes().first { $0 == WKWebsiteDataTypeMemoryCache } ?? WKWebsiteDataTypeMemoryCache)
            }
            // Note: "History" in WebKit usually refers to visited links, but we might manage our own history later.
            // For now, we'll clear what WebKit allows.
            
            if !dataTypes.isEmpty {
                let date = timeRange == .allTime ? .distantPast : Date().addingTimeInterval(-timeRange.timeInterval)
                await WebEngine.shared.clearBrowsingData(types: dataTypes, since: date)
            }
            
            // 1.5 Clear SwiftData History
            if clearHistory {
                await MainActor.run {
                    do {
                        let date = timeRange == .allTime ? Date.distantPast : Date().addingTimeInterval(-timeRange.timeInterval)
                        
                        // We can't easily use a dynamic predicate with a variable date in all SwiftData versions/macros yet without some boilerplate,
                        // but we can fetch and filter or use a specific predicate construction.
                        // For simplicity and safety with macros:
                        
                        let descriptor = FetchDescriptor<HistoryEntry>()
                        if let entries = try? modelContext.fetch(descriptor) {
                            for entry in entries {
                                if entry.visitDate >= date {
                                    modelContext.delete(entry)
                                }
                            }
                            try? modelContext.save()
                        }
                    } catch {
                        print("Failed to clear history: \(error)")
                    }
                }
            }
            
            // 2. Clear Tabs (if selected)
            if clearTabs {
                // This would need to call into BrowserStore. 
                // Since we don't have direct access to the store instance here easily without EnvironmentObject,
                // we might need to post a notification or use a shared manager if BrowserStore isn't a singleton.
                // However, BrowserStore is created in ContentView. 
                // For this task, I'll add a static method or notification handler to BrowserStore, 
                // or better, inject it if I can. But Settings window is separate.
                // I'll use NotificationCenter for now to trigger the cleanup in ContentView/BrowserStore.
                
                let userInfo: [String: Any] = ["since": timeRange == .allTime ? Date.distantPast : Date().addingTimeInterval(-timeRange.timeInterval)]
                NotificationCenter.default.post(name: .shouldClearTabs, object: nil, userInfo: userInfo)
            }
            
            // Simulate a small delay for UX
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                isClearing = false
            }
        }
    }
}

struct SyncSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("iCloud Sync")
                .font(.title2)
            
            Text("Syncing your spaces, tabs, and history across devices is coming soon.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 300)
        }
        .padding()
    }
}

extension Notification.Name {
    static let shouldClearTabs = Notification.Name("shouldClearTabs")
}
