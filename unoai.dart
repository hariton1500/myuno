
import 'dart:convert';

import 'main.dart';

class BridgeAI{
  final String botName, gameName;
  List<String> myCards = [];
  String mastLimit = '', dostLimit = '', heapCard = '';
  Map<String, int> cardsCoPlayers = {};

  String myMove;

  bool isMyMove;

  String moveMode;

  String moverName;

  bool isNoCardsToMove;

  int scoreOfGame;

  BridgeAI(this.botName, this.gameName, List<int> msg) {
    handleMsg(msg);
  }


  List<String> myMoveIs() {
    List<String> _move = [];
    //TODO ...
    if (checkForCardsToMove()) {
      //есть карты для хода
    } else {
      //нет карт для хода
    }


    return _move;
  }


  bool checkForCardsToMove() {
    print('Check for cards to move');
    bool _answer = false;
    if (mastLimit.isNotEmpty) {
      print('mode is Mast Limit ${mastLimit}');
      myCards.forEach((_card) {
        if (mastOf(_card) == mastLimit) {print('card $_card is accaptable'); _answer = true;}
        if (dostOf(_card) == 'В') {print('card $_card is accaptable'); _answer = true;}
      });
    }
    if (dostLimit.isNotEmpty) {
      print('mode is Dost Limit ${dostLimit}');
      myCards.forEach((_card) {
        if (dostOf(_card) == dostLimit) {print('card $_card is accaptable'); _answer = true;}
        //if (game.dostOf(_card) == 'В') {print('card $_card is accaptable'); _answer = true;}
      });
    }
    if (dostLimit.isEmpty && mastLimit.isEmpty) {
      print('mode is No Limit. Heap is $heapCard');
      myCards.forEach((_card) {
        if (dostOf(_card) == dostOf(heapCard)) {print('card $_card is accaptable'); _answer = true;}
        if (mastOf(_card) == mastOf(heapCard)) {print('card $_card is accaptable'); _answer = true;}
        if (dostOf(_card) == 'В') {print('card $_card is accaptable'); _answer = true;}
      });
    }
    print('Answer is : $_answer');
    return _answer;
  }

  String dostOf(String card) {
    return card.split('-')[0];
  }

  String mastOf(String card) {
    return card.split('-')[1];
  }

  void aiSend(String msg) {
    GameServer().handleMsg(msg, null);
  }

  void handleMsg(List<int> data) {
    String _msg = utf8.decode(data);
    print('Full message is: $_msg');
    _msg.split('|-|').forEach((element) {
      print(element);
      if (element.isNotEmpty) {
        var msg = jsonDecode(element);
        print('recieved: $msg');
        switch (msg['type']) {
          case 'yourCards':
            //myMove.clear();
            for (var _card in json.decode(msg['cards'])) {
              myCards.add(_card.toString());
            }
            break;
          case 'inGame':
            switch (msg['typeMove']) {
              case 'yourCardsAndInitMove':
                for (var _card in json.decode(msg['cards'])) {
                  myCards.add(_card.toString());
                }
                heapCard = msg['heap'];
                Map<String, dynamic> _coPs = json.decode(msg['coPlayers']);
                _coPs.forEach((key, value) {
                  cardsCoPlayers[key] = value;
                  print('$key have $value cards');
                });
                print('2sending: ${{'type' : 'inGame', 'gameType' : 'whatNextFirst?', 'name' : botName, 'gameName' : gameName}}');
                aiSend(json.encode({'type' : 'inGame', 'gameType' : 'whatNextFirst?', 'name' : botName, 'gameName' : gameName}));
                break;
              case 'youCanAddCards':
                dostLimit = msg['dost'];
                myMove = heapCard;
                isMyMove = true;
                moveMode = 'addCardByDost';
                moverName = botName;
                myMoveIs();
                break;
              case 'setMast':
                mastLimit = msg['mast'];
                myMove = '';
                isMyMove = true;
                moveMode = 'addCardByMast';
                moverName = botName;
                if (checkForCardsToMove()) isNoCardsToMove = !true; else isNoCardsToMove = !false;
                //if (game.myCards.any((element) => game.mastOf(element) != game.mastLimit || game.dostOf(element) != 'В')) isNoCardsToMove = true; else isNoCardsToMove = false;
                break;
              case 'moverIs':
                if (msg['movePlayer'].toString() == botName) {
                  isMyMove = true;
                  moveMode = 'newCard';
                  print('My move now. Now it is: ${myMove}');
                  if (myMove.length == 0) {
                    print('myMove is empty. Clean dost limits.');
                    dostLimit = '';
                  }
                  //проверка на наличие карт для хода
                  if (checkForCardsToMove()) {
                    print('I have cards to move');
                    isNoCardsToMove = false;
                  } else {
                    print('I need take cards from base');
                    isNoCardsToMove = true;
                    myMoveIs();
                  }
                } else {
                  isMyMove = false;
                }
                moverName = msg['movePlayer'];
                print('isMyMove: $isMyMove');
                print('move Player is: $moverName');
                break;
              case 'addCards':
                json.decode(msg['cards']).forEach((card) {
                  myCards.add(card.toString());
                });
                isNoCardsToMove = !checkForCardsToMove();
                break;
              //{'type' : 'inGame', 'typeMove': 'addCardsToCoPlayer', 'name' : _to, 'cardsNumber' : _cardsNumber.toString()}
              case 'addCardsToCoPlayer':
                if (msg['name'] != botName) {
                  moverName = msg['name'];
                  cardsCoPlayers[msg['name']] += int.parse(msg['cardsNumber']);
                }
                break;
              case 'playerPlacedCard':
                //{'type' : 'inGame', 'typeMove': 'playerPlacedCard', 'name' : _name, 'card' : _card}
                if (msg['name'] != botName) {
                  moverName = msg['name'];
                  heapCard = msg['card'];
                  cardsCoPlayers[msg['name']] -= 1;
                }
                break;
              case 'winner':
                //{'type' : 'inGame', 'typeMove' : 'winner', 'winnerName' : _winner, 'score' : _score.toString()}
                if (msg['winnerName'] == botName) {
                  scoreOfGame = 0;
                } else scoreOfGame = int.parse(msg['score']);
                //Navigator.pushReplacement(context, MaterialPageRoute(builder: (BuildContext context){return EndOfGamePage(player: botName, subscription: widget.subscription, socket: widget.socket, winner: msg['winnerName'], gameName: widget.gameName, score: scoreOfGame);}));
                break;
              default:
            }
          break;
        }
      }
    });
  }

}