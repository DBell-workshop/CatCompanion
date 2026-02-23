import SwiftUI
import CatCompanionCore

struct ReminderBubbleView: View {
    let reminderType: ReminderType
    let onComplete: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("\(titleEmoji) \(reminderType.displayName)")
                .font(.headline)
            Text(reminderType.prompt)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button(AppStrings.text(.actionComplete)) { onComplete() }
                    .buttonStyle(.borderedProminent)
                Button(AppStrings.text(.actionSnooze)) { onSnooze() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(
            BubbleBackground()
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
        )
        .frame(maxWidth: 200)
    }

    private var titleEmoji: String {
        switch reminderType {
        case .hydrate: return "💧"
        case .stand: return "🚶"
        case .restEyes: return "💤"
        }
    }
}

private struct BubbleBackground: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bubbleRect = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - 10)
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: 12, height: 12))

        let tailWidth: CGFloat = 18
        let tailHeight: CGFloat = 10
        let tailX = rect.midX - tailWidth / 2
        let tailY = rect.height - tailHeight

        path.move(to: CGPoint(x: tailX, y: tailY))
        path.addLine(to: CGPoint(x: tailX + tailWidth / 2, y: rect.height))
        path.addLine(to: CGPoint(x: tailX + tailWidth, y: tailY))
        path.closeSubpath()

        return path
    }
}
