class AIAnswer {
  List<String> myMove;
  String orderedMast;
  bool needCard;
}

class BridgeAI_2 {
  final String myName, gameName;
  final List<String> myCards;
  final Map<String, int> coPlayersCards;
  final String heapCard;
  AIAnswer myFullMove;
  String moveMode, orderedMast = '', dostLimit = '';
  //moveMode types: notMyMove, simpleMove, mastLimit, dostLimit

  BridgeAI_2(this.myName, this.gameName, this.myCards, this.coPlayersCards, this.heapCard, Map msg) {
    handleMsg(msg);
    myFullMove = getMove();
  }

  AIAnswer getMove() {
    //sleep(Duration(seconds: 1, milliseconds: 500));
    AIAnswer _answer = AIAnswer();
    if (moveMode != 'notMyMove') {
      //мой ход
      List<String> _onHeapCards = getCardsICanMove(); //список карт, которые можно применить
      if (_onHeapCards.length > 0) {
        //карты подходящие есть
        //ищем среди них с теми же достоинствами
        Map<String, int> _sameDostMap = getMapOfCardsWithSameDost(_onHeapCards);
        print('AI: same dost map from $_onHeapCards is $_sameDostMap');
        //получаем карту с максимальным количеством
        String _card = getCardWithMaxCountOfSameDost(_sameDostMap);
        print('AI: max count of $_sameDostMap is $_card');
        _answer.myMove = [_card];
        List<String> _sameDostCards = getSameDostCardsOf(_card);
        print('AI: same dost cards for $_card is $_sameDostCards');
        _answer.myMove.addAll(_sameDostCards);
        if (dostOf(_answer.myMove.last) == 'В') _answer.orderedMast = mastOf(_answer.myMove.last);
        return _answer;
      } else {
        //подходящих карт нет, надо указать это в ответе
        _answer.needCard = true;
        return _answer;
      }
    } else {
      //не мой ход
      _answer = null;
      return _answer;
    }
  }

  String getCardWithMaxCountOfSameDost(Map<String, int> _cardMap) {
    String _card = '';
    int _count = 0;
    _cardMap.forEach((__card, __count) {
      if (__count > _count) {
        _card = __card;
        _count = __count;
      }
    });
    return _card;
  }

  List<String> getSameDostCardsOf(String _card) {
    List<String> _answer = [];
    myCards.forEach((__card) {
      if (_card != __card && dostOf(_card) == dostOf(__card)) _answer.add(__card);
    });
    return _answer;
  }

  Map<String, int> getMapOfCardsWithSameDost(List<String> _listCards) {
    Map<String, int> _answer = {};
    _listCards.forEach((_card) {
      _answer[_card] = 0;
      List<String> _leftCards = _listCards;
      //_leftCards.remove(_card);
      _leftCards.forEach((_leftCard) {
        if (dostOf(_leftCard) == dostOf(_card)) _answer[_card] += 1;
      });
    });
    return _answer;
  }

  List<String> getCardsICanMove() {
    print('AI: Check for cards to move from $myCards');
    List<String> _answer = [];
    if (orderedMast.isNotEmpty) {
      print('AI: mode is Mast Limit ${orderedMast}');
      myCards.forEach((_card) {
        if (mastOf(_card) == orderedMast) {print('AI: card $_card is accaptable'); _answer.add(_card);}
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
    if (dostLimit.isEmpty && orderedMast.isEmpty) {
      print('AI: mode is No Limit. Heap is $heapCard');
      myCards.forEach((_card) {
        if (dostOf(_card) == dostOf(heapCard)) {print('AI: card $_card is accaptable'); _answer.add(_card);}
        if (mastOf(_card) == mastOf(heapCard)) {print('AI: card $_card is accaptable'); _answer.add(_card);}
        if (dostOf(_card) == 'В' && !_answer.contains(_card)) {print('AI: card $_card is accaptable'); _answer.add(_card);}
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

  void handleMsg(Map _msg) {
    print('AI: recieved: $_msg');
    if (_msg['type'] == 'inGame') {
      switch (_msg['typeMove']) {
        case 'moverIs':
          //{'type' : 'inGame', 'typeMove' : 'moverIs', 'movePlayer' : _game.humanPlayers[_game.currentMovePlayer]});
          String _movePlayer = _msg['movePlayer'];
          if (_movePlayer != myName) {
            print('AI: another player $_movePlayer moves now...');
            moveMode = 'notMyMove';
          } else {
            print('AI: my move now.');
            moveMode = 'simpleMove';
          }
          break;
        case 'setMast':
          //{'type' : 'inGame', 'typeMove' : 'setMast', 'mast' : _game.orderedMast}
          String _mast = _msg['mast'];
          orderedMast = _mast;
          moveMode = 'mastLimit';
          break;
        case 'youCanAddCards':
          //{'type' : 'inGame', 'typeMove' : 'youCanAddCards', 'dost' : games.last.dostOf(games.last.cards['heap'].first)}
          String _dost = _msg['dost'];
          dostLimit = _dost;
          moveMode = 'dostLimit';
          break;
        default:
      }
    }
  }
}