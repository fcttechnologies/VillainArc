import SwiftUI
import SwiftData

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RestTimerState.self) private var restTimer
    @Environment(\.modelContext) private var context
    @Query(sort: \RestTimeHistory.lastUsed, order: .reverse) private var recentTimes: [RestTimeHistory]
    @State private var selectedSeconds = RestTimePolicy.defaultRestSeconds
    
    var body: some View {
        NavigationStack {
            List {
                Group {
                    if restTimer.isRunning, let endDate = restTimer.endDate {
                        VStack(spacing: 6) {
                            Text("\(Image(systemName: "bell")) \(endDate.formatted(date: .omitted, time: .shortened))")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text(endDate, style: .timer)
                                .font(.system(size: 80, weight: .bold))
                        }
                    } else {
                        Text(format(seconds: restTimer.isPaused ? restTimer.remainingSeconds : selectedSeconds))
                            .font(.system(size: 80, weight: .bold))
                            .contentTransition(.numericText())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
                
                if !restTimer.isActive {
                    TimerDurationPicker(seconds: $selectedSeconds, showZero: false)
                        .frame(height: 60)
                        .listRowSeparator(.hidden)
                }
                
                controls
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                
                if !restTimer.isActive && !recentTimes.isEmpty {
                    Text("Recents")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                    ForEach(recentTimes) { history in
                        HStack {
                            Text(format(seconds: history.seconds))
                                .font(.title)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            
                            Spacer()
                            
                            Button {
                                Haptics.success()
                                restTimer.start(seconds: history.seconds)
                                RestTimeHistory.record(seconds: history.seconds, context: context)
                            } label: {
                                Image(systemName: "play.fill")
                                    .padding()
                                    .fontWeight(.semibold)
                                    .font(.title2)
                            }
                            .buttonBorderShape(.circle)
                            .buttonStyle(.glassProminent)
                            .tint(.green)
                        }
                    }
                    .onDelete(perform: deleteRecentTimes)
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        Haptics.success()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let recent = recentTimes.first {
                    selectedSeconds = recent.seconds
                }
            }
        }
    }
    
    @ViewBuilder
    private var controls: some View {
        if restTimer.isRunning {
            HStack(spacing: 16) {
                Button {
                    Haptics.selection()
                    restTimer.pause()
                } label: {
                    Text("Pause")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.yellow)
                
                Button {
                    Haptics.warning()
                    restTimer.stop()
                } label: {
                    Text("Stop")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.red)
            }
        } else if restTimer.isPaused {
            HStack(spacing: 16) {
                Button {
                    Haptics.selection()
                    restTimer.resume()
                } label: {
                    Text("Resume")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.green)
                
                Button {
                    Haptics.warning()
                    restTimer.stop()
                } label: {
                    Text("Stop")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.red)
            }
        } else {
            Button {
                Haptics.success()
                restTimer.start(seconds: selectedSeconds)
                RestTimeHistory.record(seconds: selectedSeconds, context: context)
            } label: {
                Text("Start")
                    .padding(.vertical, 8)
                    .fontWeight(.semibold)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .tint(.green)
        }
    }
    
    private func format(seconds: Int) -> String {
        let minutes = max(0, seconds / 60)
        let remainingSeconds = max(0, seconds % 60)
        return "\(minutes):" + String(format: "%02d", remainingSeconds)
    }
    
    private func deleteRecentTimes(at offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.warning()
        
        for index in offsets {
            let history = recentTimes[index]
            context.delete(history)
        }
        saveContext(context: context)
    }
}

#Preview {
    RestTimerView()
        .environment(RestTimerState())
        .sampleDataConainer()
}
