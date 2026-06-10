import CoreLocation
import SwiftUI

/// A self-contained, shareable summary card for a finished cardio session — rendered to an image via
/// `ImageRenderer` and shared from the cardio detail (replaces the old plain-text share). Strava-ish:
/// the route silhouette (for GPS sessions) or a large activity glyph, the headline stats, and Villain
/// Arc branding. Uses only explicit colors/sizes so it renders correctly off-screen.
struct CardioShareCard: View {
    let session: CardioSession
    let distanceUnit: DistanceUnit
    let energyUnit: EnergyUnit

    // Fixed canvas; ImageRenderer captures exactly this.
    static let size = CGSize(width: 1080, height: 1350)

    private var tint: Color {
        switch session.activity {
        case .run: return .orange
        case .walk: return .blue
        case .cycle: return .green
        case .hike: return .mint
        case .swim: return .teal
        default: return .purple
        }
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        session.sortedRoutePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 0)

            if routeCoordinates.count >= 2 {
                RouteSilhouette(coordinates: routeCoordinates, color: tint)
                    .frame(height: 520)
                    .padding(.horizontal, 80)
            } else {
                Image(systemName: session.systemImage)
                    .font(.system(size: 280, weight: .semibold))
                    .foregroundStyle(tint.gradient)
                    .frame(maxWidth: .infinity)
                    .frame(height: 520)
            }

            Spacer(minLength: 0)

            statsRow
            branding
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(
                colors: [Color.black, Color(white: 0.10), tint.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 28) {
            ZStack {
                Circle()
                    .fill(tint.gradient)
                    .frame(width: 120, height: 120)
                Image(systemName: session.systemImage)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(session.displayTitle)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let startedAt = session.startedAt {
                    Text(startedAt.formatted(.dateTime.weekday(.wide).month().day().year()))
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 80)
        .padding(.top, 90)
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 8) {
                    Text(stat.value)
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(stat.label.uppercased())
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(tint)
                        .tracking(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 80)
    }

    private var branding: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(tint)
            Text("VILLAIN ARC")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(4)
            Spacer()
        }
        .padding(.horizontal, 80)
        .padding(.top, 56)
        .padding(.bottom, 90)
    }

    private struct ShareStat: Identifiable {
        let id: String
        let label: String
        let value: String
    }

    private var stats: [ShareStat] {
        var items: [ShareStat] = []
        if session.totalDistanceMeters > 0 {
            items.append(ShareStat(id: "distance", label: "Distance", value: formattedDistanceText(session.totalDistanceMeters, unit: distanceUnit)))
        }
        items.append(ShareStat(id: "time", label: "Time", value: secondsToTimeWithHours(Int(session.duration.rounded()))))
        if let pace = formattedPaceText(duration: session.duration, distanceMeters: session.totalDistanceMeters, distanceUnit: distanceUnit) {
            items.append(ShareStat(id: "pace", label: "Pace", value: pace))
        } else if let avgHR = session.healthWorkout?.averageHeartRateBPM {
            items.append(ShareStat(id: "hr", label: "Avg HR", value: formattedHeartRateText(avgHR)))
        } else if let energy = session.healthWorkout?.activeEnergyBurned {
            items.append(ShareStat(id: "energy", label: "Energy", value: formattedEnergyText(energy, unit: energyUnit)))
        }
        return items
    }
}

/// A normalized polyline of the route, projected so the shape's aspect ratio is correct (longitude is
/// scaled by cos(latitude)). Drawn as a rounded stroke — the Strava-style route silhouette.
private struct RouteSilhouette: View {
    let coordinates: [CLLocationCoordinate2D]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = projectedPoints(in: proxy.size)
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))

                if let start = points.first {
                    Circle().fill(.green).frame(width: 34, height: 34).position(start)
                }
                if let end = points.last {
                    Circle().fill(.red).frame(width: 34, height: 34).position(end)
                }
            }
        }
    }

    private func projectedPoints(in size: CGSize) -> [CGPoint] {
        guard coordinates.count >= 2 else { return [] }
        let latitudes = coordinates.map(\.latitude)
        let meanLat = (latitudes.reduce(0, +) / Double(latitudes.count)) * .pi / 180
        let lonScale = max(cos(meanLat), 0.01)

        let projected = coordinates.map { CGPoint(x: $0.longitude * lonScale, y: $0.latitude) }
        let xs = projected.map(\.x), ys = projected.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        let spanX = max(maxX - minX, 1e-9), spanY = max(maxY - minY, 1e-9)

        let inset: CGFloat = 24
        let drawW = size.width - inset * 2, drawH = size.height - inset * 2
        let scale = min(drawW / spanX, drawH / spanY)
        let offsetX = inset + (drawW - spanX * scale) / 2
        let offsetY = inset + (drawH - spanY * scale) / 2

        return projected.map { point in
            let x = offsetX + (point.x - minX) * scale
            // Flip y: latitude increases north (up), screen y increases down.
            let y = offsetY + (maxY - point.y) * scale
            return CGPoint(x: x, y: y)
        }
    }
}
