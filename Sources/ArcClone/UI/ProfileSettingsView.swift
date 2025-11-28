import SwiftUI
import SwiftData

struct ProfileSettingsView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var store: BrowserStore
    @Query(sort: \BrowserProfile.createdDate) private var profiles: [BrowserProfile]
    @Query private var spaces: [BrowserSpace]
    
    @State private var newProfileName: String = ""
    @State private var editingProfile: BrowserProfile?
    @State private var showDeleteAlert = false
    @State private var profileToDelete: BrowserProfile?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Profiles")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            List {
                Section("Profiles") {
                    ForEach(profiles) { profile in
                        HStack {
                            if editingProfile == profile {
                                TextField("Profile Name", text: Bindable(profile).name)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        editingProfile = nil
                                    }
                                Button("Save") {
                                    editingProfile = nil
                                }
                                .buttonStyle(.link)
                            } else {
                                Text(profile.name)
                                Spacer()
                                
                                Button(action: {
                                    editingProfile = profile
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                
                                if profiles.count > 1 {
                                    Button(action: {
                                        profileToDelete = profile
                                        showDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Create New Profile") {
                    HStack {
                        TextField("New Profile Name", text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Create") {
                            createProfile()
                        }
                        .disabled(newProfileName.isEmpty)
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 400, height: 500)
        .alert("Delete Profile?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    deleteProfile(profile)
                }
            }
        } message: {
            Text("This will delete the profile and reassign its spaces to another profile. This action cannot be undone.")
        }
    }
    
    private func createProfile() {
        let profile = BrowserProfile(name: newProfileName)
        modelContext.insert(profile)
        newProfileName = ""
    }
    
    private func deleteProfile(_ profile: BrowserProfile) {
        store.deleteProfile(profile)
    }
}
