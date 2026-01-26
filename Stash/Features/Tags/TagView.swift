import SwiftUI

struct TagView: View {
  let text: String
  let isPrimary: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      Text(text)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isPrimary ? Color.blue : Color.gray.opacity(0.2))
        .foregroundColor(isPrimary ? .white : .primary)
        .clipShape(Capsule())
    }
  }
}
