import Foundation
import Network
import SystemConfiguration

enum NetworkMode: Equatable {
  case local
  case vpn
  case remote

  var description: String {
    switch self {
    case .local: return "Local Network"
    case .vpn: return "VPN Connection"
    case .remote: return "Remote Connection"
    }
  }
}

@MainActor
class NetworkMonitor: ObservableObject {
  @Published var networkMode: NetworkMode = .local
  @Published var isUsingVPN = false
  @Published var isOnLocalNetwork = false

  private let monitor = NWPathMonitor()
  private let serverAddress = "http://192.168.86.100:9999"

  init() {
    startMonitoring()
    updateNetworkMode()
  }

  deinit {
    monitor.cancel()
  }

  private func startMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in
        self?.handlePathUpdate(path)
      }
    }
    monitor.start(queue: DispatchQueue.global(qos: .utility))
  }

  private func handlePathUpdate(_ path: NWPath) {
    let wasUsingVPN = isUsingVPN
    let wasOnLocal = isOnLocalNetwork

    // Detect VPN by checking interface names
    isUsingVPN = detectVPNInterfaces(path: path) || detectVPNByInterfaces()

    // Check if server is on local network
    isOnLocalNetwork = checkLocalNetwork()

    // Update network mode if changed
    let newMode = determineNetworkMode()
    if networkMode != newMode || wasUsingVPN != isUsingVPN || wasOnLocal != isOnLocalNetwork {
      networkMode = newMode
      logNetworkChange(from: (wasUsingVPN, wasOnLocal), to: (isUsingVPN, isOnLocalNetwork))
    }
  }

  private func detectVPNInterfaces(path: NWPath) -> Bool {
    // Check if default route is through a VPN interface
    for interface in path.availableInterfaces {
      let name = interface.name

      // Skip system utun interfaces - macOS creates many for system services
      if name.hasPrefix("utun") {
        // System utun interfaces are typically not used for routing traffic
        // Real VPNs typically create routes that become default routes
        continue
      }

      // These are more likely to be actual VPN interfaces
      if name.hasPrefix("tun")  // OpenVPN, other VPNs (but not utun)
        || name.hasPrefix("ppp")  // L2TP, PPTP
        || name.hasPrefix("ipsec")  // IPSec VPNs
        || name.hasPrefix("wg")  // WireGuard (some implementations)
        || name.contains("vpn")  // Some VPNs have "vpn" in name
        || name.contains("wireguard") {  // WireGuard specific
        return true
      }
    }

    return false
  }

  private func detectVPNByInterfaces() -> Bool {
    // Check if default route goes through a VPN interface
    // Most reliable method: check routing table for default route

    // First, get the default route interface
    if let defaultInterface = getDefaultRouteInterface() {
      print("🔍 Default route interface: \(defaultInterface)")

      // If default route goes through utun interface, check if it has an IP address
      if defaultInterface.hasPrefix("utun") {
        return checkUtunInterfaceForVPN(defaultInterface)
      }

      // Check for other VPN interface types
      let vpnPrefixes = ["tun", "ppp", "ipsec", "wg"]
      for prefix in vpnPrefixes {
        if defaultInterface.hasPrefix(prefix) {
          print("🔍 VPN interface detected: \(defaultInterface)")
          return true
        }
      }

      // Check for VPN-specific names
      if defaultInterface.contains("vpn") || defaultInterface.contains("wireguard") {
        print("🔍 VPN interface detected: \(defaultInterface)")
        return true
      }
    }

    return false
  }

  private func getDefaultRouteInterface() -> String? {
    // Use a different approach to get default route interface
    // Check if any utun interface has both an IPv4 address and default routing behavior
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
      return nil
    }

    defer { freeifaddrs(ifaddr) }

    var utunInterfaces: [String] = []
    var addr: UnsafeMutablePointer<ifaddrs>? = firstAddr

    // Collect utun interfaces that have IPv4 addresses
    while let currentAddr = addr {
      let name = String(cString: currentAddr.pointee.ifa_name)

      if name.hasPrefix("utun") {
        // Check if this interface has an IPv4 address
        if let sockaddr = currentAddr.pointee.ifa_addr,
          sockaddr.pointee.sa_family == UInt8(AF_INET) {
          utunInterfaces.append(name)
        }
      }

      addr = currentAddr.pointee.ifa_next
    }

    // Return the first utun interface with an IPv4 address
    // This is likely the VPN interface if it exists
    return utunInterfaces.first
  }

  private func checkUtunInterfaceForVPN(_ interfaceName: String) -> Bool {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
      return false
    }

    defer { freeifaddrs(ifaddr) }

    var addr: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while let currentAddr = addr {
      let name = String(cString: currentAddr.pointee.ifa_name)

      if name == interfaceName {
        // Check if this interface has an IPv4 address (indicates active VPN)
        if let sockaddr = currentAddr.pointee.ifa_addr,
          sockaddr.pointee.sa_family == UInt8(AF_INET) {
          print("🔍 VPN detected: \(interfaceName) has IPv4 address")
          return true
        }
      }

      addr = currentAddr.pointee.ifa_next
    }

    return false
  }

  private func checkLocalNetwork() -> Bool {
    guard let serverHost = URL(string: serverAddress)?.host else {
      print("❌ Could not extract host from server address")
      return false
    }

    // Check if server is on local network ranges
    let localRanges = [
      "192.168.",  // Private Class C
      "10.",  // Private Class A
      "172.16.",  // Private Class B start
      "172.17.", "172.18.", "172.19.", "172.20.", "172.21.", "172.22.", "172.23.",
      "172.24.", "172.25.", "172.26.", "172.27.", "172.28.", "172.29.", "172.30.", "172.31.",
      "127.",  // Loopback
      "169.254."  // Link-local
    ]

    return localRanges.contains { serverHost.hasPrefix($0) }
  }

  private func determineNetworkMode() -> NetworkMode {
    if isUsingVPN && isOnLocalNetwork {
      return .vpn
    } else if isOnLocalNetwork {
      return .local
    } else {
      return .remote
    }
  }

  private func logNetworkChange(from oldState: (Bool, Bool), to newState: (Bool, Bool)) {
    let (oldVPN, oldLocal) = oldState
    let (newVPN, newLocal) = newState

    print("🌐 Network mode changed: \(networkMode.description)")
    print("   VPN: \(oldVPN) → \(newVPN)")
    print("   Local: \(oldLocal) → \(newLocal)")

    // Log optimization recommendations
    switch networkMode {
    case .local:
      print("   💡 Using full-featured local mode")
    case .vpn:
      print("   💡 Using VPN optimizations (reduced handshakes)")
    case .remote:
      print("   💡 Using remote optimizations (HLS preferred)")
    }
  }

  // Force update network mode (useful for testing)
  func updateNetworkMode() {
    // First log all available interfaces for debugging
    logAllInterfaces()

    isUsingVPN = detectVPNByInterfaces()
    isOnLocalNetwork = checkLocalNetwork()
    networkMode = determineNetworkMode()

    print("🔍 Network detection results:")
    print("   Server: \(serverAddress)")
    print("   VPN detected: \(isUsingVPN)")
    print("   Local network: \(isOnLocalNetwork)")
    print("   Mode: \(networkMode.description)")
  }

  // Debug method to log all network interfaces
  private func logAllInterfaces() {
    print("📡 All network interfaces:")

    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
      print("   Failed to get interfaces")
      return
    }

    defer { freeifaddrs(ifaddr) }

    var addr: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while let currentAddr = addr {
      let name = String(cString: currentAddr.pointee.ifa_name)
      let flags = currentAddr.pointee.ifa_flags
      let isUp = (flags & UInt32(IFF_UP)) != 0
      let isRunning = (flags & UInt32(IFF_RUNNING)) != 0

      print("   \(name): up=\(isUp), running=\(isRunning)")

      addr = currentAddr.pointee.ifa_next
    }
  }

  // Test method to simulate different network conditions
  func simulateNetworkMode(_ mode: NetworkMode) {
    networkMode = mode
    switch mode {
    case .local:
      isUsingVPN = false
      isOnLocalNetwork = true
    case .vpn:
      isUsingVPN = true
      isOnLocalNetwork = true
    case .remote:
      isUsingVPN = false
      isOnLocalNetwork = false
    }
    print("🧪 Simulating network mode: \(mode.description)")
  }
}
