import SwiftUI

struct IntroCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onDismiss: () -> Void

    private let paper = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Button(action: onDismiss) {
                    paper.opacity(0.42)
                        .ignoresSafeArea()
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)

                card
                    .frame(width: min(geometry.size.width * 0.56, 620))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(reduceMotion ? .identity : .opacity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 4) {
                Text("傅里叶说：任何封闭的笔迹，")
                Text("都能拆成一串匀速旋转的圆。")
            }
            .font(.system(size: 13))
            .foregroundStyle(ink.opacity(0.72))
            .padding(.top, 26)

            Text("这个 app 把这句话画给你看。")
                .font(.system(size: 13))
                .foregroundStyle(vermilion)
                .padding(.top, 4)

            Rectangle()
                .fill(ink.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 20) {
                IntroStep(
                    symbol: "hand.draw",
                    verb: "画",
                    main: "用手指在纸上画一个封闭图形",
                    detail: "也可以点右上角的星星，换一个现成图形",
                    ink: ink
                )
                IntroStep(
                    symbol: "slider.horizontal.3",
                    verb: "拖",
                    main: "拖最下面的滑块，决定用几个圆来还原",
                    detail: "公式里那个红色的数，就是圆的数量",
                    ink: ink
                )
                IntroStep(
                    symbol: "eye",
                    verb: "看",
                    main: "圆越多越像原稿，虚线就是你画的那条",
                    detail: "低阶只画得出圆滑的东西，直角是高频堆出来的",
                    ink: ink
                )
            }
        }
        .padding(36)
        .background(
            Color(red: 251 / 255, green: 250 / 255, blue: 248 / 255)
                .opacity(0.94),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(ink.opacity(0.12), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onDismiss()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("圆迹")
                    .font(.system(size: 21))
                    .foregroundStyle(ink)

                Text("OrbitInk")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(ink.opacity(0.45))
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Button("开始", action: onDismiss)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(paper)
                    .frame(width: 100, height: 34)
                    .background(ink.opacity(0.88), in: Capsule())
                    .buttonStyle(.plain)

                Text("点任意处也可关闭")
                    .font(.system(size: 10))
                    .foregroundStyle(ink.opacity(0.42))
            }
        }
    }

    private static let accessibilityText = "圆迹 OrbitInk。傅里叶说：任何封闭的笔迹，都能拆成一串匀速旋转的圆。这个 app 把这句话画给你看。画，用手指在纸上画一个封闭图形，也可以点右上角的星星，换一个现成图形。拖，拖最下面的滑块，决定用几个圆来还原，公式里那个红色的数，就是圆的数量。看，圆越多越像原稿，虚线就是你画的那条，低阶只画得出圆滑的东西，直角是高频堆出来的。开始。"
}

private struct IntroStep: View {
    let symbol: String
    let verb: LocalizedStringKey
    let main: LocalizedStringKey
    let detail: LocalizedStringKey
    let ink: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ink.opacity(0.72))
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .stroke(ink.opacity(0.22), lineWidth: 1)
                }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verb)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ink.opacity(0.9))
                    .frame(width: 18, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    Text(main)
                        .font(.system(size: 12))
                        .foregroundStyle(ink.opacity(0.6))

                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(ink.opacity(0.42))
                }
            }
        }
    }
}
