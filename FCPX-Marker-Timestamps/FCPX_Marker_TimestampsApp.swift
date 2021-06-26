//
//  FCPX_Marker_TimestampsApp.swift
//  FCPX-Marker-Timestamps
//
//  Created by Jaryd Meek on 6/2/21.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()

        view.blendingMode = .behindWindow    // << important !!
        view.isEmphasized = true
        view.material = .sidebar
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}

@main
struct FCPX_Marker_TimestampsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            Main().frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                .background(VisualEffectView())
                .edgesIgnoringSafeArea(.all)
        }.windowStyle(HiddenTitleBarWindowStyle())
    }
}
