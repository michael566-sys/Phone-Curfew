import CurfewKit
import SwiftUI

struct PartnerView: View {
    @Environment(AppModel.self) private var model
    @State private var newEmail = ""
    @State private var partnerEmail = ""

    var body: some View {
        Form {
            Section {
                ForEach(model.settings.myEmails, id: \.self) { Text($0) }
                    .onDelete { offsets in
                        var new = model.settings
                        new.myEmails.remove(atOffsets: offsets)
                        model.submit(new)
                    }
                HStack {
                    TextField("you@example.com", text: $newEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    Button("Add") { addMyEmail() }
                        .disabled(normalizeEmail(newEmail) == nil)
                }
            } header: {
                Text("My emails")
            } footer: {
                Text("Your own addresses can't be used as a partner.")
            }

            Section {
                if let partner = model.partner {
                    LabeledContent("Partner", value: partner.email)
                    LabeledContent("Status", value: partner.status == .confirmed ? "Confirmed" : "Invite pending")
                } else {
                    TextField("partner@example.com", text: $partnerEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    Button("Invite partner") { model.invitePartner(partnerEmail) }
                        .disabled(partnerEmail.isEmpty)
                }
            } header: {
                Text("Accountability partner")
            } footer: {
                Text("Your partner gets your unlock codes by email. New partners wait 7 days before they can approve unlocks.")
            }

            if let message = model.message {
                Section { Text(message).font(.footnote) }
            }
        }
        .navigationTitle("Partner")
    }

    private func addMyEmail() {
        guard let normalized = normalizeEmail(newEmail) else { return }
        var new = model.settings
        if !new.myEmails.contains(normalized) { new.myEmails.append(normalized) }
        model.submit(new)
        newEmail = ""
    }
}
