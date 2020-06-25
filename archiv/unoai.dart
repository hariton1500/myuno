
import 'dart:async';
import 'dart:convert';
import 'main.dart';

class BridgeAI{
  final String botName, gameName;
  List<String> myCards;
  final Map<String, List<String>> cards;
  String mastLimit = '', dostLimit = '', heapCard = '';
  Map<String, int> cardsCoPlayers = {};
  Map<String, List<String>> fullMove = {'move' : [], 'mast' : [], 'needCard' : []};
  String myMove;
  bool isMyMove;
  String moveMode;
  String moverName;
  bool isNoCardsToMove;
  int scoreOfGame;

  BridgeAI(this.botName, this.gameName, this.cards, Map msg) {
    heapCard = cards['heap'].last;
    myCards = cards[botName];
    handleMsg(msg);
  }


  List<String> myMoveIs() {
    List<String> _move = [], _moveVariants = [];
    _moveVariants = checkForCardsToMove();
    _moveVariants.shuffle();
    if (_moveVariants.length >= 0) {
      //есть карты для хода
      fullMove['move'] = [_moveVariants.first];
      if (dostOf(fullMove['move'].last) == 'В') fullMove['mast'] = ['П']; 
      _move = _moveVariants;
    } else {
      fullMove['needCard'] = ['yes'];
      //нет карт для хода
    }
    myMove = _move.last;
    return _move;
  }


  List<String> checkForCardsToMove() {
    print('AI: Check for cards to move');
    List<String> _answer = [];
    if (mastLimit.isNotEmpty) {
      print('AI: mode is Mast Limit ${mastLimit}');
      myCards.forEach((_card) {
        if (mastOf(_card) == mastLimit) {print('AI: card $_card is accaptable'); _answer.add(_card);}
        if (dostOf(_card) == 'В') {print('AI: card $_card is accaptable'); _answer.add(_card);}
      });
    }
    if (dostLimit.isNotEmpty) {
      print('AI: mode is Dost Limit ${dostLimit}');
      myCards.forEach((_card) {
        if (dostOf(_card) == dostLimit) {print('AI: card $_card is accaptable'); _answer.add(_card);}
        //if (game.dostOf(_card) == 'В') {print('AI: card $_card is accaptable'); _answer.add(_card);}
      });
    }
    if (dostLimit.isEmpty && mastLimit.isEmpty) {
      print('AI: mode is No Limit. Heap is $heapCard');
      myCards.forEach((_card) {
        if (dostOf(_card) == dostOf(heapCard)) {print('AI: card $_card is accaptable'); _answer.add(_card);}
        if (mastOf(_card) == mastOf(heapCard)) {print('AI: card $_card is accaptable'); _answer.add(_card);}
        if (dostOf(_card) == 'В') {print('AI: card $_card is accaptable'); _answer.add(_card);}
      });
    }
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

  void handleMsg(data) {
    Map msg = data;
    print('AI: recieved: $msg');
    switch (msg['type']) {
      case 'yourCards':
        //myMove.clear();
        for (var _card in json.decode(msg['cards'])) {
          myCards.add(_card.toString());
        }
        break;
      case 'runGame':
        //widget.socket.write(json.encode({'type' : 'inGame', 'gameType' : 'getMyCardsAndInitMove', 'name' : widget.player, 'gameName' : widget.gameName}));
        Timer(Duration(seconds: 2), () {
          aiSend(json.encode({'type' : 'inGame', 'gameType' : 'getMyCardsAndInitMove', 'name' : botName, 'gameName' : gameName}));
        });
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
              print('AI: $key have $value cards');
            });
            print('AI: 2sending: ${{'type' : 'inGame', 'gameType' : 'whatNextFirst?', 'name' : botName, 'gameName' : gameName}}');
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
            print('AI: My move now with mast limit $mastLimit');
            myMove = '';
            isMyMove = true;
            moveMode = 'addCardByMast';
            moverName = botName;
            //if (checkForCardsToMove().length >= 0) isNoCardsToMove = !true; else isNoCardsToMove = !false;
            myMoveIs();
            //if (game.myCards.any((element) => game.mastOf(element) != game.mastLimit || game.dostOf(element) != 'В')) isNoCardsToMove = true; else isNoCardsToMove = false;
            break;
          case 'moverIs':
            if (msg['movePlayer'].toString() == botName) {
              isMyMove = true;
              moveMode = 'newCard';
              print('AI: My move now');
              if (myMove?.length == 0) {
                print('AI: myMove is empty. Clean dost limits.');
                dostLimit = '';
              }
              myMoveIs();
            } else {
              isMyMove = false;
            }
            moverName = msg['movePlayer'];
            //print('AI: isMyMove: $isMyMove');
            //print('AI: move Player is: $moverName');
            break;
          case 'addCards':
            //isNoCardsToMove = !checkForCardsToMove();
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
              //cardsCoPlayers[msg['name']] -= 1;
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
}