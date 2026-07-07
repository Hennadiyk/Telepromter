//
//  AppTips.swift
//  Teleprompter DE
//

import SwiftUI
import TipKit

// MARK: - Tip Definitions
// Order matches the landing tab sequence: Teleprompter (1) → Add Text (0) → Account (2)

@available(iOS 17, *)
struct DragPrompterTip: Tip {
    // No rules — shown first on the landing Teleprompter tab
    var title: Text { Text("Move & Resize") }
    var message: Text? { Text("Step 1 of 6  —  Long press to drag the teleprompter window. Drag the corner handle to resize it.") }
    var image: Image? { Image(systemName: "arrow.up.left.and.arrow.down.right") }
    var actions: [Action] {
        [Action(id: "next", title: "Next →")]
    }
}

@available(iOS 17, *)
struct PlayButtonTip: Tip {
    @Parameter static var isUnlocked: Bool = false
    var rules: [Rule] {
        #Rule(Self.$isUnlocked) { $0 }
    }
    var title: Text { Text("Play / Pause") }
    var message: Text? { Text("Step 2 of 6  —  Tap to start scrolling your script. Tap again to pause.") }
    var image: Image? { Image(systemName: "play.circle.fill") }
    var actions: [Action] {
        [Action(id: "next", title: "Next →")]
    }
}

@available(iOS 17, *)
struct TextSizeSpeedTip: Tip {
    @Parameter static var isUnlocked: Bool = false
    var rules: [Rule] {
        #Rule(Self.$isUnlocked) { $0 }
    }
    var title: Text { Text("Text Size & Speed") }
    var message: Text? { Text("Step 3 of 6  —  Adjust text size with the left +/− and scroll speed with the right +/−. Tap the icons to show or hide the controls.") }
    var image: Image? { Image(systemName: "textformat.size") }
    var actions: [Action] {
        [Action(id: "next", title: "Next →")]
    }
}

@available(iOS 17, *)
struct VideoModeTip: Tip {
    @Parameter static var isUnlocked: Bool = false
    var rules: [Rule] {
        #Rule(Self.$isUnlocked) { $0 }
    }
    var title: Text { Text("Video Mode") }
    var message: Text? { Text("Step 4 of 6  —  Tap to enable the camera. Press the record button to film yourself reading the script. Premium - subscription required") }
    var image: Image? { Image(systemName: "video.fill") }
    var actions: [Action] {
        [Action(id: "next", title: "Next →")]
    }
}

@available(iOS 17, *)
struct EnterTextTip: Tip {
    @Parameter static var isUnlocked: Bool = false
    var rules: [Rule] {
        #Rule(Self.$isUnlocked) { $0 }
    }
    var title: Text { Text("Enter Your Script") }
    var message: Text? { Text("Step 5 of 6  —  Type or paste your script here, or tap Import to load a PDF or text file.") }
    var image: Image? { Image(systemName: "pencil.line") }
    var actions: [Action] {
        [Action(id: "next", title: "Next →")]
    }
}

@available(iOS 17, *)
struct AccountSettingsTip: Tip {
    @Parameter static var isUnlocked: Bool = false
    var rules: [Rule] {
        #Rule(Self.$isUnlocked) { $0 }
    }
    var title: Text { Text("Settings & Account") }
    var message: Text? { Text("Step 6 of 6  —  Change scroll mode, colors, and more in Settings. Manage your subscription or send a feature request from here.") }
    var image: Image? { Image(systemName: "gearshape.fill") }
    var actions: [Action] {
        [Action(id: "finish", title: "Finish ✓")]
    }
}

// MARK: - ViewModifiers
// Each modifier is available without importing TipKit at call sites.

struct DragPrompterTipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.popoverTip(DragPrompterTip()) { action in
                if action.id == "next" {
                    DragPrompterTip().invalidate(reason: .actionPerformed)
                    PlayButtonTip.isUnlocked = true
                }
            }
        } else {
            content
        }
    }
}

struct PlayButtonTipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.popoverTip(PlayButtonTip()) { action in
                if action.id == "next" {
                    PlayButtonTip().invalidate(reason: .actionPerformed)
                    TextSizeSpeedTip.isUnlocked = true
                }
            }
        } else {
            content
        }
    }
}

struct TextSizeSpeedTipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.popoverTip(TextSizeSpeedTip()) { action in
                if action.id == "next" {
                    TextSizeSpeedTip().invalidate(reason: .actionPerformed)
                    VideoModeTip.isUnlocked = true
                }
            }
        } else {
            content
        }
    }
}

struct VideoModeTipModifier: ViewModifier {
    @Environment(ContentViewModel.self) private var contentVM

    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.popoverTip(VideoModeTip()) { action in
                if action.id == "next" {
                    VideoModeTip().invalidate(reason: .actionPerformed)
                    EnterTextTip.isUnlocked = true
                    contentVM.selectedTab = 0
                }
            }
        } else {
            content
        }
    }
}

struct EnterTextTipModifier: ViewModifier {
    @Environment(ContentViewModel.self) private var contentVM

    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.popoverTip(EnterTextTip(), arrowEdge: .bottom) { action in
                if action.id == "next" {
                    EnterTextTip().invalidate(reason: .actionPerformed)
                    AccountSettingsTip.isUnlocked = true
                    contentVM.selectedTab = 2
                }
            }
        } else {
            content
        }
    }
}

struct AccountSettingsTipModifier: ViewModifier {
    @Environment(ContentViewModel.self) private var contentVM

    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.popoverTip(AccountSettingsTip()) { action in
                if action.id == "finish" {
                    AccountSettingsTip().invalidate(reason: .actionPerformed)
                    contentVM.selectedTab = 1
                }
            }
        } else {
            content
        }
    }
}
