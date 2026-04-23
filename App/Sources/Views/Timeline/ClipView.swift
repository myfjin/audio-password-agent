import SwiftUI

struct ClipView: View {
    let clip: TrackClip
    let color: Color
    @State private var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.Layout.clipCornerRadius)
            .fill(color.opacity(isHovered ? 0.85 : 1.0))
            .overlay(waveformOverlay)
            .overlay(labelOverlay, alignment: .topLeading)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Layout.clipCornerRadius)
                    .strokeBorder(Color.white.opacity(isHovered ? 0.25 : 0.0), lineWidth: 1)
            )
            .frame(height: AppTheme.Layout.trackHeight - 10)
            .padding(.vertical, 5)
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    // Repeating triangular waveform pattern (matches the Sketch design)
    private var waveformOverlay: some View {
        Canvas { context, size in
            let peakH: CGFloat  = 10
            let peakW: CGFloat  = 14
            let spacing: CGFloat = 4
            let baseY = size.height / 2
            let waveColor = GraphicsContext.Shading.color(.white.opacity(0.22))

            var path = Path()
            var x: CGFloat = 8
            while x + peakW < size.width - 8 {
                path.move(to:    CGPoint(x: x,            y: baseY + peakH / 2))
                path.addLine(to: CGPoint(x: x + peakW / 2, y: baseY - peakH / 2))
                path.addLine(to: CGPoint(x: x + peakW,    y: baseY + peakH / 2))
                x += peakW + spacing
            }
            context.stroke(path, with: waveColor, lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.clipCornerRadius))
    }

    private var labelOverlay: some View {
        Text(clip.service)
            .font(AppTheme.Font.label)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .lineLimit(1)
    }
}
