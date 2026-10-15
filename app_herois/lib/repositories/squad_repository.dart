import '../data/hero_database.dart';
import '../models/hero.dart';

class SquadRepository {
  final HeroDatabase _database;
  SquadRepository(this._database);

  Future<List<Hero>> getMembers() => _database.getSquadMembers();
  Future<RecruitmentResult> recruit(Hero hero) => _database.recruit(hero);
  Future<int> dismissMember(int heroId) => _database.dismissMember(heroId);
  Future<Hero> improveAttribute(int heroId, String attribute) =>
      _database.improveMemberAttribute(heroId, attribute);
}
