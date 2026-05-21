/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import Foundation
import Combine
import AppKit
import Defaults
import SwiftUI

@MainActor
class CapsLockManager: ObservableObject {
    static let shared = CapsLockManager()
    
    @Published var isCapsLockActive: Bool = false
    
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var isMonitoring = false
    private var cancellables = Set<AnyCancellable>()
    private let coordinator = DynamicIslandViewCoordinator.shared
    private let capsLockAnimation = Animation.spring(response: 0.32, dampingFraction: 0.85)
    
    private init() {
        isCapsLockActive = NSEvent.modifierFlags.contains(.capsLock)

        Defaults.publisher(.enableCapsLockIndicator, options: [])
            .sink { [weak self] change in
                guard let self else { return }
                if change.newValue {
                    self.startMonitoring()
                } else {
                    self.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        if Defaults[.enableCapsLockIndicator] {
            startMonitoring()
        }
    }
    
    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        cancellables.removeAll()
    }

    private func startMonitoring() {
        guard !isMonitoring else { return }
        isCapsLockActive = NSEvent.modifierFlags.contains(.capsLock)

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
        isMonitoring = true
        print("CapsLockManager: ✅ Initialized with Caps Lock \(isCapsLockActive ? "ON" : "OFF")")
    }
    
    private func stopMonitoring() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        isMonitoring = false
        isCapsLockActive = false
        if coordinator.sneakPeek.type == .capsLock {
            coordinator.toggleSneakPeek(status: false, type: .capsLock)
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        guard Defaults[.enableCapsLockIndicator] else { return }
        let newState = event.modifierFlags.contains(.capsLock)
        
        guard newState != isCapsLockActive else { return }
        
        withAnimation(capsLockAnimation) {
            isCapsLockActive = newState
        }
        
        print("CapsLockManager: Caps Lock \(newState ? "ACTIVATED" : "DEACTIVATED")")
        
        // Only show/hide if feature is enabled
        guard Defaults[.enableCapsLockIndicator] else { return }
        
        if newState {
            // Show inline indicator
            coordinator.toggleSneakPeek(
                status: true,
                type: .capsLock,
                duration: .infinity, // Stay visible until deactivated
                value: 1.0,
                icon: ""
            )
        } else {
            // Hide indicator
            coordinator.toggleSneakPeek(
                status: false,
                type: .capsLock,
                duration: 0,
                value: 0,
                icon: ""
            )
        }
    }
}
