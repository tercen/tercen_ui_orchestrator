/// Represents the current user's identity and role for the header.
class UserState {
  final String displayName;
  final String identityString; // Seed for identicon generation
  final bool isAdmin;

  const UserState({
    required this.displayName,
    required this.identityString,
    required this.isAdmin,
  });
}
