import SwiftUI

struct TrackClip: Identifiable, Equatable {
    var id = UUID()
    var service: String
    var username: String        = ""
    var wavFile: String?        = nil   // path to WAV credential file
    var startUnit: CGFloat      // position on timeline
    var durationUnits: CGFloat  // visual width
}

struct Track: Identifiable {
    var id = UUID()
    var name: String
    var colorIndex: Int
    var clips: [TrackClip]
    var isMuted: Bool  = false
    var isSolo: Bool   = false

    var color: Color { AppTheme.clipColors[colorIndex % AppTheme.clipColors.count] }
}

// MARK: - Sample data (mirrors the Sketch design layout)
extension Track {
    static let sampleData: [Track] = [
        Track(name: "/Main Vocal", colorIndex: 0, clips: [
            TrackClip(service: "GitHub",    username: "dev@me.com",  startUnit: 0.0, durationUnits: 2.5),
            TrackClip(service: "GitLab",    username: "dev@me.com",  startUnit: 3.0, durationUnits: 3.5),
            TrackClip(service: "Bitbucket", username: "dev@me.com",  startUnit: 7.2, durationUnits: 1.5),
        ]),
        Track(name: "/Hook Vocal", colorIndex: 1, clips: [
            TrackClip(service: "Gmail",    username: "me@gmail.com", startUnit: 0.5, durationUnits: 1.5),
            TrackClip(service: "Outlook",  username: "me@msft.com",  startUnit: 2.5, durationUnits: 2.0),
            TrackClip(service: "Notion",   username: "me@gmail.com", startUnit: 6.5, durationUnits: 1.8),
        ]),
        Track(name: "Daily Builder", colorIndex: 2, clips: [
            TrackClip(service: "AWS",      username: "admin",        startUnit: 0.0, durationUnits: 1.2),
            TrackClip(service: "GCP",      username: "admin",        startUnit: 1.6, durationUnits: 1.2),
            TrackClip(service: "Azure",    username: "admin",        startUnit: 3.2, durationUnits: 1.2),
            TrackClip(service: "DO",       username: "admin",        startUnit: 5.0, durationUnits: 1.2),
            TrackClip(service: "Vercel",   username: "admin",        startUnit: 6.8, durationUnits: 1.2),
        ]),
        Track(name: "[Bass]", colorIndex: 3, clips: [
            TrackClip(service: "Binance",  username: "trader",       startUnit: 0.0, durationUnits: 4.0),
            TrackClip(service: "Kraken",   username: "trader",       startUnit: 4.5, durationUnits: 4.0),
        ]),
        Track(name: "[Piano]", colorIndex: 4, clips: [
            TrackClip(service: "Twitter",  username: "@me",          startUnit: 0.0, durationUnits: 2.0),
            TrackClip(service: "LinkedIn", username: "@me",          startUnit: 2.5, durationUnits: 1.5),
            TrackClip(service: "Discord",  username: "me#0000",      startUnit: 5.0, durationUnits: 2.5),
        ]),
    ]
}
