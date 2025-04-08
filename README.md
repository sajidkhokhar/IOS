# AuthViewModel - SwiftUI Authentication Manager

`AuthViewModel` is a comprehensive authentication manager implemented in Swift, designed for easy integration into SwiftUI apps. It supports multiple authentication methods, including anonymous, Google, Apple, and email/password. This module simplifies the process of integrating and managing user authentication by abstracting complex operations into straightforward, reusable methods.

## Features

- **Google Sign-In**: Integration with Google's authentication system.
- **Apple Sign-In**: Support for authentication via Apple ID.
- **Email and Password Authentication**: Traditional email and password sign-in.
- **Anonymous Authentication**: Allows users to sign in anonymously.
- **Account Linking**: Supports linking different authentication methods to a single account.
- **Account Management**: Users can sign out and delete accounts.
- **Auto Store in UserDefaults**: Automatically stores user login status and data in UserDefaults, providing a seamless experience across app sessions.

### UserDefaults Keys

The application utilizes UserDefaults to store various user information. Below is a detailed list of the UserDefaults keys and their purpose:

- `userId`: Stores the unique identifier for the logged-in user.
- `userEmail`: Stores the email address of the logged-in user.
- `userDisplayName`: Stores the display name of the logged-in user.
- `userProfileImageURL`: Stores the URL for the user's profile image.
- `loginType`: Stores the method used for the user's login, e.g., Google, Apple, Email/Password, or Anonymous.
- `isUserSignIn`: Boolean value that indicates whether the user is currently signed in.

These keys help maintain the user's session and keep track of their authentication state across different launches of the application.


## Requirements

- iOS 13.0+
- Xcode 11.0+
- Swift 5.0+
- Firebase Authentication
- GoogleSignIn SDK
- CryptoKit
- AuthenticationServices

## Installation

### Firebase Setup

1. Add your project to Firebase:
   - Go to the [Firebase Console](https://console.firebase.google.com/).
   - Add a new project and follow the setup instructions.

2. Integrate Firebase into your iOS project:
   - Add the `GoogleService-Info.plist` to your project.
   - Install Firebase SDK using CocoaPods or Swift Package Manager.

```bash
pod 'Firebase/Auth'
pod 'Firebase'
pod 'GoogleSignIn'
pod 'FirebaseCore'
```

You can also use Swift Package Manager to add Firebase and GoogleSignIn to your project:
```bash
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "VERSION")),
    .package(url: "https://github.com/google/GoogleSignIn-iOS", .upToNextMajor(from: "VERSION"))
]
```
Replace "VERSION" with the latest versions compatible with your project.

### Usage
To use AuthViewModel in your project, you need to configure each service according to their individual setup instructions provided by their SDKs.

Here is a basic example of how to initiate a sign-in process using AuthViewModel:


### Google Sign-In
Here is a basic example of how to initiate a sign-in process using Google authentication in `AuthViewModel`:

```bash
AuthManager.shared.signIn(with: .google, clientID: "YOUR_GOOGLE_CLIENT_ID") { success, user, error in
    if success {
        print("Login Successful: \(user?.uid)")
    } else {
        print("Error: \(error ?? "Unknown error")")
    }
}
```
Make sure to replace "YOUR_GOOGLE_CLIENT_ID" with your actual Google client ID.


### Anonymous Authentication
For anonymous sign-in:
```bash
AuthManager.shared.signIn(with: .anonymous) { success, user, error in
    if success {
        print("Login Successful: \(user?.uid)")
    } else {
        print("Error: \(error ?? "Unknown error")")
    }
}
```

### Apple Sign-In
To sign in using Apple ID:
```bash
AuthManager.shared.signIn(with: .apple) { success, user, error in
    if success {
        print("Login Successful: \(user?.uid)")
    } else {
        print("Error: \(error ?? "Unknown error")")
    }
}
```

### Email and Password Authentication
For signing in with an email and password:
```bash
AuthManager.shared.signIn(with: .emailPassword, email: "user@example.com", password: "password123") { success, user, error in
    if success {
        print("Login Successful: \(user?.uid)")
    } else {
        print("Error: \(error ?? "Unknown error")")
    }
}
```
### Sign Out
To sign out a user:
```bash
AuthManager.shared.signOut(loginType: .google) { loginType, success, error in
    if success {
        print("Sign Out Successful")
    } else {
        print("Error Signing Out: \(error ?? "Unknown error")")
    }
}
```
### Delete Account
To delete a user account:
```bash
AuthManager.shared.deleteAccount { loginType, success, error in
    if success {
        print("Account Deletion Successful")
    } else {
        print("Error Deleting Account: \(error ?? "Unknown error")")
    }
}
```

Contributing
Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are greatly appreciated.

Contact
Sajid Khokhar. - khokharsajid166@gmail.com

