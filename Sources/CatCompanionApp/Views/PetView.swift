import SwiftUI
import CatCompanionCore

struct PetView: View {
    let isAlerting: Bool
    let isSpeaking: Bool
    let isListening: Bool
    let speechLevel: Double
    let motionProfile: PetMotionProfile
    let isLowPowerMode: Bool
    let statusText: String
    @State private var animatePulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            accentColor.opacity(isSpeaking ? 0.75 : 0.45),
                            lineWidth: isSpeaking ? 2 : 1
                        )
                )
                .shadow(color: accentColor.opacity(0.25), radius: isSpeaking ? 14 : 8, x: 0, y: 4)
                .frame(width: 178, height: 178)

            Circle()
                .stroke(accentColor.opacity(0.28), lineWidth: 1)
                .frame(width: 152, height: 152)
                .scaleEffect(animatePulse ? 1.03 : 0.97)
                .opacity(animatePulse ? 0.85 : 0.45)
                .animation(
                    .easeInOut(duration: pulseDuration).repeatForever(autoreverses: true),
                    value: animatePulse
                )

            Circle()
                .stroke(
                    accentColor.opacity(0.36),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 8])
                )
                .frame(width: 126, height: 126)
                .rotationEffect(.degrees(animatePulse ? 360 : 0))
                .animation(
                    .linear(duration: orbitDuration).repeatForever(autoreverses: false),
                    value: animatePulse
                )

            VStack(spacing: 10) {
                TechWaveformBars(
                    energy: energy,
                    color: accentColor,
                    motionProfile: motionProfile,
                    isLowPowerMode: isLowPowerMode
                )
                .frame(width: 132, height: 54)

                VStack(spacing: 3) {
                    Text(AppStrings.text(.appName))
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.58))

                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 138)
                }
            }

            if isAlerting {
                Circle()
                    .fill(Color.orange.opacity(0.96))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: 72, y: -72)
            }
        }
        .onAppear {
            animatePulse = true
        }
    }

    private var panelBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.09, blue: 0.16).opacity(0.94),
                Color(red: 0.03, green: 0.15, blue: 0.21).opacity(0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accentColor: Color {
        if isAlerting {
            return Color.orange
        }
        if isSpeaking {
            return Color(red: 0.18, green: 0.87, blue: 1.0)
        }
        if isListening {
            return Color(red: 0.42, green: 0.78, blue: 1.0)
        }
        return Color(red: 0.35, green: 0.72, blue: 1.0)
    }

    private var energy: CGFloat {
        let profileFactor: CGFloat = motionProfile == .vivid ? 1.0 : 0.68
        if isAlerting {
            return min(1.0, 0.88 * profileFactor)
        }
        if isSpeaking {
            let liveLevel = CGFloat(min(1, max(0, speechLevel)))
            let boosted = 0.28 + liveLevel * 0.95 * profileFactor
            return max(0.22, min(1.0, boosted))
        }
        if isListening {
            return min(1.0, 0.72 * profileFactor)
        }
        let idleBase: CGFloat = isLowPowerMode ? 0.18 : 0.38
        return min(1.0, idleBase * profileFactor)
    }

    private var pulseDuration: Double {
        if isLowPowerMode {
            return 2.8
        }
        if isSpeaking {
            return motionProfile == .vivid ? 0.8 : 1.2
        }
        return motionProfile == .vivid ? 1.8 : 2.3
    }

    private var orbitDuration: Double {
        if isLowPowerMode {
            return 8.4
        }
        if isSpeaking {
            return motionProfile == .vivid ? 2.8 : 4.0
        }
        return motionProfile == .vivid ? 6.0 : 7.5
    }
}

private struct TechWaveformBars: View {
    let energy: CGFloat
    let color: Color
    let motionProfile: PetMotionProfile
    let isLowPowerMode: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: frameInterval)) { timeline in
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<13, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(barGradient)
                        .frame(width: 4, height: barHeight(for: index, at: timeline.date.timeIntervalSinceReferenceDate))
                        .opacity(barOpacity(for: index))
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.95),
                Color.white.opacity(0.72),
                color.opacity(0.85)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func barHeight(for index: Int, at time: TimeInterval) -> CGFloat {
        let motionFactor = motionProfile == .vivid ? 1.0 : 0.62
        let lowPowerFactor = isLowPowerMode ? 0.36 : 1.0
        let speed = (1.6 + Double(energy) * 5.2) * motionFactor * lowPowerFactor
        let offset = Double(index) * 0.55
        let primary = (sin(time * speed + offset) + 1) * 0.5
        let secondary = (sin(time * speed * 0.63 + offset * 1.8) + 1) * 0.5
        let blend = primary * 0.7 + secondary * 0.3
        let minHeight: CGFloat = isLowPowerMode ? 7 : 9
        let profileRange: CGFloat = motionProfile == .vivid ? 34 : 22
        let dynamicRange: CGFloat = (isLowPowerMode ? 8 : 12) + energy * profileRange
        return minHeight + CGFloat(blend) * dynamicRange
    }

    private func barOpacity(for index: Int) -> CGFloat {
        let base: CGFloat = isLowPowerMode ? 0.48 : 0.62
        return base + CGFloat((index * 7) % 5) * 0.05
    }

    private var frameInterval: TimeInterval {
        if isLowPowerMode {
            return 1.0 / 8.0
        }
        return motionProfile == .vivid ? 1.0 / 30.0 : 1.0 / 16.0
    }
}
