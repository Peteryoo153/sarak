import Foundation
import Observation
import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

struct SarakError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

/// 로그인 상태와 Firestore(그룹·진도·응원) 연결을 담당합니다.
@Observable
final class Session {
    private(set) var user: FirebaseAuth.User?
    private(set) var groups: [SarakGroup] = []
    private(set) var groupsLoaded = false
    private(set) var progress: [String: [MemberProgress]] = [:]
    private(set) var cheers: [Cheer] = []
    var pendingInviteCode: String?

    private var db: Firestore { Firestore.firestore() }
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var groupsListener: ListenerRegistration?
    private var progressListeners: [String: ListenerRegistration] = [:]
    private var cheerListeners: [String: ListenerRegistration] = [:]
    private var currentNonce: String?

    var uid: String? { user?.uid }
    var isSignedIn: Bool { user != nil }
    var displayName: String {
        let n = user?.displayName?.trimmingCharacters(in: .whitespaces) ?? ""
        return n.isEmpty ? "이름 없음" : n
    }

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            let changed = self.user?.uid != user?.uid
            self.user = user
            if changed { self.restartListeners() }
        }
    }

    // MARK: - Listeners

    private func restartListeners() {
        groupsListener?.remove(); groupsListener = nil
        progressListeners.values.forEach { $0.remove() }; progressListeners = [:]
        cheerListeners.values.forEach { $0.remove() }; cheerListeners = [:]
        groups = []; progress = [:]; cheers = []; groupsLoaded = false
        guard let uid else { groupsLoaded = true; return }

        groupsListener = db.collection("groups").whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let list = (snap?.documents ?? []).map(SarakGroup.init(doc:)).sorted { $0.createdAt < $1.createdAt }
                self.groups = list
                self.groupsLoaded = true
                self.syncGroupSubListeners()
            }
    }

    private func syncGroupSubListeners() {
        guard let uid else { return }
        let ids = Set(groups.map(\.id))
        for (id, l) in progressListeners where !ids.contains(id) { l.remove(); progressListeners[id] = nil; progress[id] = nil }
        for (id, l) in cheerListeners where !ids.contains(id) { l.remove(); cheerListeners[id] = nil }
        cheers.removeAll { !ids.contains($0.groupId) }

        for g in groups {
            if progressListeners[g.id] == nil {
                progressListeners[g.id] = db.collection("groups").document(g.id).collection("progress")
                    .addSnapshotListener { [weak self] snap, _ in
                        self?.progress[g.id] = (snap?.documents ?? []).map(MemberProgress.init(doc:))
                    }
            }
            if cheerListeners[g.id] == nil {
                let since = Timestamp(date: Date().addingTimeInterval(-3 * 86400))
                cheerListeners[g.id] = db.collection("groups").document(g.id).collection("cheers")
                    .whereField("to", isEqualTo: uid)
                    .whereField("createdAt", isGreaterThan: since)
                    .addSnapshotListener { [weak self] snap, _ in
                        guard let self else { return }
                        let name = self.groups.first { $0.id == g.id }?.name ?? ""
                        let mine = (snap?.documents ?? []).map { Cheer(doc: $0, groupId: g.id, groupName: name) }
                        self.cheers = (self.cheers.filter { $0.groupId != g.id } + mine).sorted { $0.createdAt > $1.createdAt }
                    }
            }
            if g.createdBy == uid && !g.inviteCode.isEmpty { ensureInvite(for: g) }
        }
    }

    // MARK: - Auth

    @MainActor
    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { throw SarakError("Firebase 설정을 찾을 수 없습니다.") }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else {
            throw SarakError("화면을 찾을 수 없습니다.")
        }
        var top = root
        while let p = top.presentedViewController { top = p }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: top)
        guard let idToken = result.user.idToken?.tokenString else { throw SarakError("구글 인증 토큰이 없습니다.") }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        let auth = try await Auth.auth().signIn(with: credential)
        try await createUserIfNeeded(auth.user)
    }

    /// SignInWithAppleButton의 onRequest에서 호출
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    @MainActor
    func completeApple(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code == .canceled { return }
            throw e
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken, let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else { throw SarakError("애플 인증 정보를 읽을 수 없습니다.") }
            let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: cred.fullName)
            let result = try await Auth.auth().signIn(with: credential)
            let full = [cred.fullName?.familyName, cred.fullName?.givenName].compactMap { $0 }.joined()
            if !full.isEmpty && (result.user.displayName ?? "").isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = full
                try? await change.commitChanges()
            }
            try await createUserIfNeeded(Auth.auth().currentUser ?? result.user)
            user = Auth.auth().currentUser
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
    }

    private func deleteUserData(_ uid: String) async {
        if let groups = try? await db.collection("groups").whereField("members", arrayContains: uid).getDocuments() {
            for g in groups.documents {
                try? await g.reference.collection("progress").document(uid).delete()
                try? await g.reference.updateData(["members": FieldValue.arrayRemove([uid])])
            }
        }
        if let done = try? await db.collection("users").document(uid).collection("completed_plans").getDocuments() {
            for d in done.documents { try? await d.reference.delete() }
        }
        try? await db.collection("users").document(uid).delete()
    }

    /// 계정 삭제 (App Store 5.1.1(v)) — 토큰이 유효할 때 데이터를 먼저 정리하고 인증 계정을 지웁니다.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { throw SarakError("로그인 상태가 아닙니다.") }
        // 최근 로그인 여부를 먼저 확인: 5분 이내 로그인이 아니면 재로그인 요청
        if let last = user.metadata.lastSignInDate, Date().timeIntervalSince(last) > 5 * 60 {
            throw SarakError("보안을 위해 로그아웃 후 다시 로그인한 다음 바로 삭제해 주세요.")
        }
        await deleteUserData(user.uid)
        do {
            try await user.delete()
        } catch let e as NSError where e.code == AuthErrorCode.requiresRecentLogin.rawValue {
            throw SarakError("보안을 위해 로그아웃 후 다시 로그인한 다음 바로 삭제해 주세요.")
        }
        GIDSignIn.sharedInstance.signOut()
    }

    private func createUserIfNeeded(_ user: FirebaseAuth.User) async throws {
        let ref = db.collection("users").document(user.uid)
        let snap = try await ref.getDocument()
        if !snap.exists {
            try await ref.setData([
                "name": user.displayName ?? "이름없음",
                "email": user.email ?? "",
                "photoUrl": user.photoURL?.absoluteString as Any,
                "createdAt": FieldValue.serverTimestamp(),
            ])
        }
    }

    // MARK: - Groups

    func createGroup(name: String, preset: RangePreset, days: Int, schedule: [DayPlan]) async throws -> SarakGroup {
        guard let uid else { throw SarakError("로그인이 필요합니다.") }
        let code = Self.inviteCode()
        let ref = db.collection("groups").document()
        try await ref.setData([
            "name": name, "createdBy": uid, "inviteCode": code, "members": [uid],
            "planType": preset.label, "rangeName": preset.label,
            "totalDays": schedule.count, "startDate": Timestamp(date: Date()),
            "startBookId": preset.startBookId, "endBookId": preset.endBookId,
            "minutesPerDay": schedule.map(\.estimatedMinutes).max() ?? 15,
            "schedule": Self.encode(schedule), "createdAt": FieldValue.serverTimestamp(),
        ])
        try await db.collection("invites").document(code).setData(["groupId": ref.documentID, "createdBy": uid, "createdAt": FieldValue.serverTimestamp()])
        try await writeProgress(groupId: ref.documentID, day: 1, completed: false, comment: nil, progress: 0, streak: 0, lastReadAt: nil)
        return SarakGroup(doc: try await ref.getDocument())
    }

    func updateGroupPlan(_ group: SarakGroup, preset: RangePreset, schedule: [DayPlan], restart: Bool) async throws {
        var data: [String: Any] = [
            "planType": preset.label, "rangeName": preset.label,
            "startBookId": preset.startBookId, "endBookId": preset.endBookId,
            "totalDays": schedule.count, "minutesPerDay": schedule.map(\.estimatedMinutes).max() ?? 15,
            "schedule": Self.encode(schedule),
        ]
        if restart || group.startDate == nil { data["startDate"] = Timestamp(date: Date()) }
        try await db.collection("groups").document(group.id).updateData(data)
    }

    /// 초대코드로 참여. invites/{code}로 그룹을 찾고(새 규칙), 없으면 예전 방식 검색을 시도합니다.
    func joinGroup(code raw: String) async throws -> SarakGroup {
        guard let uid else { throw SarakError("로그인이 필요합니다.") }
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 6 else { throw SarakError("초대코드는 6자리예요.") }
        var groupId: String?
        if let inv = try? await db.collection("invites").document(code).getDocument(), inv.exists {
            groupId = inv.data()?["groupId"] as? String
        }
        if groupId == nil {
            let q = try? await db.collection("groups").whereField("inviteCode", isEqualTo: code).limit(to: 1).getDocuments()
            groupId = q?.documents.first?.documentID
        }
        guard let groupId else { throw SarakError("초대코드를 찾을 수 없어요. 다시 확인해 주세요.") }
        let ref = db.collection("groups").document(groupId)
        try await ref.updateData(["members": FieldValue.arrayUnion([uid])])
        try await writeProgress(groupId: groupId, day: 1, completed: false, comment: nil, progress: 0, streak: 0, lastReadAt: nil, merge: true)
        return SarakGroup(doc: try await ref.getDocument())
    }

    func leaveGroup(_ group: SarakGroup) async throws {
        guard let uid else { return }
        let ref = db.collection("groups").document(group.id)
        try? await ref.collection("progress").document(uid).delete()
        try await ref.updateData(["members": FieldValue.arrayRemove([uid])])
    }

    private func ensureInvite(for g: SarakGroup) {
        let ref = db.collection("invites").document(g.inviteCode)
        ref.getDocument { snap, _ in
            if snap?.exists == false {
                ref.setData(["groupId": g.id, "createdBy": g.createdBy, "createdAt": FieldValue.serverTimestamp()])
            }
        }
    }

    // MARK: - Progress

    func writeProgress(groupId: String, day: Int, completed: Bool, comment: String?, progress: Double,
                       streak: Int, lastReadAt: Date?, merge: Bool = false) async throws {
        guard let uid else { return }
        let ref = db.collection("groups").document(groupId).collection("progress").document(uid)
        if merge, (try? await ref.getDocument())?.exists == true { return }
        let p = MemberProgress(uid: uid, name: displayName, currentDay: day, todayCompleted: completed,
                               todayComment: comment, progress: progress, streak: streak, lastReadAt: lastReadAt)
        try await ref.setData(p.firestore, merge: true)
    }

    /// 읽기 완료 시 서버 동기화 (개인 문서 + 활성 그룹 출석부)
    func reportCompletion(groupId: String?, day: Int, comment: String?, progress: Double, streak: Int) async {
        guard let uid else { return }
        try? await db.collection("users").document(uid).setData([
            "todayCompleted": true, "todayComment": comment as Any, "lastReadAt": FieldValue.serverTimestamp(),
            "currentDay": day, "progress": progress, "streak": streak,
        ], merge: true)
        if let groupId {
            try? await writeProgress(groupId: groupId, day: day, completed: true, comment: comment,
                                     progress: progress, streak: streak, lastReadAt: Date())
            if progress >= 1, let g = groups.first(where: { $0.id == groupId }) {
                try? await saveCompletion(planName: g.name, range: g.rangeName, start: g.startDate ?? g.createdAt)
            }
        }
    }

    func sendCheer(to member: MemberProgress, in group: SarakGroup) async throws {
        guard let uid else { return }
        try await db.collection("groups").document(group.id).collection("cheers").addDocument(data: [
            "from": uid, "fromName": displayName, "to": member.uid, "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    func saveCompletion(planName: String, range: String, start: Date) async throws {
        guard let uid else { return }
        try await db.collection("users").document(uid).collection("completed_plans").addDocument(data: [
            "planName": planName, "range": range, "startDate": Timestamp(date: start), "completedAt": FieldValue.serverTimestamp(),
        ])
    }

    func completionRecords() async -> [CompletionRecord] {
        guard let uid else { return [] }
        let snap = try? await db.collection("users").document(uid).collection("completed_plans")
            .order(by: "completedAt", descending: true).getDocuments()
        return (snap?.documents ?? []).map { d in
            let m = d.data()
            return CompletionRecord(id: d.documentID, planName: m["planName"] as? String ?? "통독 플랜",
                                    range: m["range"] as? String ?? "",
                                    startDate: (m["startDate"] as? Timestamp)?.dateValue() ?? Date(),
                                    completedAt: (m["completedAt"] as? Timestamp)?.dateValue() ?? Date())
        }
    }

    // MARK: - Helpers

    static func encode(_ schedule: [DayPlan]) -> [[String: Any]] {
        guard let data = try? JSONEncoder().encode(schedule),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr
    }

    static func inviteCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
