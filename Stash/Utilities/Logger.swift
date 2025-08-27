import Foundation
import os.log

extension Logger {
  static let connection = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.stashvp.app", category: "Connection")
}
