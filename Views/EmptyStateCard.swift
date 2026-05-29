import SwiftUI

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    let buttonSystemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 72, height: 72)

                Circle()
                    .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                    .frame(width: 86, height: 86)

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: action) {
                Label(buttonTitle, systemImage: buttonSystemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .controlSize(.large)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            tint.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(tint.opacity(0.12), lineWidth: 1)
        )
    }
}
