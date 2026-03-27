import SwiftUI

/// Chronological list of drink events, grouped by hour.
struct EventLogView: View {
    @Environment(EventLogViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isEmpty {
                    VepoEmptyState(
                        icon: "drop.triangle",
                        title: "No drinks yet",
                        message: "Connect your Vepo bottle and drink events will appear here automatically."
                    )
                } else {
                    eventList
                }
            }
            .background(VepoTheme.Colors.background)
            .navigationTitle("Event Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { viewModel.selectedDate },
                            set: { date in
                                Task { await viewModel.selectDate(date) }
                            }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
            }
            .task {
                await viewModel.loadEvents()
            }
            .refreshable {
                await viewModel.loadEvents()
            }
        }
    }

    private var eventList: some View {
        List {
            ForEach(viewModel.groupedByHour, id: \.hour) { group in
                Section(group.hour) {
                    ForEach(group.events, id: \.id) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}
