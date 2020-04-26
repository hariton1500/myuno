

class Card {
  String dost, mast;
}
class Uno {
  List<String> humanPlayers, compPlayers;
  //List<String> mastList = ['П', 'Т', 'Б', 'Ч'];
  //List<String> dostList = ['6', '7', '8', '9', '10', 'В', 'Д', 'К', 'Т'];
  Set<String> mastSet = {'П', 'Т', 'Б', 'Ч'}, dostSet = {'6', '7', '8', '9', '10', 'В', 'Д', 'К', 'Т'};
  Set<Card> base;
  Uno() {
    this.dostSet;
    this.mastSet;
    mastSet.forEach((mast) {
      dostSet.forEach((dost) {
        Card card;
        card.dost = dost;
        card.mast = mast;
        this.base.add(card);
        print(card);
      });
    });
    print(this.base);
  }
}


void main(List<String> args) {
  print('Добро пожаловаь в игру UNO:classic');
  Uno game;
  //print(game.dostSet);
}