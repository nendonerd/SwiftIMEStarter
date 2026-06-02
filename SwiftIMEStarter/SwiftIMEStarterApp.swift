//
//  SwiftIMEStarterApp.swift
//  SwiftIMEStarter
//
//  Created by ensan on 2021/09/07.
//

import SwiftUI

struct SwiftIMEStarterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
