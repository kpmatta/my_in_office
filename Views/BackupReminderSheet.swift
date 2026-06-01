import SwiftUI

struct BackupReminderSheet: View {
    let onOpenSettings: () -> Void
    let onDismissForNow: () -> Void
    let onNeverRemindMe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "externaldrive.badge.icloud")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Back up your attendance data")
                        .font(.title3.weight(.semibold))
                    Text("Export a CSV backup and save it to Files or iCloud Drive.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Use Export Data in Settings to create the backup.", systemImage: "checkmark.circle")
                Label("Save the file somewhere safe so you can import it later if needed.", systemImage: "folder")
                Label("We’ll remind you again later unless you turn reminders off.", systemImage: "bell.badge")
            }
            .font(.footnote)
            .foregroundColor(.secondary)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button("Open Settings", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                Button("Not Now", action: onDismissForNow)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("Never Remind Me", role: .destructive, action: onNeverRemindMe)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .padding(24)
    }
}
