//
//  WidgetReloadCoordinator.swift
//  Remmy
//
//  Single coordinator for all WidgetKit timeline reloads.
//  Replaces three independent debounce paths (ActivityStore, WatchService, AppDelegate)
//  with one shared debounce timer to prevent redundant WidgetCenter calls.
//

import WidgetKit
import os

private let logger = Logger(subsystem: "com.edgeoftrust.remmy", category: "WidgetReload")

/// Unified widget timeline reload coordinator.
/// All widget reload requests flow through this singleton to ensure
/// a single shared debounce timer prevents redundant WidgetCenter calls.
///
/// Uses trailing-edge debounce: if a request arrives during the cooldown window,
/// it schedules a deferred reload so the latest state is always reflected.
@MainActor
final class WidgetReloadCoordinator {

    static let shared = WidgetReloadCoordinator()

    /// Minimum interval between WidgetCenter.shared.reloadTimelines calls
    private let debounceInterval: TimeInterval = 5.0

    /// Tracks when the last reload was actually dispatched
    private var lastReload: Date?

    /// Pending deferred reload task (trailing edge)
    private var deferredReload: Task<Void, Never>?

    /// Widget kind identifier
    private let widgetKind = "RemmyWidget"

    private init() {}

    /// Request a widget timeline reload.
    /// Trailing-edge debounce: fires immediately if outside the cooldown window,
    /// otherwise schedules a deferred reload when the window expires.
    /// Safe to call from any path (ActivityStore, WatchService, AppDelegate).
    func requestReload() {
        let now = Date()

        if let last = lastReload, now.timeIntervalSince(last) < debounceInterval {
            // Inside cooldown — schedule trailing reload if not already pending
            if deferredReload == nil {
                let remaining = debounceInterval - now.timeIntervalSince(last)
                deferredReload = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(remaining))
                    guard !Task.isCancelled else { return }
                    self?.fireReload()
                    self?.deferredReload = nil
                }
            }
            return
        }

        // Outside cooldown — fire immediately
        deferredReload?.cancel()
        deferredReload = nil
        fireReload()
    }

    private func fireReload() {
        lastReload = Date()
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
