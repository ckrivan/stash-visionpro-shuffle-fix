import SwiftUI

// Custom icons loader to directly load icons from bundle
struct IconImage: View {
  let name: String
  var width: CGFloat = 30
  var height: CGFloat = 30
  var color: Color?

  var body: some View {
    if let uiImage = loadIconImage(name: name) {
      Image(uiImage: uiImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: width, height: height)
        .if(color != nil) { view in
          view.foregroundStyle(color!)
        }
    } else {
      // Fallback to system icon if custom icon isn't found
      Image(systemName: fallbackIcon(for: name))
        .font(.system(size: width))
        .frame(width: width, height: height)
        .if(color != nil) { view in
          view.foregroundStyle(color!)
        }
    }
  }

  private func fallbackIcon(for name: String) -> String {
    switch name {
    case "direct2hls", "globe": return "network"
    case "close": return "xmark.circle"
    case "shuffle": return "arrow.triangle.2.circlepath"
    case "performershuffle": return "person.2.gobackward"
    case "play": return "play.circle"
    case "pause": return "pause.circle"
    default: return "questionmark.circle"
    }
  }
}

// Helper function to load custom icons from the app bundle
func loadIconImage(name: String) -> UIImage? {
  // First try to load from the bundle's Resources/Icons directory
  if let bundleURL = Bundle.main.url(forResource: "Icons/\(name)", withExtension: "png"),
    let data = try? Data(contentsOf: bundleURL) {
    return UIImage(data: data)
  }

  // If that fails, try to load directly from the app's main bundle
  if let bundleImage = UIImage(named: name) {
    return bundleImage
  }

  // Next, try to load from the documents directory (for custom installed icons)
  let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  let iconPath = documentsPath.appendingPathComponent("Icons/\(name).png")
  if let data = try? Data(contentsOf: iconPath) {
    return UIImage(data: data)
  }

  // Finally, try looking in the main app directory
  let mainPath = Bundle.main.bundlePath
  let mainIconPath = URL(fileURLWithPath: mainPath).appendingPathComponent("Icons/\(name).png")
  if let data = try? Data(contentsOf: mainIconPath) {
    return UIImage(data: data)
  }

  // If we still can't find it, look in the parent directory of the bundle
  let parentPath = URL(fileURLWithPath: mainPath).deletingLastPathComponent().path
  let parentIconPath = URL(fileURLWithPath: parentPath).appendingPathComponent("Icons/\(name).png")
  if let data = try? Data(contentsOf: parentIconPath) {
    return UIImage(data: data)
  }

  return nil
}

// Helper extension to conditionally apply modifiers
extension View {
  @ViewBuilder
  func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}
