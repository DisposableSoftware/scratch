import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "https://music.example.com",
                        text: viewModel.binding(\.serverURL, to: { .serverURLChanged($0) })
                    )
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                } header: {
                    Text("Server")
                }
                Section {
                    TextField("Username", text: viewModel.binding(\.username, to: { .usernameChanged($0) }))
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: viewModel.binding(\.password, to: { .passwordChanged($0) }))
                        .textContentType(.password)
                } header: {
                    Text("Account")
                }
            }
            .navigationTitle("Scratch")
        }
    }
}
