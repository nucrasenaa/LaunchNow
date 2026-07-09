import SwiftUI
import AppKit

enum LaunchpadBackgroundPreset: String, CaseIterable, Identifiable {
    case system
    case aurora
    case graphite
    case sunset
    case forest
    case customImage

    var id: String { rawValue }
}

enum LaunchpadAppearancePreset: String, CaseIterable, Identifiable {
    case glass
    case dark
    case light
    case compact
    case classicLaunchpad

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        case .glass, .compact, .classicLaunchpad:
            return nil
        }
    }

    var surfaceTint: Color {
        switch self {
        case .glass, .classicLaunchpad:
            return .clear
        case .dark:
            return .black
        case .light:
            return .white
        case .compact:
            return .primary
        }
    }

    var surfaceTintOpacity: Double {
        switch self {
        case .glass, .classicLaunchpad:
            return 0
        case .dark:
            return 0.22
        case .light:
            return 0.16
        case .compact:
            return 0.08
        }
    }

    var contentPadding: CGFloat {
        switch self {
        case .compact:
            return 10
        case .glass, .dark, .light, .classicLaunchpad:
            return 16
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact:
            return 22
        case .glass, .dark, .light, .classicLaunchpad:
            return 30
        }
    }

    var isCompact: Bool {
        self == .compact
    }
}

struct LaunchpadBackgroundView: View {
    @ObservedObject var appStore: AppStore

    var body: some View {
        ZStack {
            backgroundContent
                .scaleEffect(1 + CGFloat(appStore.backgroundBlur / 180))
                .blur(radius: appStore.backgroundBlur)

            Color.black
                .opacity((1 - appStore.backgroundOpacity) * 0.7)
        }
        .ignoresSafeArea()
        .animation(LNAnimations.gridUpdate, value: appStore.backgroundPreset)
        .animation(LNAnimations.gridUpdate, value: appStore.backgroundOpacity)
        .animation(LNAnimations.gridUpdate, value: appStore.backgroundBlur)
        .animation(LNAnimations.gridUpdate, value: appStore.customBackgroundImagePath)
    }

    @ViewBuilder
    private var backgroundContent: some View {
        switch appStore.backgroundPreset {
        case .system:
            Color.clear
        case .aurora:
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.20, blue: 0.34),
                    Color(red: 0.19, green: 0.52, blue: 0.56),
                    Color(red: 0.74, green: 0.35, blue: 0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .graphite:
            RadialGradient(
                colors: [
                    Color(red: 0.34, green: 0.36, blue: 0.40),
                    Color(red: 0.12, green: 0.13, blue: 0.15),
                    Color(red: 0.03, green: 0.04, blue: 0.05)
                ],
                center: .topTrailing,
                startRadius: 60,
                endRadius: 900
            )
        case .sunset:
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.58, blue: 0.30),
                    Color(red: 0.72, green: 0.29, blue: 0.47),
                    Color(red: 0.18, green: 0.18, blue: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .forest:
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.28, blue: 0.22),
                    Color(red: 0.26, green: 0.42, blue: 0.24),
                    Color(red: 0.71, green: 0.65, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .customImage:
            customImageBackground
        }
    }

    @ViewBuilder
    private var customImageBackground: some View {
        if let url = appStore.customBackgroundImageURL,
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.20, blue: 0.34),
                    Color(red: 0.19, green: 0.52, blue: 0.56),
                    Color(red: 0.74, green: 0.35, blue: 0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
