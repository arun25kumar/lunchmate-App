
import '../../domain/entities/team.dart';
import '../../domain/repositories/team_repository.dart';
import '../datasources/remote/firestore_team_datasource.dart';

class TeamRepositoryImpl implements TeamRepository {
  final FirestoreTeamDataSource dataSource;

  TeamRepositoryImpl({
    required this.dataSource,
  });

  @override
  Future<Team> createTeam({
    required String teamName,
    required String adminName,
    required String email,
    required String mobile,
    required String pin,
  }) {
    return dataSource.createTeam(
      teamName: teamName,
      adminName: adminName,
      email: email,
      mobile: mobile,
      pin: pin,
    );
  }
}
