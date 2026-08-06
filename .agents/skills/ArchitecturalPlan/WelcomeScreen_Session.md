# Implementation Plan - Splash Screen Foundation

✅ Phase 1
Splash

✅ Phase 2
Welcome

✅ Phase 3
Authentication

✅ Phase 4
Session Management

✅ Phase 4.5
Profile Completion

✅ Phase 5
Home Entry

⬜ Phase 6 — Local Data Foundation
• Notes
• Tasks
• Folders
• Categories
• Images

⬜ Phase 7
Cloud Sync Foundation

⬜ Phase 8
Conflict Resolution & Multi-Device Sync

⬜ Phase 9
Backup & Restore

⬜ Phase 10
Premium Features


## Objective

Implement a production-grade Splash Screen that is responsible ONLY for application initialization and routing decisions.

This screen is not an onboarding screen. It must never contain business logic related to authentication or UI decisions beyond determining the next destination.

---

## Responsibilities

The Splash Screen should:

• Display the Quick Notes logo/title centered.
• Keep a plain white background.
• Stay visible for approximately 1.5–2 seconds.
• Initialize required services.
• Determine the correct navigation destination.
• Never require user interaction.

---

## During initialization perform:

1. Initialize Local Database.
2. Initialize SharedPreferences.
3. Initialize Dependency Injection.
4. Initialize Authentication Service.
5. Check whether this is the first app launch.
6. Check whether onboarding has already been completed.
7. Check whether a user is currently authenticated.
8. Prepare repositories without downloading user data.

---

## Navigation Decision Tree

IF first launch

    Navigate → Welcome Screen

ELSE

    IF authenticated

        Navigate → Home Screen

    ELSE

        Navigate → Login Screen

---

## Architecture

SplashScreen
SplashController
SplashState
SplashNavigator

Business logic must remain inside SplashController.

SplashScreen only listens for navigation state.

---

## Deliverables

✓ SplashScreen
✓ SplashController
✓ Initialization Service
✓ Navigation Logic
✓ Clean separation between UI and business logic

No animations beyond a simple fade.
No authentication requests.
No database synchronization.



Phase - 2 

# Implementation Plan - Welcome Screen

## Objective

Create the onboarding welcome screen introducing Quick Notes.

This screen is shown ONLY once during the first launch.

---

## Responsibilities

Display:

• Floating decorative note/task cards
• Quick Notes title
• Start button

This screen performs NO authentication.

---

## User Interaction

User presses:

Start

↓

Navigate to Login Screen

---

## Requirements

The floating cards are decorative only.

Do not fetch data.

Do not initialize services.

Do not ask permissions.

No authentication.

No storage decisions.

Only play lightweight entrance animations.

---

## Completion

After pressing Start:

Store

onboardingCompleted = true

Navigate to Login Screen.

---

## Deliverables

WelcomeScreen

WelcomeAnimationController

Start Button

Decorative Widgets

Persistent onboarding flag


Phase - 3

# Implementation Plan - Login Screen

## Objective

Provide two methods for entering Quick Notes:

1. Continue with Google
2. Continue Offline

This screen is responsible only for user authentication and local-mode initialization.

---

## UI

Quick Notes

Continue with Google

OR

Continue Offline

---

## Continue with Google

When pressed:

1. Start Google Authentication.

2. If authentication succeeds:

Retrieve:

User ID

Email

Display Name

Photo URL (optional)

3. Store authenticated session locally.

4. Determine whether cloud data already exists.

IF cloud account contains data

↓

Navigate directly to Home Screen.

Synchronization will occur later.

IF cloud account is empty

↓

Create user profile.

↓

Navigate to Home Screen.

---

## Continue Offline

When pressed:

1. Create Local User Profile.

2. Initialize Local Database.

3. Mark user as Offline Mode.

4. Navigate to Home Screen.

No authentication occurs.

No internet required.

---

## Error Handling

Google Sign-In cancelled

↓

Stay on Login Screen.

Google Sign-In failed

↓

Show Snackbar.

Retry.

Offline initialization failed

↓

Show error.

Retry initialization.

---

## Architecture

LoginScreen

LoginController

AuthenticationService

OfflineInitializationService

SessionManager

---

## Deliverables

Google Sign-In

Offline Mode

Loading State

Error State

Navigation to Home

Phase - 4

# Implementation Plan - Session Management

## Objective

Create a centralized Session Manager responsible for deciding how Quick Notes starts.

SessionManager becomes the single source of truth for authentication state.

---

Session Types

Authenticated

Offline

Guest (future)

---

Store

isAuthenticated

isOffline

userId

email

provider

---

Splash Screen must only ask:

SessionManager

↓

What is the current session?

The SessionManager returns:

Authenticated

↓

Home

Offline

↓

Home

No Session

↓

Login

First Launch

↓

Welcome

Phase - 5

# Implementation Plan - Home Entry

## Objective

Create the transition from onboarding into the main application.

Home Screen should never know whether the user came from:

Google Login

Offline Mode

Apple Sign-In (future)

Returning Session

Splash

HomeScreen receives no authentication or session objects.

By the time HomeScreen is created, the application session has already been
restored and all repositories are fully initialized.

HomeScreen interacts only with application repositories and providers.

Home behaves identically regardless of entry point.

---

## Architectural Contract

SessionManager restores the active session before navigation occurs.

UserRepository becomes the single source of truth for the active user.

All repositories (NotesRepository, TasksRepository, FoldersRepository, etc.)
resolve the active user internally through UserRepository when required.

HomeScreen depends only on repositories and providers.

HomeScreen is completely unaware of authentication, onboarding, or session state.

---

## Responsibilities

Load notes through NotesRepository.

Prepare task repository.

Initialize calendar.

Initialize folders.

Display today's data.

No authentication logic.

No onboarding logic.

No routing decisions.

---

## Repository Abstraction

HomeScreen always talks to the repository abstraction layer:

NotesRepository
      │
      ├── SQLite (today)
      ├── Cloud Cache (future)
      ├── Sync Queue (future)
      └── Remote Backend (future)

HomeScreen does not care whether notes came from SQLite, Firestore,
an encrypted cache, or another source.

---

## Result

HomeScreen becomes a pure presentation screen.

Completely independent of authentication and session concerns.

Future-proof against any change in data source or authentication provider.

App Launch
      │
      ▼
Splash
      │
      ├───────────────┐
      │               │
 First Launch?       Returning User
      │               │
     Yes             No
      │               │
      ▼               ▼
 Welcome          Session Check
      │               │
      ▼               │
 Login              ┌──┴─────────────┐
      │             │                │
      │       Authenticated      Offline
      │             │                │
      ├───────┬─────┘                │
      │       │                      │
Google      Offline                  │
      │       │                      │
      └───────┴──────────────────────┘
                  │
                  ▼
             Home Screen


             
# Phase 4.5 - User Profile Completion

## Objective

Introduce a mandatory Profile Completion screen immediately after the user's first successful Google authentication.

This screen is NOT part of the authentication flow.

It is part of Quick Notes user onboarding and is responsible for creating the application's internal user profile.

Authentication and profile creation must remain separate concerns.

---

## Updated Authentication Flow

Splash
↓

Welcome
↓

Login
↓

Google Authentication
↓

UserRepository

↓

Does Quick Notes Profile exist?

IF YES

↓

Navigate directly to HomeScreen.

IF NO

↓

Navigate to ProfileScreen.

---

## Responsibilities

AuthenticationService

- Authenticate the Google account.
- Return AuthResult.
- Never navigate.
- Never create a profile.

UserRepository

- Restore authenticated user.
- Determine whether an application profile already exists.

ProfileRepository

- Create, update and load Quick Notes user profiles.
- Store profile information locally.
- Become the single source of truth for profile data.

LoginController

- Coordinate authentication.
- Ask UserRepository whether a profile exists.
- Navigate either to ProfileScreen or HomeScreen.

ProfileScreen

- Display authenticated user's Google name and email.
- Display current Google profile photo if available.
- Allow user to choose a Quick Notes avatar.
- Allow user to edit the display name.
- Never perform authentication.
- Never call Google APIs directly.

---

## Save Flow

When Save is pressed:

1. Validate profile information.
2. Create a UserProfile entity.
3. Persist the profile using ProfileRepository.
4. Mark `hasCompletedProfile = true`.
5. Navigate to HomeScreen.

---

## Splash Routing Update

SplashController should determine startup destination using the following order:

1. Has completed onboarding?
2. Is session restored?
3. Has completed profile?

Routing:

Not onboarded
→ Welcome

No active session
→ Login

Authenticated but profile incomplete
→ ProfileScreen

Authenticated and profile complete
→ HomeScreen

---

## Design Principles

- Authentication and profile management must remain completely independent.
- HomeScreen must remain unaware of authentication or onboarding.
- ProfileScreen must only create or edit application profile data.
- Future cloud synchronization must synchronize the UserProfile through ProfileRepository without modifying AuthenticationService.

One final recommendation

I would make one tiny addition that you'll thank yourself for later:

Instead of only storing:

hasCompletedProfile = true;

Create a real UserProfile entity from day one:

class UserProfile {
  final String userId;          // Google UID or Offline UUID
  final String displayName;     // Quick Notes display name
  final String email;
  final String? avatarId;       // Your illustrated avatar selection
  final String? photoUrl;       // Google photo (optional)
  final DateTime createdAt;
  final DateTime updatedAt;
}

Then derive completion like this:

Profile exists?
    ↓
Yes → Home
No  → ProfileScreen

That removes the need for a separate hasCompletedProfile flag and makes the existence of a valid profile itself the source of truth. It's a cleaner, more scalable design that will fit naturally when you later add profile editing, cloud sync, and multi-device support.