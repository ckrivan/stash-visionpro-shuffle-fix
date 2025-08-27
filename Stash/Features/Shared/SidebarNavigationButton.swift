import SwiftUI

struct SidebarNavigationButton: View {
  let title: String
  let icon: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      // Navigation style aligned to left
      HStack(spacing: 12) {
        // Icon with background for selected state
        ZStack {
          // Background circle for selected state
          Circle()
            .fill(isSelected ? .white : .clear)
            .frame(width: 32, height: 32)

          // Icon
          Image(systemName: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
        }

        // Label
        Text(title)
          .font(.subheadline)
          .fontWeight(isSelected ? .medium : .regular)
          .foregroundStyle(isSelected ? .white : .white.opacity(0.8))

        Spacer()
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
    .cornerRadius(10)
    .hoverEffect(.highlight)
  }
}
