import SwiftUI

struct NavigationButton: View {
  let title: String
  let icon: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 24))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(isSelected ? .primary : .secondary)

        Text(title)
          .font(.caption)
          .foregroundStyle(isSelected ? .primary : .secondary)
      }
      .frame(width: 60, height: 60)
    }
    .buttonStyle(.plain)
  }
}
