import SwiftUI

struct VPNStatusIndicator: View {
  @StateObject private var networkMonitor = NetworkMonitor()
  @State private var showDetails = false

  var body: some View {
    HStack(spacing: 8) {
      // VPN icon with status color
      Image(systemName: vpnIconName)
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(statusColor)
        .symbolEffect(.pulse, isActive: networkMonitor.networkMode == .vpn)

      // Network mode text
      Text(networkModeText)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(statusColor)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(backgroundMaterial)
    .clipShape(Capsule())
    .onTapGesture {
      showDetails.toggle()
    }
    .popover(isPresented: $showDetails) {
      VPNDetailsPopover(networkMonitor: networkMonitor)
    }
  }

  private var vpnIconName: String {
    switch networkMonitor.networkMode {
    case .vpn:
      return "shield.fill"
    case .local:
      return "house.fill"
    case .remote:
      return "network"
    }
  }

  private var statusColor: Color {
    switch networkMonitor.networkMode {
    case .vpn:
      return .blue
    case .local:
      return .green
    case .remote:
      return .orange
    }
  }

  private var networkModeText: String {
    switch networkMonitor.networkMode {
    case .vpn:
      return "VPN"
    case .local:
      return "Local"
    case .remote:
      return "Remote"
    }
  }

  private var backgroundMaterial: some ShapeStyle {
    switch networkMonitor.networkMode {
    case .vpn:
      return AnyShapeStyle(.ultraThinMaterial.opacity(0.8))
    case .local:
      return AnyShapeStyle(.ultraThinMaterial.opacity(0.6))
    case .remote:
      return AnyShapeStyle(.ultraThinMaterial.opacity(0.7))
    }
  }
}

struct VPNDetailsPopover: View {
  let networkMonitor: NetworkMonitor

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: iconName)
          .font(.title2)
          .foregroundColor(statusColor)

        VStack(alignment: .leading) {
          Text("Network Status")
            .font(.headline)
          Text(networkMonitor.networkMode.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        Spacer()
      }

      Divider()

      VStack(alignment: .leading, spacing: 8) {
        VPNDetailRow(title: "VPN Active", value: networkMonitor.isUsingVPN ? "Yes" : "No")
        VPNDetailRow(title: "Local Network", value: networkMonitor.isOnLocalNetwork ? "Yes" : "No")
        VPNDetailRow(title: "Optimization", value: optimizationDescription)
      }

      if networkMonitor.networkMode == .vpn {
        Divider()

        VStack(alignment: .leading, spacing: 4) {
          Text("VPN Optimizations Active:")
            .font(.caption)
            .fontWeight(.semibold)

          Text("• Single Bearer token auth")
            .font(.caption2)
          Text("• Reduced API calls")
            .font(.caption2)
          Text("• Deferred thumbnail loading")
            .font(.caption2)
        }
        .foregroundColor(.secondary)
      }
    }
    .padding()
    .frame(width: 280)
  }

  private var iconName: String {
    switch networkMonitor.networkMode {
    case .vpn:
      return "shield.fill"
    case .local:
      return "house.fill"
    case .remote:
      return "network"
    }
  }

  private var statusColor: Color {
    switch networkMonitor.networkMode {
    case .vpn:
      return .blue
    case .local:
      return .green
    case .remote:
      return .orange
    }
  }

  private var optimizationDescription: String {
    switch networkMonitor.networkMode {
    case .vpn:
      return "VPN Optimized"
    case .local:
      return "Full Featured"
    case .remote:
      return "Remote Optimized"
    }
  }
}

struct VPNDetailRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)

      Spacer()

      Text(value)
        .font(.caption)
        .fontWeight(.medium)
    }
  }
}

#Preview {
  VPNStatusIndicator()
}
