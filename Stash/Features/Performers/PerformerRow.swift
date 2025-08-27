import SwiftUI

struct PerformerRow: View {
  let performer: StashScene.Performer

  var body: some View {
    VStack {
      // Performer Image
      if let imagePath = performer.image_path,
        let url = URL(string: imagePath) {
        AsyncImage(url: url) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Rectangle()
            .fill(.ultraThinMaterial)
        }
        .frame(width: 160, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))
      } else {
        Rectangle()
          .fill(.ultraThinMaterial)
          .frame(width: 160, height: 200)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .overlay {
            Image(systemName: "person.fill")
              .font(.system(size: 40))
              .foregroundStyle(.secondary)
          }
      }

      // Performer Info
      VStack(alignment: .leading, spacing: 4) {
        Text(performer.name)
          .font(.headline)
          .lineLimit(1)

        HStack(spacing: 8) {
          if let sceneCount = performer.scene_count {
            Label("\(sceneCount)", systemImage: "film")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let imageCount = performer.image_count {
            Label("\(imageCount)", systemImage: "photo")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let gender = performer.gender {
            Text(gender)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
    }
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .hoverEffect(.lift)
  }
}
