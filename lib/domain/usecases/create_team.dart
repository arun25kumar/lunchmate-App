
import '../entities/team.dart';
import '../repositories/team_repository.dart';

class CreateTeam {
  final TeamRepository repository;

  CreateTeam(this.repository);

  Future<Team> call({
    required String teamName,
    required String adminName,
    required String email,
    required String mobile,
    required String pin,
  }) {
    return repository.createTeam(
      teamName: teamName,
      adminName: adminName,
      email: email,
      mobile: mobile,
      pin: pin,
    );
  }
}
