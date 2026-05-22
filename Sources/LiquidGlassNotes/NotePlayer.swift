import SwiftUI
import AppKit
import QuartzCore

struct DisplayBlock: Identifiable {
    let id: UUID
    var x: Double
    var y: Double
    var text: String
    var opacity: Double = 1.0
}

struct DisplayStroke: Identifiable {
    let id: UUID
    var points: [CGPoint]
    var opacity: Double = 1.0
}

struct PlaybackFrame {
    var blocks: [DisplayBlock]
    var strokes: [DisplayStroke]
}

@MainActor
final class PlaybackEngine: ObservableObject {
    let events: [EditEvent]
    let totalDuration: Double
    private let cumulativeStart: [Double]
    private let durations: [Double]

    @Published var playheadTime: Double = 0
    @Published var isPlaying: Bool = false

    private var lastTick: CFTimeInterval = 0

    init(note: Note) {
        let sorted = note.history.sorted { $0.timestamp < $1.timestamp }
        self.events = sorted

        let weights = Self.computeWeights(sorted)
        let totalWeight = max(0.001, weights.reduce(0, +))
        let eventCount = sorted.count
        let dur = max(3.0, min(45.0, 4.0 + sqrt(Double(eventCount)) * 0.85))
        self.totalDuration = dur

        var cum: [Double] = []
        var durs: [Double] = []
        var t: Double = 0
        for w in weights {
            cum.append(t)
            let d = dur * (w / totalWeight)
            durs.append(d)
            t += d
        }
        self.cumulativeStart = cum
        self.durations = durs
    }

    func play() {
        if playheadTime >= totalDuration {
            playheadTime = 0
        }
        isPlaying = true
        lastTick = CACurrentMediaTime()
    }

    func pause() {
        isPlaying = false
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to t: Double) {
        playheadTime = max(0, min(totalDuration, t))
    }

    func tick() {
        guard isPlaying else { return }
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now
        playheadTime = min(totalDuration, playheadTime + dt)
        if playheadTime >= totalDuration {
            isPlaying = false
        }
    }

    func frame(at time: Double) -> PlaybackFrame {
        var blocks: [UUID: DisplayBlock] = [:]
        var blockOrder: [UUID] = []
        var strokes: [UUID: DisplayStroke] = [:]
        var strokeOrder: [UUID] = []

        for (i, event) in events.enumerated() {
            let start = cumulativeStart[i]
            let dur = durations[i]
            let end = start + dur

            if time >= end {
                applyFull(event, blocks: &blocks, blockOrder: &blockOrder,
                          strokes: &strokes, strokeOrder: &strokeOrder)
            } else if time > start {
                let progress = max(0, min(1, (time - start) / max(dur, 0.0001)))
                applyPartial(event, progress: progress,
                             blocks: &blocks, blockOrder: &blockOrder,
                             strokes: &strokes, strokeOrder: &strokeOrder)
                break
            } else {
                break
            }
        }

        return PlaybackFrame(
            blocks: blockOrder.compactMap { blocks[$0] },
            strokes: strokeOrder.compactMap { strokes[$0] }
        )
    }

    private func applyFull(_ event: EditEvent,
                           blocks: inout [UUID: DisplayBlock],
                           blockOrder: inout [UUID],
                           strokes: inout [UUID: DisplayStroke],
                           strokeOrder: inout [UUID]) {
        switch event {
        case .blockCreated(let id, let x, let y, _):
            if blocks[id] == nil { blockOrder.append(id) }
            blocks[id] = DisplayBlock(id: id, x: x, y: y, text: "")
        case .blockTextRun(let id, let text, _):
            blocks[id]?.text = text
        case .blockMoved(let id, let x, let y, _):
            blocks[id]?.x = x
            blocks[id]?.y = y
        case .blockDeleted(let id, _):
            blocks[id] = nil
            blockOrder.removeAll { $0 == id }
        case .strokeAdded(let stroke, _):
            if strokes[stroke.id] == nil { strokeOrder.append(stroke.id) }
            strokes[stroke.id] = DisplayStroke(id: stroke.id, points: stroke.points)
        case .strokeErased(let id, _):
            strokes[id] = nil
            strokeOrder.removeAll { $0 == id }
        }
    }

    private func applyPartial(_ event: EditEvent, progress: Double,
                              blocks: inout [UUID: DisplayBlock],
                              blockOrder: inout [UUID],
                              strokes: inout [UUID: DisplayStroke],
                              strokeOrder: inout [UUID]) {
        switch event {
        case .blockCreated(let id, let x, let y, _):
            if blocks[id] == nil { blockOrder.append(id) }
            blocks[id] = DisplayBlock(id: id, x: x, y: y, text: "", opacity: progress)
        case .blockTextRun(let id, let text, _):
            guard var existing = blocks[id] else { return }
            let prev = existing.text
            let common = commonPrefixCount(prev, text)
            let suffix = text.suffix(text.count - common)
            if suffix.isEmpty {
                existing.text = text
            } else {
                let chars = Int((Double(suffix.count) * progress).rounded())
                let prefix = text.prefix(common)
                existing.text = String(prefix) + String(suffix.prefix(chars))
            }
            blocks[id] = existing
        case .blockMoved(let id, let toX, let toY, _):
            guard var existing = blocks[id] else { return }
            let eased = ease(progress)
            existing.x = existing.x + (toX - existing.x) * eased
            existing.y = existing.y + (toY - existing.y) * eased
            blocks[id] = existing
        case .blockDeleted(let id, _):
            blocks[id]?.opacity = max(0, 1.0 - progress)
        case .strokeAdded(let stroke, _):
            if strokes[stroke.id] == nil { strokeOrder.append(stroke.id) }
            let count = max(2, Int((Double(stroke.points.count) * progress).rounded()))
            let partial = Array(stroke.points.prefix(count))
            strokes[stroke.id] = DisplayStroke(id: stroke.id, points: partial)
        case .strokeErased(let id, _):
            strokes[id]?.opacity = max(0, 1.0 - progress)
        }
    }

    private static func computeWeights(_ events: [EditEvent]) -> [Double] {
        var prevText: [UUID: String] = [:]
        var weights: [Double] = []
        for event in events {
            switch event {
            case .blockCreated:
                weights.append(0.5)
            case .blockTextRun(let id, let text, _):
                let prev = prevText[id] ?? ""
                let commonCount = commonPrefixCount(prev, text)
                let added = max(0, text.count - commonCount)
                weights.append(0.7 + sqrt(Double(added)) * 0.25)
                prevText[id] = text
            case .blockMoved:
                weights.append(0.7)
            case .blockDeleted:
                weights.append(0.4)
            case .strokeAdded(let stroke, _):
                weights.append(0.8 + sqrt(Double(stroke.points.count)) * 0.18)
            case .strokeErased:
                weights.append(0.4)
            }
        }
        return weights
    }

    private func ease(_ x: Double) -> Double {
        // ease in-out cubic
        if x < 0.5 {
            return 4 * x * x * x
        } else {
            let f = (2 * x - 2)
            return 1 + f * f * f / 2
        }
    }
}

private func commonPrefixCount(_ a: String, _ b: String) -> Int {
    let ac = Array(a)
    let bc = Array(b)
    let n = min(ac.count, bc.count)
    var i = 0
    while i < n && ac[i] == bc[i] { i += 1 }
    return i
}

struct NotePlayerView: View {
    let note: Note
    let onClose: () -> Void

    @StateObject private var engine: PlaybackEngine

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    init(note: Note, onClose: @escaping () -> Void) {
        self.note = note
        self.onClose = onClose
        self._engine = StateObject(wrappedValue: PlaybackEngine(note: note))
    }

    var body: some View {
        ZStack {
            PlaybackCanvas(frame: engine.frame(at: engine.playheadTime))
                .padding(.leading, 38)
                .padding(.trailing, 4)
                .padding(.top, 24)
                .padding(.bottom, 96)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack {
                Spacer()
                PlaybackControls(engine: engine, onClose: onClose)
                    .padding(.bottom, 22)
            }
        }
        .onReceive(ticker) { _ in
            if engine.isPlaying { engine.tick() }
        }
        .onAppear {
            engine.play()
        }
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }
}

struct PlaybackCanvas: View {
    let frame: PlaybackFrame

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            Canvas { context, _ in
                for stroke in frame.strokes {
                    var ctx = context
                    if stroke.opacity < 1 {
                        ctx.opacity = stroke.opacity
                    }
                    drawPencil(&ctx, points: stroke.points, seed: stroke.id.hashValue)
                }
            }

            ForEach(frame.blocks) { block in
                Text(block.text.isEmpty ? " " : block.text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.12))
                    .shadow(color: .black.opacity(0.18), radius: 1.2, x: 0.5, y: 1.2)
                    .frame(maxWidth: 480, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(x: block.x, y: block.y)
                    .opacity(block.opacity)
            }
        }
    }

    private func drawPencil(_ context: inout GraphicsContext, points: [CGPoint], seed: Int) {
        let perturbed = perturb(points, seed: seed, amount: 1.0)
        let path = smoothPath(perturbed)
        context.stroke(
            path,
            with: .color(Color(white: 0.18).opacity(0.78)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round, dash: [2.5, 0.35])
        )
    }

    private func perturb(_ points: [CGPoint], seed: Int, amount: Double) -> [CGPoint] {
        points.enumerated().map { i, p in
            let dx = (noise(seed: seed &+ i &* 2) - 0.5) * amount
            let dy = (noise(seed: seed &+ i &* 2 &+ 1) - 0.5) * amount
            return CGPoint(x: p.x + dx, y: p.y + dy)
        }
    }

    private func noise(seed: Int) -> Double {
        var s = UInt64(bitPattern: Int64(seed)) &+ 0x123456789ABCDEF
        s = (s ^ (s >> 33)) &* 0xff51afd7ed558ccd
        s = (s ^ (s >> 33)) &* 0xc4ceb9fe1a85ec53
        s = s ^ (s >> 33)
        return Double(s & 0xFFFFFFFF) / Double(UInt32.max)
    }

    private func smoothPath(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            if points.count < 3 {
                for p in points.dropFirst() { path.addLine(to: p) }
                return
            }
            for i in 1..<(points.count - 1) {
                let mid = CGPoint(
                    x: (points[i].x + points[i + 1].x) / 2,
                    y: (points[i].y + points[i + 1].y) / 2
                )
                path.addQuadCurve(to: mid, control: points[i])
            }
            if let last = points.last { path.addLine(to: last) }
        }
    }
}

struct PlaybackControls: View {
    @ObservedObject var engine: PlaybackEngine
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                engine.togglePlay()
            } label: {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            ScrubBar(
                value: engine.playheadTime,
                total: engine.totalDuration,
                onSeek: { engine.seek(to: $0) }
            )
            .frame(width: 280, height: 8)

            Text("\(format(engine.playheadTime))  /  \(format(engine.totalDuration))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Close playback")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(.white.opacity(0.10))
                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    private var iconName: String {
        if engine.playheadTime >= engine.totalDuration && !engine.isPlaying {
            return "arrow.counterclockwise"
        }
        return engine.isPlaying ? "pause.fill" : "play.fill"
    }

    private func format(_ t: Double) -> String {
        let total = Int(t.rounded())
        let s = total % 60
        let m = total / 60
        return String(format: "%d:%02d", m, s)
    }
}

struct ScrubBar: View {
    let value: Double
    let total: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: max(4, CGFloat(value / max(0.001, total)) * geo.size.width))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let frac = max(0, min(1, v.location.x / geo.size.width))
                        onSeek(frac * total)
                    }
            )
        }
    }
}
