import 'dart:math';

class Uno {
  final List<String> humanPlayers, compPlayers = [];
  List<String> mastList = ['П', 'Т', 'Б', 'Ч'];
  List<String> dostList = ['6', '7', '8', '9', '10', 'В', 'Д', 'К', 'Т'];
  int currentMovePlayer, basePlayer = 0;
  Map<String, List<String>> cards = {};
  final String name;
  String orderedMast = '';
  
  Uno(this.name, this.humanPlayers) {
    cards['base'] = [];
    cards['heap'] = [];
    humanPlayers.forEach((player) => cards[player] = []);
    mastList.forEach((mast) {
      dostList.forEach((dost) {
        cards['base'].add(dost + '-' + mast);
      });
    });
    print('Карты: $cards');
    print('[$name] Размешиваем колоду...');
    rand('base');
    print('[$name] Раздаем карты');
    razdacha(5);
  }

  void rand(String owner) {
    List<String> tempBase = [];
    for (var i = 0; i < cards[owner].length; i++) {
      int _index = Random().nextInt(cards[owner].length);
      tempBase.add(cards[owner].elementAt(_index));
      cards[owner].removeAt(_index);
    }
    cards[owner].clear();
    cards[owner] = tempBase;
  }

  void razdacha(int num) {
    for (var i = 0; i < num; i++) {
      humanPlayers.forEach((player) {
        cards[player].add(cards['base'].first);
        cards['base'].removeAt(0);
      });
    }
  }

  initMove() {
    List<String> _move = [];
    cards['heap'].add(cards['base'].first);
    print(cards['heap']);
    _move.add(cards['base'].first);
    cards['base'].removeAt(0);
  }

  bool playerCanAddCardsToMove() {
    bool _sameDostCards = false;
    cards[humanPlayers[currentMovePlayer]].forEach((card){
      if (dostOf(card) == dostOf(cards['heap'].first)) _sameDostCards = true;
      }
    );
    return _sameDostCards;
  }

  String dostOf(String card) {
    return card.split('-')[0];
  }

  String mastOf(String card) {
    return card.split('-')[1];
  }

  void setMoveTo(int index) {
    currentMovePlayer = index;
  }

  setNextPlayer(int times) {
    for (var i = 0; i < times; i++) {
      int numberOfPlayers = humanPlayers.length;
      if (currentMovePlayer == numberOfPlayers) {
        currentMovePlayer = 0;
      } else {
        currentMovePlayer++;
      }
    }
  }

  void razdachaToNextPlayer(int num) {
    for (var i = 0; i < num; i++) {
      cards[nextPlayer()].add(cards['base'].first);
      cards['base'].removeAt(0);
    }
  }

  String nextPlayer() {
    int numberOfPlayers = humanPlayers.length;
    if (currentMovePlayer + 1 == numberOfPlayers) {
      return humanPlayers[0];
    } else {
      return humanPlayers[currentMovePlayer + 1];
    }
  }

  Map<String, dynamic> makeRuleOperation(List<String> moveCards) {
    Map<String, dynamic> answer = {'updateCards' : false, 'countCards' : 0, 'setMast' : false};
    switch (dostOf(moveCards.first)) {
      case '6': {
        print('6: give 2 cards');
        razdachaToNextPlayer(2 * moveCards.length);
        answer['updateCards'] = true;
        answer['countCards'] = 2;
        setNextPlayer(2);
      }
      break;
      case '7': {
        print('7: give 1 card');
        razdachaToNextPlayer(1 * moveCards.length);
        answer['updateCards'] = true;
        answer['countCards'] = 1;
        print(setNextPlayer(2));
      }
      break;
      case '8': {
        print('8: give 1 card');
        razdachaToNextPlayer(1 * moveCards.length);
        answer['updateCards'] = true;
        answer['countCards'] = 1;
        print(setNextPlayer(1));
      }
      break;
      case 'Т':
        print(setNextPlayer(1 + moveCards.length));
      break;
      case 'В': {
        answer['setMast'] = true;
        print(setNextPlayer(1));
      }
      break;
    }
    return answer;
  }
}
