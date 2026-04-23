import SwiftUI

struct EditorPanelView: View {
    @EnvironmentObject var vm: TimelineViewModel

    @State private var knob1: Double = 0.72
    @State private var knob2: Double = 0.45
    @State private var sliders: [Double] = Array(repeating: 0.6, count: AppTheme.Layout.sliderCount)

    private var clip: TrackClip? { vm.selectedClip }
    private var track: Track?    { vm.selectedTrack }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            waveformDisplay
            Divider().background(Color.white.opacity(0.1))
            controls
            Divider().background(Color.white.opacity(0.1))
            credentialInfo
        }
        .frame(width: AppTheme.Layout.editorWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(AppTheme.Dark.editorBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
        .onChange(of: clip?.service) { _ in vm.revealedPassword = nil }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if let track {
                RoundedRectangle(cornerRadius: 3)
                    .fill(track.color)
                    .frame(width: 10, height: 10)
            }
            Text(clip?.service ?? "")
                .font(AppTheme.Font.editorTitle)
                .foregroundStyle(Color.white)
            Spacer()
            Button { vm.closeEditor() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Waveform display (visual decoration)

    private var waveformDisplay: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let step: CGFloat = 3
            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))
            var x: CGFloat = 0
            while x < size.width {
                let seed = Double(clip?.service.hashValue ?? 0)
                let amp = sin(x * 0.08 + seed) * 14 + sin(x * 0.19 + seed * 0.5) * 8
                path.addLine(to: CGPoint(x: x, y: midY + amp))
                x += step
            }
            context.stroke(
                path,
                with: .color(AppTheme.Dark.waveformLine),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
        .background(AppTheme.Dark.waveformBg)
        .frame(height: 70)
    }

    // MARK: - DAW controls (decorative aesthetic)

    private var controls: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 16) {
                KnobView(value: $knob1, label: "Encrypt")
                KnobView(value: $knob2, label: "Strength")
            }
            .padding(.horizontal, 16)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)

            HStack(alignment: .center, spacing: 10) {
                ForEach(sliders.indices, id: \.self) { i in
                    VerticalSliderView(value: $sliders[i])
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(height: AppTheme.Layout.editorHeight)
        .padding(.vertical, 8)
    }

    // MARK: - Credential info (real data)

    private var credentialInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow(label: "Username", value: clip?.username ?? "—")

            HStack {
                infoRow(
                    label: "Password",
                    value: vm.revealedPassword ?? "••••••••••••"
                )
                Spacer()
                Button {
                    if vm.revealedPassword == nil {
                        vm.revealPassword(for: clip!)
                    } else {
                        vm.revealedPassword = nil
                    }
                } label: {
                    Image(systemName: vm.revealedPassword == nil ? "eye" : "eye.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(clip == nil)

                if let password = vm.revealedPassword {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(password, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .font(AppTheme.Font.label)
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(AppTheme.Font.label)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
        }
    }
}
