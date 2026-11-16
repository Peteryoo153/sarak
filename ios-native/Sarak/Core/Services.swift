import SwiftUI
import UIKit
import UserNotifications

enum AppLinks {
    static let appStoreID = "6761447362"
    static let appStore = URL(string: "https://apps.apple.com/kr/app/id\(appStoreID)")!
    /// Firebase Hosting에 올리는 초대 안내 페이지 (hosting/ 폴더). 앱이 있으면 sarak://로 열고, 없으면 App Store로 보냅니다.
    static let inviteBase = "https://sarak-821b2.web.app/join"
    static let support = URL(string: "https://www.youtube.com/@biblecraft/join")!
    static let maker = URL(string: "https://linktr.ee/biblestorys")!
    static let contactEmail = "biblestorys@naver.com"
    /// 인스타그램 스토리에 바로 올리려면 Meta 개발자 앱 ID가 필요합니다. 없으면 공유 시트로 보냅니다.
    static let facebookAppID: String? = nil

    static func inviteURL(code: String) -> URL { URL(string: "\(inviteBase)?code=\(code)")! }
}

// MARK: - Daily reminder

enum ReminderService {
    static let id = "sarak.daily"

    static func requestAndSchedule(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        schedule(hour: hour, minute: minute)
        return true
    }

    static func schedule(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "사락"
        content.body = "오늘의 말씀이 기다리고 있어요. 함께 펼쳐볼까요?"
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour; comps.minute = minute
        // repeats: true — 매일 같은 시각 (기존 앱은 한 번만 울리던 문제 수정)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

// MARK: - Sharing

enum ShareService {
    @MainActor
    static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        var top = root
        while let p = top?.presentedViewController { top = p }
        return top
    }

    @MainActor
    static func share(_ items: [Any]) {
        guard let top = topViewController() else { return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        top.present(vc, animated: true)
    }

    @MainActor
    static func render<V: View>(_ view: V, size: CGSize, scheme: ColorScheme = .light) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height).environment(\.colorScheme, scheme))
        renderer.scale = 3
        return renderer.uiImage
    }

    /// 인스타그램 스토리 공유. 앱 ID가 있으면 스토리 편집 화면으로 바로, 없으면 공유 시트(인스타그램 → 스토리 선택).
    @MainActor
    static func shareToInstagramStory(_ image: UIImage) {
        if let appID = AppLinks.facebookAppID,
           let url = URL(string: "instagram-stories://share?source_application=\(appID)"),
           UIApplication.shared.canOpenURL(url), let png = image.pngData() {
            UIPasteboard.general.setItems([["com.instagram.sharedSticker.backgroundImage": png]],
                                          options: [.expirationDate: Date().addingTimeInterval(300)])
            UIApplication.shared.open(url)
        } else {
            share([image])
        }
    }

    @MainActor
    static func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    static func inviteMessage(from name: String, group: SarakGroup, today: DayPlan?) -> String {
        var lines = ["\(name)님이 사락에서 함께 성경을 읽자고 초대했어요.", "", "📖 \(group.name) · \(group.memberUids.count)명이 함께 읽는 중"]
        if let today { lines.append("오늘은 \(today.displayRange)을 읽어요.") }
        lines += ["", "초대코드: \(group.inviteCode)", "바로 참여하기: \(AppLinks.inviteURL(code: group.inviteCode).absoluteString)"]
        return lines.joined(separator: "\n")
    }

    static func readTogetherMessage(from name: String, today: DayPlan) -> String {
        [
            "\(name)님이 오늘 말씀을 같이 읽자고 보냈어요.",
            "",
            "📖 오늘의 말씀: \(today.displayRange) (약 \(today.estimatedMinutes)분)",
            "",
            "사락에서 함께 읽어요 → \(AppLinks.appStore.absoluteString)",
        ].joined(separator: "\n")
    }
}
