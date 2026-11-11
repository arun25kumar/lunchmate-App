
import '../entities/team.dart';

abstract class TeamRepository {
  Future<Team> createTeam({
    required String teamName,
    required String adminName,
    required String email,
    required String mobile,
    required String pin,
  });
}
