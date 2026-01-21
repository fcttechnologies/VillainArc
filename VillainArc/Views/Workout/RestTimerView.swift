import SwiftUI
import SwiftData

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RestTimerState.self) private var restTimer
    @Environment(\.modelContext) private var context
    @Query(RestTimeHistory.recents) private var recentTimes: [RestTimeHistory]
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
                        Text(secondsToTime(restTimer.isPaused ? restTimer.pausedRemainingSeconds : selectedSeconds))
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
                            Text(secondsToTime(history.seconds))
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button {
                                Haptics.success()
                                restTimer.start(seconds: history.seconds)
                                RestTimeHistory.record(seconds: history.seconds, context: context)
                                saveContext(context: context)
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
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.yellow)
                
                Button {
                    Haptics.warning()
                    restTimer.stop()
                } label: {
                    Text("Stop")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
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
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.green)
                
                Button {
                    Haptics.warning()
                    restTimer.stop()
                } label: {
                    Text("Stop")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
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
                saveContext(context: context)
            } label: {
                Text("Start")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.vertical, 5)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .tint(.green)
        }
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
