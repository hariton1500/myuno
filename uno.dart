import 'dart:convert';
import 'dart:io';

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
      tempBase.add(cards[owner].elementAt(Random().nextInt(cards[owner].length)));
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


  List<String> letPlayerEndMoveWithSameDostCards(String dost) {
    List<String> _move = [];
    List<int> variants = [];
    print('Можно добавить карты к текущему ходу (укажите цифры через запятую):');
    int _index = 0;
    cards[humanPlayers[currentMovePlayer]].forEach((card) {
      if (card.startsWith(dost)) {
        print('Выбор: [$_index] $card');
        variants.add(_index);
      }
      _index++;
    });
    String input = stdin.readLineSync();
    //print(input);
    input.split(',').forEach((str){_move.add(cards[currentMovePlayer][int.parse(str)]);});
    return _move;
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
    if (currentMovePlayer == numberOfPlayers) {
      return humanPlayers[0];
    } else {
      return humanPlayers[currentMovePlayer + 1];
    }
  }

  String makeRuleOperation(List<String> moveCards) {
    Map<String, dynamic> answer = {'updateCards' : false, 'setMast' : false};
    switch (dostOf(moveCards.first)) {
      case '6': {
        razdachaToNextPlayer(2 * moveCards.length);
        answer['updateCards'] = true;
        setNextPlayer(2);
      }
      break;
      case '7': {
        razdachaToNextPlayer(1 * moveCards.length);
        answer['updateCards'] = true;
        setNextPlayer(2);
      }
      break;
      case '8': {
        razdachaToNextPlayer(1 * moveCards.length);
        answer['updateCards'] = true;
        setNextPlayer(1);
      }
      break;
      case 'T':
        setNextPlayer(2 + moveCards.length);
      break;
      case 'J': {
        answer['setMast'] = true;
      }
      break;
    }
    return json.encode(answer);
  }
}
