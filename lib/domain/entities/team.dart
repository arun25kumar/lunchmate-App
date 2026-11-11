
class Team {
  final String teamId;
  final String teamName;
  final String teamCode;
  final String? adminId;
  final String adminName;
 final String email;
  final String mobile;
  final DateTime createdAt;

  const Team({
    required this.teamId,
    required this.teamName,
    required this.teamCode,
    this.adminId,
    required this.adminName,
   required this.email,
    required this.mobile,
    required this.createdAt,
  });
}
