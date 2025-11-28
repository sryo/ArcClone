import SwiftUI
import SwiftData

struct ProfilePickerView: View {
    @Binding var selectedProfile: BrowserProfile?
    @Query(sort: \BrowserProfile.createdDate) var profiles: [BrowserProfile]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var store: BrowserStore
    
    @State private var editingProfileID: UUID?
    @State private var editingName: String = ""
    @FocusState private var isFocused: Bool
    @State private var showProfileSettings = false
    @State private var profileToDelete: BrowserProfile?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                // All Profiles (excluding Incognito)
                ForEach(profiles) { profile in
                    if !profile.isIncognito {
                        profileRow(for: profile)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                }

                
                // Incognito Option
                Button(action: {
                    selectIncognito()
                }) {
                    HStack {
                        Image(systemName: "sunglasses.fill")
                            .foregroundColor(.primary)
                        Text("Incognito")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedProfile?.isIncognito == true {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                
                Divider()
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                
                // New Profile Option
                Button(action: {
                    createNewProfile()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.secondary)
                        Text("New Profile")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                
                // Manage Profiles Option
                Button(action: {
                    showProfileSettings = true
                }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                        Text("Manage Profiles")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: 200)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showProfileSettings) {
            ProfileSettingsView(isPresented: $showProfileSettings)
                .environmentObject(store)
        }
        .alert("Delete Profile?", isPresented: $showDeleteConfirmation, presenting: profileToDelete) { profile in
            Button("Delete", role: .destructive) {
                deleteProfile(profile)
            }
            Button("Cancel", role: .cancel) {}
        } message: { profile in
            Text("Are you sure you want to delete '\(profile.name)'? This action cannot be undone.")
        }
    }
    
    private func profileRow(for profile: BrowserProfile) -> some View {
        HStack {
            if editingProfileID == profile.id {
                TextField("Profile Name", text: $editingName)
                    .focused($isFocused)
                    .onSubmit {
                        saveEdit(for: profile)
                    }
                    // onExitCommand is available on macOS
                    .onExitCommand {
                        cancelEdit()
                    }
                    .textFieldStyle(.plain)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)
            } else {
                HStack {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary)
                        Text(profile.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedProfile == profile {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedProfile = profile
                    }
                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                        startEditing(profile)
                    })
                    
                    Menu {
                        Button(role: .destructive) {
                            profileToDelete = profile
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(.vertical, 4)
        .background(selectedProfile == profile ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
    
    private func startEditing(_ profile: BrowserProfile) {
        editingProfileID = profile.id
        editingName = profile.name
        isFocused = true
    }
    
    private func saveEdit(for profile: BrowserProfile) {
        if !editingName.isEmpty {
            profile.name = editingName
            try? modelContext.save()
        }
        editingProfileID = nil
        isFocused = false
    }
    
    private func cancelEdit() {
        editingProfileID = nil
        isFocused = false
    }
    
    private func deleteProfile(_ profile: BrowserProfile) {
        let nonIncognitoProfiles = profiles.filter { !$0.isIncognito }
        guard nonIncognitoProfiles.count > 1 else {
            // Cannot delete the last profile
            // TODO: Show an alert or visual feedback
            return
        }
        
        store.deleteProfile(profile)
        
        // If we deleted the selected profile, switch to another one
        if selectedProfile == profile {
            if let nextProfile = nonIncognitoProfiles.first(where: { $0.id != profile.id }) {
                selectedProfile = nextProfile
            }
        }
    }
    
    private func selectIncognito() {
        if let incognito = profiles.first(where: { $0.isIncognito }) {
            selectedProfile = incognito
        } else {
            let newProfile = BrowserProfile(name: "Incognito", isIncognito: true)
            modelContext.insert(newProfile)
            selectedProfile = newProfile
        }
    }
    
    private func createNewProfile() {
        let newProfile = BrowserProfile(name: "New Profile")
        modelContext.insert(newProfile)
        selectedProfile = newProfile
        
        // Use a slight delay to allow the view to update before focusing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startEditing(newProfile)
        }
    }
}
