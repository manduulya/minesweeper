String displayUsername(String? username) {
  if (username == null || username.isEmpty) return 'Player';
  return username[0].toUpperCase() + username.substring(1);
}
