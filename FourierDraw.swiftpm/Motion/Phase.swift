import Foundation

let bloomDuration = 0.9
let firstRoundDrawDuration = 12.0
let drawDuration = 6.0
let sealDuration = 0.8
let turnDuration = 0.5

enum Stage: Equatable {
    case bloom
    case draw
    case seal
    case turn
}

struct PhaseState {
    let stage: Stage
    let progress: Double
    let drawProgress: Double
}

func phaseState(
    elapsed: Double,
    isFirstRound: Bool,
    hasBloom: Bool,
    isDragging: Bool = false
) -> PhaseState {
    let elapsed = elapsed.isFinite ? max(0, elapsed) : 0
    let firstBloomDuration = isFirstRound && hasBloom ? bloomDuration : 0
    let firstDrawDuration = isFirstRound ? firstRoundDrawDuration : drawDuration
    let firstCycleDuration = firstBloomDuration + firstDrawDuration + sealDuration + turnDuration

    if isDragging {
        if elapsed < firstBloomDuration {
            return phaseState(
                cycleElapsed: elapsed,
                bloomDuration: firstBloomDuration,
                drawDuration: firstDrawDuration
            )
        }

        let firstDrawEnd = firstBloomDuration + firstDrawDuration
        if elapsed < firstDrawEnd {
            return phaseState(
                cycleElapsed: elapsed,
                bloomDuration: firstBloomDuration,
                drawDuration: firstDrawDuration
            )
        }

        let repeatingElapsed = (elapsed - firstDrawEnd)
            .truncatingRemainder(dividingBy: drawDuration)
        return phaseState(
            cycleElapsed: repeatingElapsed,
            bloomDuration: 0,
            drawDuration: drawDuration
        )
    }

    if elapsed < firstCycleDuration {
        return phaseState(
            cycleElapsed: elapsed,
            bloomDuration: firstBloomDuration,
            drawDuration: firstDrawDuration
        )
    }

    let repeatingCycleDuration = drawDuration + sealDuration + turnDuration
    let repeatingElapsed = (elapsed - firstCycleDuration)
        .truncatingRemainder(dividingBy: repeatingCycleDuration)

    return phaseState(
        cycleElapsed: repeatingElapsed,
        bloomDuration: 0,
        drawDuration: drawDuration
    )
}

private func phaseState(
    cycleElapsed: Double,
    bloomDuration: Double,
    drawDuration: Double
) -> PhaseState {
    if cycleElapsed < bloomDuration {
        return PhaseState(
            stage: .bloom,
            progress: cycleElapsed / bloomDuration,
            drawProgress: 0
        )
    }

    let drawElapsed = cycleElapsed - bloomDuration
    if drawElapsed < drawDuration {
        let progress = drawElapsed / drawDuration
        return PhaseState(stage: .draw, progress: progress, drawProgress: progress)
    }

    let sealElapsed = drawElapsed - drawDuration
    if sealElapsed < sealDuration {
        return PhaseState(
            stage: .seal,
            progress: sealElapsed / sealDuration,
            drawProgress: 1
        )
    }

    return PhaseState(
        stage: .turn,
        progress: (sealElapsed - sealDuration) / turnDuration,
        drawProgress: 1
    )
}

#if DEBUG
func debugValidatePhaseState() {
    let samples = [0.0, 0.5, 1.0, 5.0, 7.0, 7.4, 14.0]
    let modes = [
        (name: "regular", isFirstRound: false, hasBloom: false),
        (name: "hand-drawn first round", isFirstRound: true, hasBloom: true)
    ]

    for mode in modes {
        print("\(mode.name):")
        for elapsed in samples {
            let state = phaseState(
                elapsed: elapsed,
                isFirstRound: mode.isFirstRound,
                hasBloom: mode.hasBloom
            )
            print(
                "elapsed = \(String(format: "%.1f", elapsed)): "
                    + "(\(state.stage), \(String(format: "%.3f", state.progress)))"
            )
        }
    }

    let draggingAtDrawEnd = phaseState(
        elapsed: 6.0,
        isFirstRound: false,
        hasBloom: false,
        isDragging: true
    )
    let draggingAfterDrawEnd = phaseState(
        elapsed: 6.5,
        isFirstRound: false,
        hasBloom: false,
        isDragging: true
    )
    let firstRoundAfterDrawEnd = phaseState(
        elapsed: 13.4,
        isFirstRound: true,
        hasBloom: true,
        isDragging: true
    )
    let resumedElapsed = draggingAfterDrawEnd.drawProgress * drawDuration
    let resumed = phaseState(
        elapsed: resumedElapsed,
        isFirstRound: false,
        hasBloom: false
    )

    assert(draggingAtDrawEnd.stage == .draw && draggingAtDrawEnd.drawProgress == 0)
    assert(draggingAfterDrawEnd.stage == .draw)
    assert(firstRoundAfterDrawEnd.stage == .draw)
    assert(abs(draggingAfterDrawEnd.drawProgress - resumed.drawProgress) < 1e-12)
    print(
        "dragging: draw end = \(draggingAtDrawEnd.drawProgress), "
            + "after end = \(draggingAfterDrawEnd.drawProgress), "
            + "first round after end = \(firstRoundAfterDrawEnd.drawProgress)"
    )
    print(
        "resume continuity error = "
            + "\(abs(draggingAfterDrawEnd.drawProgress - resumed.drawProgress))"
    )
}
#endif
