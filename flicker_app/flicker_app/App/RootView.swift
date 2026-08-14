import SwiftUI

struct RootView: View {
    @State private var session = SessionStore()

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
            } else {
                AuthFlowView()
            }
        }
        .environment(session)
    }
}
