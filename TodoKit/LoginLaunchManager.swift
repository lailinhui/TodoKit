import Foundation
import ServiceManagement
import Combine

@MainActor
final class LoginLaunchManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = SMAppService.mainApp.status == .enabled

    func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            isEnabled = enabled
            return nil
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            return "设置开机启动失败：\(error.localizedDescription)"
        }
    }
}
