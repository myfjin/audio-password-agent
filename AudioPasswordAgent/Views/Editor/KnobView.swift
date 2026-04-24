import SwiftUI

/// Circular rotary knob matching the orange gradient knobs in the Sketch editor panel.
struct KnobView: View {
    @Binding var value: Double   // 0.0 – 1.0
    var label: String = ""
    var size: CGFloat = AppTheme.Layout.knobSize

    // Maps value [0,1] to rotation angle [-135°, +135°]
    private var angle: Double { (value - 0.5) * 270 }

    @State private var dragStart: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track arc (dark)
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)

                // Value arc (orange)
                Circle()
                    .trim(from: 0.125, to: 0.125 + value * 0.75)
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.accent.opacity(0.6), AppTheme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Knob body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.accent.opacity(0.9),
                                AppTheme.accent.opacity(0.5),
                                Color(hex: "331800")
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: size * 0.8
                        )
                    )
                    .padding(6)

                // Indicator dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .offset(y: -(size / 2 - 14))
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: size, height: size)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let delta = -drag.translation.height / 200
                        value = min(1, max(0, dragStart + delta))
                    }
                    .onEnded { _ in dragStart = value }
            )

            if !label.isEmpty {
                Text(label)
                    .font(AppTheme.Font.label)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
    }
}
