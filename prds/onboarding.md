# Onboarding System

## Purpose

Provide a minimal, user-friendly introduction to Kashr that:

- Builds trust through privacy-first messaging
- Explains the core mental model (tagging concept)
- Enables progressive feature discovery without overwhelming new users
- Scales gracefully as we add features (budgets, recurring transactions, debt tracking, etc.)

## Design Philosophy

**Minimal Onboarding + Progressive Disclosure**

- Main onboarding: 3 screens max (Privacy → Tagging → Ready)
  - We want to keep it simple and don't mention "allocation", "turnover", "pending" here
  - Always skippable: Users can skip onboarding and find info later
  - Always accessible: Settings → Help allows re-running onboarding anytime
- Feature-specific tips: Show contextually when user encounters the feature
  - No accounts yet: "Create your first account" with Cash/Checking suggestions
  - First account creation: Choice between manual/synced with brief explanation
  - No transactions yet: "Add your first transaction" with hint about Quick Add
  - No tags yet: "Create tags to organize your transactions"
  - Matching: Explain when they first see a pending transaction or click match
  - Transfers: Explain on first transfer or when clicking transfer button
  - Savings goals: Explain when they navigate to savings page
  - Synced accounts/Comdirect: Explain only when selecting synced account option
  - More details in Help Section (Settings → Help):


## Architecture

**State Management**:

- `SettingsState` (Freezed) contains:
  - `onboardingCompletedOn: DateTime?` - Tracks completion timestamp
  - `featureTipsShown: Map<FeatureTip, bool>` - Tracks which feature tips were shown
- `SettingsCubit` provides methods to manage onboarding state

**Key Files**:

- `lib/settings/model/feature_tip.dart` - Enum for feature discovery tips
- `lib/onboarding/*` - onboarding screens.

**Feature Discovery**

```dart
// Check if user has seen a tip
final SettingsState state = ...
if (!state.hasSeenFeatureTip(FeatureTip.pendingTransactionExplainer)) {
  // Show tip dialog/tooltip
  showFeatureTipDialog(...);

  // Mark as shown
  context.read<SettingsCubit>().setFeatureTipShown(FeatureTip.pendingTransactionExplainer, true);
}
```
