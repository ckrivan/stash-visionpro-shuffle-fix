import SwiftUI

struct PerformerHeaderView: View {
  let performer: StashScene.Performer

  var body: some View {
    VStack(spacing: 16) {
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
        .frame(width: 200, height: 200)
        .clipShape(Circle())
      } else {
        Circle()
          .fill(.ultraThinMaterial)
          .frame(width: 200, height: 200)
          .overlay {
            Image(systemName: "person.fill")
              .font(.system(size: 60))
              .foregroundStyle(.secondary)
          }
      }

      // Performer Info
      VStack(spacing: 8) {
        Text(performer.name)
          .font(.title)
          .fontWeight(.semibold)

        HStack(spacing: 16) {
          Text("\(performer.scene_count ?? 0) scenes")
            .foregroundStyle(.secondary)
          Text("•")
            .foregroundStyle(.secondary)
          Text("\(performer.image_count ?? 0) images")
            .foregroundStyle(.secondary)
        }

        if let gender = performer.gender {
          Text(gender)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 20))
  }
}
