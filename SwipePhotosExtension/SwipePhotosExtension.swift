import WidgetKit
import SwiftUI

// MARK: - Placeholder Photo Model
struct PhotoItem {
    let text: String
    let timestamp: Date
}

// MARK: - Timeline Entry
struct PhotoEntry: TimelineEntry {
    let date: Date
    let quote: PhotoItem?
    let allQuotes: [PhotoItem]
    let currentIndex: Int
}

// MARK: - Timeline Provider
struct PhotoProvider: @MainActor TimelineProvider {
    typealias Entry = PhotoEntry
    
    // Placeholder for widget gallery
    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(
            date: Date(),
            quote: PhotoItem(text: "Your photos will appear here", timestamp: Date()),
            allQuotes: [],
            currentIndex: 0
        )
    }
    
    // Quick snapshot for widget preview
    @MainActor func getSnapshot(in context: Context, completion: @escaping (PhotoEntry) -> Void) {
        let entry = fetchCurrentEntry()
        completion(entry)
    }
    
    // Main timeline generation
    @MainActor func getTimeline(in context: Context, completion: @escaping (Timeline<PhotoEntry>) -> Void) {
        let entry = fetchCurrentEntry()

        // Use .atEnd policy so widget can be updated immediately when reloadAllTimelines() is called
        let timeline = Timeline(entries: [entry], policy: .atEnd)

        completion(timeline)
    }
    
    // Helper to fetch placeholder data
    @MainActor
    private func fetchCurrentEntry() -> PhotoEntry {
        // TODO: Implement photo fetching logic
        return PhotoEntry(
            date: Date(),
            quote: PhotoItem(text: "Coming soon", timestamp: Date()),
            allQuotes: [],
            currentIndex: 0
        )
    }
}

// MARK: - Widget View
struct SwipePhotosView: View {
    let entry: PhotoEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        // Home Screen widgets
        case .systemSmall, .systemMedium, .systemLarge:
            HomeScreenSwipePhotosView(entry: entry)
            
        // Lock Screen widgets
        case .accessoryInline:
            InlineSwipePhotosView(entry: entry)
        case .accessoryCircular:
            CircularSwipePhotosView(entry: entry)
        case .accessoryRectangular:
            RectangularSwipePhotosView(entry: entry)
        default:
            HomeScreenSwipePhotosView(entry: entry)
        }
    }
}

// MARK: - Home Screen Widget View
struct HomeScreenSwipePhotosView: View {
    let entry: PhotoEntry

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "photo.stack.fill")
                    .foregroundColor(.blue)
                Text("Swipe Photos")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            Spacer()

            // Placeholder content
            if let item = entry.quote {
                Text(item.text)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("No photos yet")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Navigation info
            if !entry.allQuotes.isEmpty {
                HStack {
                    Spacer()
                    Text("Photo \(entry.currentIndex + 1) of \(entry.allQuotes.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Lock Screen Widget Views
struct InlineSwipePhotosView: View {
    let entry: PhotoEntry

    var body: some View {
        ViewThatFits {
            if let item = entry.quote {
                Text("📸 \(item.text)")
            } else {
                Text("📸 No photos yet")
            }
        }
    }
}

struct CircularSwipePhotosView: View {
    let entry: PhotoEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "photo.stack.fill")
                    .font(.title2)
                if !entry.allQuotes.isEmpty {
                    Text("\(entry.allQuotes.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                } else {
                    Text("0")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
        }
        .containerBackground(for: .widget) { }
    }
}

struct RectangularSwipePhotosView: View {
    let entry: PhotoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "photo.stack.fill")
                    .font(.caption)
                Text("Swipe Photos")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            if let item = entry.quote {
                Text(item.text)
                    .font(.caption)
                    .lineLimit(2)
                    .widgetAccentable()
            } else {
                Text("No photos yet - Add your first photo!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .containerBackground(for: .widget) { }
    }
}

// MARK: - Widget Configuration
struct SwipePhotos: Widget {
    let kind: String = "SwipePhotosWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoProvider()) { entry in
            SwipePhotosView(entry: entry)
        }
        .configurationDisplayName("Swipe Photos Widget")
        .description("Displays your photos")
        .supportedFamilies([
            // Home Screen widgets
            .systemSmall,
            .systemMedium,
            .systemLarge,

            // Lock Screen widgets
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Widget Bundle
@main
struct SwipePhotosBundle: WidgetBundle {
    var body: some Widget {
        SwipePhotos()
    }
}

// MARK: - Preview
#Preview(as: .systemLarge) {
    SwipePhotos()
} timeline: {
    PhotoEntry(
        date: Date(),
        quote: PhotoItem(text: "Your photos will appear here", timestamp: Date()),
        allQuotes: [],
        currentIndex: 0
    )
}

#Preview("Lock Screen Rectangular", as: .accessoryCircular) {
    SwipePhotos()
} timeline: {
    PhotoEntry(
        date: Date(),
        quote: PhotoItem(text: "Coming soon", timestamp: Date()),
        allQuotes: [PhotoItem(text: "Test", timestamp: Date())],
        currentIndex: 0
    )
}
