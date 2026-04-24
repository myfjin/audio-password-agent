import SwiftUI

/// Vertical fader matching the slider bank in the Sketch editor panel.
struct VerticalSliderView: View {
    @Binding var value: Double   // 0.0 – 1.0
    var height: CGFloat = AppTheme.Layout.sliderHeight

    private let trackWidth: CGFloat  = 3
    private let thumbSize: CGFloat   = 12

    var body: some View {
        GeometryReader { geo in
            let usable = geo.size.height - thumbSize
            let thumbY  = usable * (1 - value)

            ZStack(alignment: .top) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: trackWidth)
                    .frame(maxWidth: .infinity)

                // Fill below thumb
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: trackWidth, height: usable - thumbY + thumbSize / 2)
                    .offset(y: thumbY + thumbSize / 2)
                    .frame(maxWidth: .infinity)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(y: thumbY)
                    .frame(maxWidth: .infinity)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newVal = 1 - (drag.location.y - thumbSize / 2) / usable
                        value = min(1, max(0, newVal))
                    }
            )
        }
        .frame(width: 20, height: height)
    }
}
