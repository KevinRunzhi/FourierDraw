import SwiftUI
import Foundation

struct FirstRunCaptions: View {
    let startedAt: Date
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let captions = [
        "每个圆是求和式里的一项",
        "圆首尾相接，末端就是笔尖",
        "拖下面的滑块，看它用几个圆"
    ]
    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)

    init(startedAt: Date, onFinished: @escaping () -> Void) {
        self.startedAt = startedAt
        self.onFinished = onFinished
#if DEBUG
        _ = Self.timelineValidation
#endif
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: startedAt, by: 0.1)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                let index = Self.captionIndex(at: elapsed)

                VStack(spacing: 7) {
                    ZStack {
                        ForEach(captions.indices, id: \.self) { captionIndex in
                            Text(captions[captionIndex])
                                .font(.system(size: 16))
                                .foregroundStyle(ink.opacity(0.9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .opacity(captionIndex == index ? 1 : 0)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(width: geometry.size.width * 0.72, height: 52)
                    .background(.white.opacity(reduceTransparency ? 1 : 0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ink.opacity(0.1), lineWidth: 1)
                    }
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.25),
                        value: index
                    )

                    HStack(spacing: 10) {
                        ForEach(captions.indices, id: \.self) { dotIndex in
                            Circle()
                                .fill(ink.opacity(dotIndex == index ? 0.75 : 0.22))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .opacity(Self.overallOpacity(at: elapsed))
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottom
                )
                .padding(.bottom, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(captions[index])
            }
        }
        .allowsHitTesting(false)
        .task {
            do {
                try await Task.sleep(for: .seconds(8))
            } catch {
                return
            }
            onFinished()
        }
    }

    private static func captionIndex(at elapsed: TimeInterval) -> Int {
        if elapsed >= 5 { return 2 }
        if elapsed >= 2.5 { return 1 }
        return 0
    }

    private static func overallOpacity(at elapsed: TimeInterval) -> Double {
        guard elapsed > 7.7 else { return 1 }
        return max(0, (8 - elapsed) / 0.3)
    }

#if DEBUG
    private static let timelineValidation: Void = {
        assert(captionIndex(at: 0) == 0)
        assert(captionIndex(at: 2.49) == 0)
        assert(captionIndex(at: 2.5) == 1)
        assert(captionIndex(at: 4.99) == 1)
        assert(captionIndex(at: 5) == 2)
        assert(overallOpacity(at: 7.7) == 1)
        assert(overallOpacity(at: 8) == 0)
        print("FirstRunCaptions timeline: 0.0 / 2.5 / 5.0 / 8.0 passed")
    }()
#endif
}
