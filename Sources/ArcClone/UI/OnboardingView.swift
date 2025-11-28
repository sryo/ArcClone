import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "square.stack.3d.up.fill",
            title: "Welcome to ArcClone",
            description: "A browser built with Spaces, Profiles, and SwiftUI that reimagines how you organize your web browsing."
        ),
        OnboardingPage(
            icon: "square.grid.2x2",
            title: "Organize with Spaces",
            description: "Create separate workspaces for different contexts—Work, Personal, Projects. Each Space has its own tabs and can use different Profiles."
        ),
        OnboardingPage(
            icon: "person.2.circle",
            title: "Isolate with Profiles",
            description: "Profiles keep your cookies, history, and logins completely separate. Perfect for managing multiple accounts or keeping work and personal browsing isolated."
        ),
        OnboardingPage(
            icon: "pin.fill",
            title: "Pin Your Favorites",
            description: "Pinned tabs stay in your Space permanently. Today tabs are temporary and get archived after 12 hours. Drag tabs between sections to organize."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Page Content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            .frame(height: 400)
            
            // Page Indicators
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 20)
            
            // Navigation Buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundColor(.accentColor)
                .frame(height: 100)
            
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
        }
        .padding(40)
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
