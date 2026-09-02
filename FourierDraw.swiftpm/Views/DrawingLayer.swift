import SwiftUI
import Foundation

struct DrawingLayer: View {
    @Binding var points: [CGPoint]
    let onDrawingBegan: () -> Void
    let onDrawingEnded: ([CGPoint]) -> Void

    var body: some View {
        Canvas { context, _ in
            guard let first = points.first else { return }

            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(
                path,
                with: .color(
                    Color(red: 125 / 255, green: 122 / 255, blue: 115 / 255)
                ),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if points.isEmpty {
                        onDrawingBegan()
                    }
                    points.append(value.location)
                }
                .onEnded { _ in
                    let completedPoints = points
                    points.removeAll(keepingCapacity: true)
                    onDrawingEnded(completedPoints)
                }
        )
    }
}
