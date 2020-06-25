class Uno {
  final List<String> humanPlayers, compPlayers = [];
  //Map<String, bool> playerIsHuman = {};
  final List<String> mastList = ['П', 'Т', 'Б', 'Ч'];
  final List<String> dostList = ['6', '7', '8', '9', '10', 'В', 'Д', 'К', 'Т'];
  int currentMovePlayer, basePlayer = 0;
  Map<String, List<String>> cards = {};
  final String name;
  String orderedMast = '';
  Map<String, int> scores = {};
  
  Uno(this.name, this.humanPlayers) {
    cards['base'] = [];
    cards['heap'] = [];
    humanPlayers.forEach((player) {
      cards[player] = [];
      scores[player] = 0;
    });
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
    print(cards[owner]);
    cards[owner].shuffle();
    /*
    List<String> temp = [];
    int _count = cards[owner].length;
    for (var i = 0; i < _count; i++) {
      String _card = cards[owner][Random().nextInt(cards[owner].length)];
      temp.add(_card);
      cards[owner].remove(_card);
    }
    cards[owner].clear();
    cards[owner] = temp;
    */
    print(cards[owner]);
  }

  void razdacha(int num) {
    print('cards before:');
    print(cards);
    for (var i = 0; i < num; i++) {
      humanPlayers.forEach((player) {
        cards[player].add(cards['base'].first);
        cards['base'].removeAt(0);
      });
      //print('$humanPlayers[i] cards: $cards[$humanPlayers[i]]');
    }
    print('cards after:');
    print(cards);
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

  String setNextPlayer(int times) {
    for (var i = 0; i < times; i++) {
      int numberOfPlayers = humanPlayers.length - 1;
      if (currentMovePlayer == numberOfPlayers) {
        currentMovePlayer = 0;
      } else {
        currentMovePlayer++;
      }
    }
    return humanPlayers[currentMovePlayer];
  }

  List<String> razdachaToCurrentPlayer(int num) {
    String _player = humanPlayers[currentMovePlayer];
    print('Razdacha $num cards to $_player');
    List<String> _adding = [];
    for (var i = 0; i < num; i++) {
      if (cards['base'].isEmpty) {
        cards['base'] = cards['heap'];
        cards['heap'] = [cards['heap'].last];
        cards['base'].removeLast();
      }
      _adding.add(cards['base'].first);
      cards['base'].removeAt(0);
    }
    cards[_player].addAll(_adding);
    return _adding;
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
    print('Analizing what to do with move: $moveCards');
    Map<String, dynamic> answer = {'updateCards' : false, 'countCards' : 0, 'setMast' : false, 'simpleCard' : false, 'moveTo' : false, 'adding' : <String>[], 'addingForWho' : ''};
    switch (dostOf(moveCards.first)) {
      case '6': {
        print('6: give 2 cards');
        answer['adding'] = razdachaToCurrentPlayer(2 * moveCards.length);
        answer['addingForWho'] = humanPlayers[currentMovePlayer];
        answer['updateCards'] = true;
        answer['countCards'] = 2;
        print('Move tranfer to ${setNextPlayer(1)}');
        answer['moveTo'] = true;
      }
      break;
      case '7': {
        print('7: give 1 card');
        answer['adding'] = razdachaToCurrentPlayer(moveCards.length);
        answer['addingForWho'] = humanPlayers[currentMovePlayer];
        answer['updateCards'] = true;
        answer['countCards'] = 1;
        print('Move tranfer to ${setNextPlayer(1)}');
        answer['moveTo'] = true;
      }
      break;
      case '8': {
        print('8: give 1 card');
        answer['adding'] = razdachaToCurrentPlayer(moveCards.length);
        answer['addingForWho'] = humanPlayers[currentMovePlayer];
        answer['updateCards'] = true;
        answer['countCards'] = 1;
        print(setNextPlayer(0));
        answer['moveTo'] = true;
      }
      break;
      case 'Т':
        //print('Т: next Player ${moveCards.length} times');
        print('Move tranfer to ${setNextPlayer(1)}');
        answer['moveTo'] = true;
      break;
      case 'В': {
        print('mastLimit');
        answer['setMast'] = true;
        print(setNextPlayer(0));
      }
      break;
      default:
        answer['simpleCard'] = true;
        print(setNextPlayer(0));
    }
    return answer;
  }
}
