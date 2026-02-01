import AppIntents
import SwiftUI

struct RestTimerSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Rest Timer"
    static let isDiscoverable: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        return .result {
            RestTimerSnippetView()
        }
    }
}

struct RestTimerSnippetView: View {
    let restTimer = RestTimerState.shared

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            timerDisplay
            
            controls
        }
        .padding()
    }
    
    @ViewBuilder
    private var controls: some View {
        if restTimer.isRunning {
            HStack(spacing: 16) {
                Button(intent: RestTimerControlIntent(action: .stop)) {
                    Text("Stop")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)

                Button(intent: RestTimerControlIntent(action: .pause)) {
                    Text("Pause")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                }
                .tint(.yellow)
            }
        } else if restTimer.isPaused {
            HStack(spacing: 16) {
                Button(intent: RestTimerControlIntent(action: .stop)) {
                    Text("Stop")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
                
                Button(intent: RestTimerControlIntent(action: .resume)) {
                    Text("Resume")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        if restTimer.isRunning, let endDate = restTimer.endDate, endDate > Date() {
            VStack(spacing: 6) {
                Text("\(Image(systemName: "bell")) \(endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(timerInterval: .now...endDate, countsDown: true)
                    .font(.system(size: 80, weight: .bold))
            }
        } else {
            if restTimer.isPaused {
                HStack(spacing: 12) {
                    Text(secondsToTime(restTimer.pausedRemainingSeconds))
                        .font(.system(size: 80, weight: .bold))
                        .contentTransition(.numericText())
                }
            } else {
                Text("No Active Timer")
                    .font(.system(size: 80, weight: .bold))
            }
        }
    }
    
}
