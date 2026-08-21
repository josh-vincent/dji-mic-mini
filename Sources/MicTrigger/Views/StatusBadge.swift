import SwiftUI

struct StatusBadge: View {
    let label: String
    let isReady: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isReady ? Color.green : Color.secondary.opacity(0.7))
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }
}
