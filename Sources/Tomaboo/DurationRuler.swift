import SwiftUI

/// 可左右拖动的时长刻度尺：每格 1 分钟，每 5 分钟一个数字。
/// value 可为小数（计时中平滑移动）；拖动时吸附到整分钟并给触控板反馈。
struct DurationRuler: View, Animatable {
    var value: Double
    var tint: Color
    var onChange: ((Int) -> Void)?   // nil = 只读
    var range: ClosedRange<Int> = 1...180

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    private let spacing: CGFloat = 9
    @State private var dragStart: Double?

    var body: some View {
        Canvas { ctx, size in
            let mid = size.width / 2
            let first = max(0, Int((value - mid / spacing).rounded(.down)))
            let last = min(range.upperBound, Int((value + mid / spacing).rounded(.up)))
            guard first <= last else { return }
            for m in first...last {
                let x = mid + (CGFloat(m) - value) * spacing
                let major = m % 5 == 0
                let h: CGFloat = major ? 14 : 8
                let tick = Path(roundedRect: CGRect(x: x - 1, y: size.height - h, width: 2, height: h), cornerRadius: 1)
                ctx.fill(tick, with: .color(.primary.opacity(major ? 0.45 : 0.22)))
                if major {
                    let selected = abs(Double(m) - value) < 0.5
                    let label = Text("\(m)")
                        .font(.system(size: selected ? 13 : 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.4))
                    ctx.draw(label, at: CGPoint(x: x, y: 8))
                }
            }
        }
        .overlay(alignment: .bottom) {
            Capsule().fill(tint).frame(width: 3, height: 24)
        }
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.25),
                                     .init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
        .frame(height: 44)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard let onChange else { return }
                let start = dragStart ?? value
                dragStart = start
                let new = min(max(Int((start - drag.translation.width / spacing).rounded()), range.lowerBound), range.upperBound)
                if Double(new) != value {
                    onChange(new)
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            .onEnded { _ in dragStart = nil })
        .accessibilityElement()
        .accessibilityLabel("时长")
        .accessibilityValue("\(Int(value.rounded())) 分钟")
        .accessibilityAdjustableAction { direction in
            guard let onChange else { return }
            let step = direction == .increment ? 1 : -1
            onChange(min(max(Int(value.rounded()) + step, range.lowerBound), range.upperBound))
        }
    }
}
