import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Phone Curfew").font(.largeTitle.bold())
            Text("Blocks your apps from 10:30 PM to 6:30 AM and keeps daytime use in check. It needs Screen Time access to do that.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if model.authorization == .denied {
                Text("Access was denied or revoked. Allow it again, or turn it on in Settings → Screen Time.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                Task { await model.requestAuthorization() }
            } label: {
                Text("Allow Screen Time access").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let message = model.message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}
