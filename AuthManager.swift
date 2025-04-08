//
//  AuthViewModel.swift
//
//  Created by Sajid on 07/04/25.
//

#if canImport(FirebaseAuth) && canImport(GoogleSignIn) && canImport(CryptoKit) &&  canImport(AuthenticationServices)
import FirebaseAuth
import GoogleSignIn
import CryptoKit
import AuthenticationServices

// MARK: - Sign-In , Sign-out , Delete
final class AuthManager: NSObject {
    static let shared = AuthManager()
    private override init() {}
    
    private var currentNonce: String?
    private var appleCompletion: ((Bool, User?, String?) -> Void)?
    
    // MARK: - Sign In Entry Point
    func signIn(with type: LoginType, clientID: String? = nil, email: String? = nil, password: String? = nil, completion: @escaping (Bool, User?, String?) -> Void) {
        switch type {
        case .anonymous:
            signInAnonymously(completion: completion)
        case .google:
            guard let clientID = clientID else {
                completion(false, nil, "Missing Google Client ID.")
                return
            }
            signInWithGoogle(clientID: clientID, completion: completion)
        case .apple:
            signInWithApple(completion: completion)
        case .emailPassword:
            guard let email = email, let password = password else {
                completion(false, nil, "Missing email or password.")
                return
            }
            signInWithEmailPassword(email: email, password: password, completion: completion)
        case .none:
            completion(false, nil, "Invalid login type.")
        }
    }
    
    
    // MARK: - Sign Out
    func signOut(loginType: LoginType,completion: @escaping (LoginType,Bool, String?) -> Void) {
        do {
            try Auth.auth().signOut()
            updateUserDefaultsOnSignOut()
            completion(loginType,true, nil)
        } catch {
            completion(loginType,false, error.localizedDescription)
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount(completion: @escaping (LoginType,Bool, String?) -> Void) {
        let loginType = UserDefaults.loginType ?? .anonymous
        guard let user = Auth.auth().currentUser else {
            completion(loginType,false, "No user is signed in.")
            return
        }
        
        user.delete { error in
            if let error = error {
                completion(loginType,false, error.localizedDescription)
            } else {
                self.updateUserDefaultsOnSignOut()
                completion(loginType,true, nil)
            }
        }
    }
    
    //MARK: Unlink User
    func unlink(provider: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().currentUser?.unlink(fromProvider: provider) { user, error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
}

// MARK: - Google Sign-In (with Linking Support)
extension AuthManager {
    private func signInWithGoogle(clientID: String, completion: @escaping (_ success: Bool, _ user: User?, _ error: String?) -> Void) {
        guard let presentingVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController else {
            completion(false, nil, "No root view controller found")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
            if let error = error {
                completion(false, nil, error.localizedDescription)
                return
            }
            
            guard
                let idToken = result?.user.idToken?.tokenString,
                let accessToken = result?.user.accessToken.tokenString
            else {
                completion(false, nil, "Failed to retrieve tokens")
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            if let user = Auth.auth().currentUser, user.isAnonymous {
                self.linkCredentialToAnonymousUser(credential: credential, loginType: .google, completion: completion)
            } else {
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        completion(false, nil, error.localizedDescription)
                    } else if let user = authResult?.user {
                        self.updateUserDefaults(user: user, loginType: .google)
                        completion(true, user, nil)
                    } else {
                        completion(false, nil, "User info unavailable")
                    }
                }
            }
        }
    }
}

// MARK: - Anonymous Sign-In
extension AuthManager {
    private func signInAnonymously(completion: @escaping (Bool, User?, String?) -> Void) {
        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                completion(false, nil, error.localizedDescription)
            } else if let user = result?.user {
                self.updateUserDefaults(user: user,loginType: .anonymous)
                completion(true, user, nil)
            } else {
                completion(false, nil, "Unknown error occurred.")
            }
        }
    }
}

// MARK: - Apple Sign-In (with Linking Support)
extension AuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private func signInWithApple(completion: @escaping (Bool, User?, String?) -> Void) {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        
        self.appleCompletion = completion
    }
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
        
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let token = credential.identityToken,
              let idTokenString = String(data: token, encoding: .utf8),
              let nonce = currentNonce else {
            appleCompletion?(false, nil, "Apple Sign-In failed.")
            return
        }
        
        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        
        if let user = Auth.auth().currentUser, user.isAnonymous {
            linkCredentialToAnonymousUser(credential: firebaseCredential, loginType: .apple) { success, userId, error in
                self.appleCompletion?(success, user, error)
            }
        } else {
            Auth.auth().signIn(with: firebaseCredential) { result, error in
                if let error = error {
                    self.appleCompletion?(false, nil, error.localizedDescription)
                } else if let user = result?.user {
                    self.updateUserDefaults(user: user,loginType: .apple)
                    self.appleCompletion?(true, user, nil)
                } else {
                    self.appleCompletion?(false, nil, "Unknown error occurred.")
                }
            }
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleCompletion?(false, nil, error.localizedDescription)
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).compactMap { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return status == errSecSuccess ? random : nil
            }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Email-Password Sign-In
extension AuthManager {
    func signInWithEmailPassword(email: String, password: String, completion: @escaping (Bool, User?, String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(false, nil, error.localizedDescription)
            } else if let user = authResult?.user {
                self.updateUserDefaults(user: user, loginType: .emailPassword)
                completion(true, user, nil)
            } else {
                completion(false, nil, "Unknown error occurred during email-password sign-in.")
            }
        }
    }
}

// MARK: - Email-Password Sign-Up
extension AuthManager {
    func signUpWithEmailPassword(email: String, password: String, completion: @escaping (Bool, User?, String?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(false, nil, error.localizedDescription)
            } else if let user = authResult?.user {
                self.updateUserDefaults(user: user, loginType: .emailPassword)
                completion(true, user, nil)
            } else {
                completion(false, nil, "Unknown error occurred during email-password registration.")
            }
        }
    }
}

// MARK: - Forgot Password
extension AuthManager {
    func forgotPassword(email: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
}

// MARK: - Link Credential (Google/Apple) to Anonymous User
extension AuthManager {
    private func linkCredentialToAnonymousUser(credential: AuthCredential, loginType: LoginType, completion: @escaping (_ success: Bool, _ user: User?, _ error: String?) -> Void) {
        Auth.auth().currentUser?.link(with: credential) { result, error in
            if let error = error as NSError?, error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                completion(false, nil, "This account is already linked to another user.")
            } else if let error = error {
                completion(false, nil, error.localizedDescription)
            } else if let user = result?.user {
                self.updateUserDefaults(user: user ,loginType: loginType)
                completion(true, user, nil)
            } else {
                completion(false, nil, "Unknown linking error.")
            }
        }
    }
}

// MARK: - Get Current User Info
extension AuthManager {
    func getCurrentUser() -> (userId: User?, isSignedIn: Bool) {
        if let user = Auth.auth().currentUser {
            return (user, true)
        } else {
            return (nil, false)
        }
    }
}

// MARK: - Helper Methods for User Authentication
extension AuthManager {
    private func updateUserDefaults(user: User,loginType: LoginType) {
        UserDefaults.userId = user.uid
        UserDefaults.userEmail = user.email ?? (loginType == .google ? user.email ?? "Google User" : loginType == .apple ? user.email ?? "Apple User" : "Anonymous")
        UserDefaults.userDisplayName = user.displayName ?? (loginType == .google ? user.email ?? "Google User" : loginType == .apple ? user.email ?? "Apple User" : "Anonymous")
        UserDefaults.isUserSignIn = true
        UserDefaults.loginType = loginType
        
    }
    
    private func updateUserDefaultsOnSignOut() {
        UserDefaults.userId = nil
        UserDefaults.userEmail = nil
        UserDefaults.userDisplayName = nil
        UserDefaults.isUserSignIn = false
        UserDefaults.loginType = LoginType.none
    }
}

// MARK: - UserDefaults for Authentication
extension UserDefaults {
    
    static var userId : String? {
        get {
            return standard.string(forKey: #function)
        }
        set {
            standard.set(newValue, forKey: #function)
        }
    }
    
    static var userEmail : String? {
        get {
            return standard.string(forKey: #function)
        }
        set {
            standard.set(newValue, forKey: #function)
        }
    }
    
    static var userDisplayName : String? {
        get {
            return standard.string(forKey: #function)
        }
        set {
            standard.set(newValue, forKey: #function)
        }
    }
    
    static var userProfileImageURL : String? {
        get {
            return standard.string(forKey: #function)
        }
        set {
            standard.set(newValue, forKey: #function)
        }
    }
    
    class var loginType: LoginType? {
        get {
            let data = UserDefaults.standard.string(forKey: "loginType") ?? ""
            switch data {
            case LoginType.apple.rawValue:
                return .apple
            case LoginType.anonymous.rawValue:
                return .anonymous
            case LoginType.google.rawValue:
                return .google
            default:
                return LoginType.none
            }
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: "loginType")
        }
    }
    
    class var isUserSignIn : Bool {
        get {
#if os(iOS)
            return getOrSetUserDefault(key: #function, defaultValue: false)
#else
            return false
#endif
        }
        set {
            standard.set(newValue, forKey: #function)
        }
    }
    
    //Common Function
    private static func getOrSetUserDefault<T>(key: String, defaultValue: T) -> T {
        if let value = standard.object(forKey: key) as? T {
            return value
        }
        standard.set(defaultValue, forKey: key)
        return defaultValue
    }
}

// MARK: - Enum of Login Type
enum LoginType: String {
    case anonymous
    case google
    case apple
    case emailPassword
    case none
}
#else
#error("Please install missing dependencies first.")
import FirebaseAuth // ❗️If you see an error: "No such module 'FirebaseAuth'":
// ➤ Solution: Add Firebase SDK via Swift Package Manager:
//    URL: https://github.com/firebase/firebase-ios-sdk.git
//    Then add 'FirebaseAuth' under the dependencies tab for your target.

import GoogleSignIn // ❗️If you see an error: "No such module 'GoogleSignIn'":
// ➤ Solution: Use CocoaPods:
//    1. Run `sudo gem install cocoapods` (if not already installed)
//    2. Create a Podfile (if not present) with `pod init`
//    3. In the Podfile, add: `pod 'GoogleSignIn'`
//    4. Run `pod install`
//    5. Open the `.xcworkspace` file and build again

import CryptoKit // ❗️If you see an error: "No such module 'CryptoKit'":
// ➤ Solution: CryptoKit is available from iOS 13+
//    Ensure your deployment target is set to iOS 13.0 or higher in Xcode:
//    Project > Target > General > Deployment Info

import AuthenticationServices // ❗️If you see an error: "No such module 'AuthenticationServices'":
// ➤ Solution: This is a native framework available from iOS 13+
//    Make sure your deployment target is iOS 13.0 or above
//    If you're using Swift packages, no need to add anything extra.

#endif
