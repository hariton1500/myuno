import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'bridgeai.dart';
import 'uno.dart';

class GameServer {
  Map<String, Socket> clientsSockets = {};
  Map<String, int> scores = {};
  Map<String, String> playersInGames = {}, GamesWithPlayers = {}, lastMsg = {};
  List<String> players = [], rooms = [];
  Map<String, DateTime> lastAction = {};
  Socket currentSocket;
  //список экземпляров с играми
  List<Uno> games = [];
  Map<String, bool> playerIsHuman = {};

  void answerTo(List<String> to, Map<String, String> msg) {
    print('Sending message $msg: to $to');
    if (msg['type'] == 'inGame') if (msg['typeMove'] == 'setMast' ||
        msg['typeMove'] == 'moverIs') lastMsg = msg;
    to.forEach((_player) {
      if (playerIsHuman[_player]) {
        //print('Sending to $_player: ${clientsSockets[_player].remoteAddress.address}:${clientsSockets[_player].remotePort}');
        clientsSockets[_player].add(utf8.encode(json.encode(msg) + '|-|'));
      } else {
        //если робот, то ему отправляем только пакет с конкретным ходом и текущим раскладом его карт
        if (msg.containsKey('typeMove')) {
          print('Sending to bot $_player');
          if (msg['typeMove'] == 'youCanAddCards' ||
              msg['typeMove'] == 'moverIs' ||
              msg['typeMove'] == 'setMast') {
            Uno _game = games.firstWhere((__game) {
              return (__game.name == playersInGames[_player]);
            }, orElse: () => null);
            //Map<String, List<String>> _aiMove = BridgeAI(_player, _game.name, _game.cards, msg).fullMove;
            if (_game != null) {
              List<String> _coPlayers = _game.humanPlayers.toList();
              _coPlayers.remove(_player);
              Map<String, int> _coPlayersCards = {};
              _coPlayers.forEach((_name) {
                _coPlayersCards[_name] = _game.cards[_name].length;
              });
              AIAnswer aiMove = BridgeAI_2(
                      _player,
                      _game.name,
                      _game.cards[_player],
                      _coPlayersCards,
                      _game.cards['heap'].last,
                      msg)
                  .myFullMove;
              Timer(Duration(seconds: 1),
                  () => botOperation(aiMove, _game, _player));
            }
          }
        }
      }
    });
  }

  void botOperation(AIAnswer _aiMove, Uno _game, String _player) {
    //sleep(Duration(seconds: 1));
    print('We got move from AI:');
    if (_aiMove != null) {
      if (_aiMove.myMove != null) {
        print('move: ${_aiMove.myMove}');
        _aiMove.myMove.forEach((_card) {
          dynamic _msg = '';
          //{'type' : 'inGame', 'gameType' : 'addHeap', 'heap' : game.heapCards.last, 'name' : widget.player, 'gameName' : widget.gameName}
          _msg = {
            'type': 'inGame',
            'gameType': 'addHeap',
            'heap': _card,
            'name': _player,
            'gameName': _game.name
          };
          onInGameAnswer(_msg);
        });
        dynamic _msg = {
          'type': 'inGame',
          'gameType': 'playerMove',
          'gameName': _game.name,
          'move': json.encode(_aiMove.myMove),
          'mast': _aiMove.orderedMast != 0 ? _aiMove.orderedMast : null
        };
        print('sending: $_msg');
        onInGameAnswer(_msg);
      } else
        print('move: null');
      if (_aiMove.orderedMast != null) {
        print('ordered mast: ${_aiMove.orderedMast}');
      } else
        print('ordered mast: null');
      if (_aiMove.needCard != null)
        onInGameAnswer({
          'type': 'inGame',
          'gameType': 'takeCardFromBase',
          'name': _player,
          'gameName': _game.name
        });
    } else
      print('it is null');
  }

  handleSocketsStream(Socket client) {
    print('Socket client:');
    //print(client.remoteAddress.address + ':' + client.remotePort.toString());
    currentSocket = client;
    client.listen(hadleMsgInts,
        onDone: onClientSocketDone(client),
        onError: onClientSocketError,
        cancelOnError: true);
  }

  onClientSocketDone(Socket socket) {
    print('Client Socket is done');
    //print('${socket.remoteAddress.address}:${socket.remotePort}} closing');
    String _player = clientsSockets.keys.firstWhere(
        (__name) => clientsSockets[__name] == socket,
        orElse: () => null);
    if (_player != null) {
      print('Remove player: $_player');
      players.remove(_player);
      out(players, 'Players');
    } else
      print('unknown connection closed');
  }

  onClientSocketError(e) {
    print('Client Socket is Error $e');
  }

  hadleMsgInts(List<int> data) {
    String msg = utf8.decode(data, allowMalformed: true);
    if (msg.startsWith('{')) handleMsg(msg, currentSocket);
  }

  void out(Object info, String what) {
    String msg = '---------$what---------', msg2 = '';
    print(msg);
    print(info);
    for (var i = 0; i < msg.length; i++) {
      msg2 += '=';
    }
    print(msg2);
  }

  void hourTimer(Timer timer) {
    print('Hour timer tick: ${DateTime.now()}');
    List<String> _namesToDelete = [];
    players.forEach((_player) {
      if (lastAction[_player] != null) {
        print(
            'For $_player diff is ${lastAction[_player].difference(DateTime.now())}');
        if (-lastAction[_player].difference(DateTime.now()) >=
            Duration(minutes: 55)) _namesToDelete.add(_player);
      }
    });
    _namesToDelete.forEach((_player) {
      try {
        print('removing what I have from $_player');
        //убрать все что можно
        print('in clientsSockets: $clientsSockets');
        clientsSockets.removeWhere(
            (_player, _socket) => clientsSockets.keys.contains(_player));
        print('in players: $players');
        players.remove(_player);
        print('in gameList $rooms');
        if (rooms.contains(_player)) rooms.remove(_player);
      } on Exception catch (e) {
        print(e);
      }
    });
  }

  void handleMsg(message, Socket _socket) {
    print('Message received: $message');
    var msg;
    try {
      msg = jsonDecode(message);
    } on FormatException catch (e) {
      print(e);
      msg = {'type': 'errorParsing'};
    }
    switch (msg['type']) {
      case 'addPlayer':
        if (!players.contains(msg['name'])) {
          players.add(msg['name']);
          playerIsHuman[msg['name']] = true;
          //out(players, 'Players');
          print('Добавлен игрок по имени: ${msg['name']}');
          //print('client IP:${_socket.remoteAddress.address}:${_socket.remotePort}');
          clientsSockets[msg['name']] =
              _socket; //clients.last; //закрепляем сокет за игроком, чтобы знать кому отправлять сообщение
          lastAction[players.last] = DateTime.now();
          answerTo([
            msg['name']
          ], {
            'type': 'answer',
            'result': 'ok',
            'mess': 'Регистрация пройдена'
          });
        } else {
          answerTo([
            msg['name']
          ], {
            'type': 'answer',
            'result': 'notOk',
            'mess': 'Это имя уже занято'
          });
        }
        break;
      case 'getGamesList':
        String _fromName = msg['name'];
        answerTo([_fromName],
            {'type': 'gamesListUpdate', 'gamesList': jsonEncode(rooms)});
        break;
      case 'createGame':
        String _gameName = msg['name'];
        rooms.add(_gameName);
        print('Room ${rooms.last} created');
        answerTo([_gameName], {'type': 'roomCreated'});
        break;
      case 'deleteGame':
        String _gameName = msg['name'];
        rooms.remove(_gameName);
        scores.remove(_gameName);
        List<String> _playersOfGame = playersInGames.keys
            .where((_name) =>
                playersInGames[_name] == _gameName && playerIsHuman[_name])
            .toList();
        playersInGames
            .removeWhere((_player, _gameName) => _gameName == msg['name']);
        //out(gamesList, 'Games List');
        //out(playersInGames, 'Players in Games');
        _playersOfGame.forEach((_player) => answerTo([
              _player
            ], {
              'type': 'gameDestroyed',
              'name': msg['name'],
              'type2': 'gamesListUpdate',
              'gamesList': jsonEncode(rooms)
            }));
        games.removeWhere((_game) => _game.name == _gameName);
        break;
      case 'enterGame':
        String _gameName = msg['gameName'];
        String _playerName = msg['who'];
        List<String> _playersInRoom = playersInGames.keys
            .where((__name) => playersInGames[__name] == _gameName)
            .toList();
        print('in room $_gameName now $_playersInRoom');
        if (_playersInRoom.isNotEmpty) {
          //только зашедшему отправляем список тех кто уже в комнате
          Map<String, int> _scores = {};
          _playersInRoom.forEach((_player) {
            _scores[_player] = scores[_player];
          });
          answerTo([
            msg['who']
          ], {
            'type': 'playersInGames',
            'players': json.encode(_playersInRoom),
            'scores': json.encode(_scores)
          });
        }
        //добавляем заходящего в комнату
        print(playersInGames);
        playersInGames[msg['who']] = _gameName;
        print(playersInGames);
        //добавляем ему 0 в счетчик очков
        print('Scores: $scores');
        scores[_playerName] = 0;
        print('Scores: $scores');
        //добавляем вошедшего в список игроков комнаты
        _playersInRoom.add(_playerName);
        //отправляем всем, что добавлен еще один игрок
        answerTo(_playersInRoom, {
          'type': 'playersInGamesUpdate',
          'playerName': _playerName,
          'score': '0'
        });
        break;
      case 'continueGame':
        String _roomName = msg['gameName'];
        List<String> _players = playersInGames.keys
            .where((__name) => playersInGames[__name] == _roomName)
            .toList();
        print('in room $_roomName are players: $_players');
        print('clientsSockets are: $clientsSockets');
        Map<String, int> _scores = {};
        _players.forEach((_player) {
          _scores[_player] = scores[_player];
        });
        answerTo([
          msg['who']
        ], {
          'type': 'playersInGames',
          'players': json.encode(_players),
          'scores': json.encode(_scores)
        });
        break;
      case 'addBot':
        String _gameName = msg['gameName'];
        //генерируем нового игрока-бота
        String _botName = 'Bot' +
            DateTime.now().hour.toString() +
            DateTime.now().minute.toString() +
            DateTime.now().second.toString();
        players.add(_botName);
        playerIsHuman[_botName] = false;
        playersInGames[_botName] = _gameName;
        scores[_botName] = 0;
        List<String> _toPlayers = playersInGames.keys
            .where((__name) =>
                playersInGames[__name] == _gameName && playerIsHuman[__name])
            .toList();
        print('in game $_gameName are human players: $_toPlayers');
        print('clientsSockets are: $clientsSockets');
        List<Socket> _to = [];
        _toPlayers.forEach((_player) {
          //print('Player $_player ${clientsSockets[_player].remoteAddress.address}:${clientsSockets[_player].remotePort}');
          _to.add(clientsSockets[_player]);
        });
        answerTo(_toPlayers, {
          'type': 'playersInGamesUpdate',
          'playerName': _botName,
          'score': '0'
        });
        break;
      case 'leaveGame':
        String _gameName = msg['gameName'];
        playersInGames.remove(msg['who']);
        List<String> _toPlayers = playersInGames.keys
            .where((__name) => playersInGames[__name] == _gameName)
            .toList();
        List<Socket> _to = [];
        print('sending update of game $_gameName to players: ${_toPlayers}');
        _toPlayers.forEach((_player) => _to.add(clientsSockets[_player]));
        answerTo(_toPlayers,
            {'type': 'playersInGamesDowndate', 'playerName': msg['who']});
        break;
      case 'runGame':
        startGame(msg['gameName']);
        break;
      case 'inGame':
        onInGameAnswer(msg);
        break;
      case 'dataReady':
        answerTo([msg['from']], {'type': 'dataReadyOk'});
        break;
      default:
        print('Error of parsing :(');
        List<String> _commands = message.toString().split('}{');
        print('Separated: $_commands');
        if (_commands.length > 1) {
          _commands[0] += '}';
          _commands[1] = '{' + _commands[1];
          handleMsg(_commands[0], _socket);
          handleMsg(_commands[1], _socket);
        }
    }
  }

  onInGameAnswer(dynamic message) {
    print('ingame[${message['gameName']}] recieve: $message');
    int _index = games.indexWhere((game) {
      return game.name == message['gameName'].toString();
    });
    if (_index != -1) {
      Uno _game = games[_index];
      print('Game: ${_game.name}; Players: ${_game.humanPlayers}');
      _game.humanPlayers.forEach((_player) {
        print('$_player cards: ${_game.cards[_player]}');
      });
      switch (message['gameType']) {
        case 'takeCardFromBase':
          print('Take card from ${_game.cards['base']}');
          if (_game.cards['base'].length == 0) {
            print('Base is empty. Flip it!');
            _game.cards['base'] = _game.cards['heap'];
            _game.cards['heap'] = [_game.cards['heap'].last];
            _game.cards['base'].removeLast();
            print('Base flipped from HEAP and now is ${_game.cards['base']}');
          }
          String _card = _game.cards['base'].first;
          print('Taking $_card');
          _game.cards['base'].remove(_card);
          String _to = message['name'];
          _game.cards[_to].add(_card);
          print('$_to takes $_card from Base');
          answerTo([
            _to
          ], {
            'type': 'inGame',
            'typeMove': 'addCards',
            'cards': json.encode([_card])
          });
          List<String> _coP = _game.humanPlayers;
          _coP.forEach((_name) {
            answerTo([
              _name
            ], {
              'type': 'inGame',
              'typeMove': 'addCardsToCoPlayer',
              'name': _to,
              'cardsNumber': '1',
              'cards': json.encode([_card])
            });
          });
          answerTo([_to], lastMsg);
          break;
        case 'playerMove':
          List _move = json.decode(message['move']);
          List<String> __move = [];
          _move.forEach((_card) {
            __move.add(_card.toString());
            _game.cards[_game.humanPlayers[_game.currentMovePlayer]]
                .remove(_card);
          });
          print(
              'Recieved ${_game.humanPlayers[_game.currentMovePlayer]}-s move: $__move');
          lastAction[_game.humanPlayers[_game.currentMovePlayer]] =
              DateTime.now();
          print('Next Player now: ${_game.setNextPlayer(1)}');
          var toDo = _game.makeRuleOperation(__move);
          bool _checked = false;
          print('toDo is: $toDo');
          if (toDo['updateCards']) {
            //{'updateCards' : false, 'countCards' : 0, 'setMast' : false, 'simpleCard' : false, 'moveTo' : false, 'adding' : <String>[], 'addingForWho' : ''}
            int _cardsNumber = toDo['adding'].length;
            List<String> _cards = toDo['adding'];
            String _to = toDo['addingForWho'];
            answerTo([
              _to
            ], {
              'type': 'inGame',
              'typeMove': 'addCards',
              'cards': json.encode(_cards)
            });
            List<String> _coP = _game.humanPlayers;
            _coP.forEach((_name) {
              answerTo([
                _name
              ], {
                'type': 'inGame',
                'typeMove': 'addCardsToCoPlayer',
                'name': _to,
                'cardsNumber': _cardsNumber.toString(),
                'cards': json.encode(_cards)
              });
            });
            _checked = true;
            checkForAWinner(_game);
          }
          if (toDo['setMast']) {
            _game.orderedMast = message['mast'];
            if (_game.orderedMast == null)
              _game.orderedMast = _game.mastOf(__move.last);
            print('Ordered mast is: ${_game.orderedMast}');
            if (!checkForAWinner(_game))
              answerTo([
                _game.humanPlayers[_game.currentMovePlayer]
              ], {
                'type': 'inGame',
                'typeMove': 'setMast',
                'mast': _game.orderedMast
              });
          } else
            _game.orderedMast = '';
          if (toDo['simpleCard']) {
            if (!checkForAWinner(_game))
              answerTo(_game.humanPlayers, {
                'type': 'inGame',
                'typeMove': 'moverIs',
                'movePlayer': _game.humanPlayers[_game.currentMovePlayer]
              });
          }
          if (toDo['moveTo']) {
            print('Sending to ${_game.humanPlayers} who is move now');
            if (!_checked) {
              if (!checkForAWinner(_game))
                answerTo(_game.humanPlayers, {
                  'type': 'inGame',
                  'typeMove': 'moverIs',
                  'movePlayer': _game.humanPlayers[_game.currentMovePlayer]
                });
            } else
              answerTo(_game.humanPlayers, {
                'type': 'inGame',
                'typeMove': 'moverIs',
                'movePlayer': _game.humanPlayers[_game.currentMovePlayer]
              });
          }
          //проверка на то что кто-то выиграл
          //checkForAWinner(_game);
          break;
        case 'setMast':
          games[_index].orderedMast = message['orderedMast'];
          break;
        case 'getMyCardsAndInitMove':
          print('getCardsfrom ${message['name']}');
          Map<String, String> _msg = {'type': 'inGame'};
          Map<String, List<String>> _coPlayers = {};
          games[_index].humanPlayers.forEach((name) {
            if (message['name'].toString() != name) {
              _coPlayers[name] = games[_index].cards[name];
            }
          });
          _msg.addAll({
            'typeMove': 'yourCardsAndInitMove',
            'cards': json.encode(games[_index].cards[message['name']]),
            'heap': games[_index].cards['heap'].first,
            'base': json.encode(games[_index].cards['base'].length),
            'coPlayers': json.encode(_coPlayers)
          });
          print('Decided to send to ${[message['name']]} mess: $_msg');
          answerTo([message['name']], _msg);
          break;
        case 'whatNextFirst?':
          String _player = message['name'],
              _currentPlayer = _game.humanPlayers[_game.currentMovePlayer];
          if (_player == _currentPlayer) {
            if (_game.playerCanAddCardsToMove()) {
              answerTo([
                message['name']
              ], {
                'type': 'inGame',
                'typeMove': 'youCanAddCards',
                'dost': games.last.dostOf(games.last.cards['heap'].first)
              });
            } else {
              print('Player $_player has no cards to add for first move');
              onInGameAnswer({
                'type': 'inGame',
                'gameType': 'playerMove',
                'move': json.encode([_game.cards['heap'].last]),
                'gameName': message['gameName']
              });
            }
          } else
            answerTo(_game.humanPlayers, {
              'type': 'inGame',
              'typeMove': 'moverIs',
              'movePlayer': _game.humanPlayers[_game.currentMovePlayer]
            });
          break;
        case 'getMyCards':
          //отправляем игроку его карты
          answerTo([
            message['name']
          ], {
            'type': 'yourCards',
            'cards': json.encode(games[_index].cards[message['name']])
          });
          break;
        case 'getInitMove':
          //сообщаем про первую карту в куче
          answerTo([message['name']],
              {'type': 'initMove', 'heap': games[_index].cards['heap'].first});
          break;
        case 'addedCards':
          List<String> _move = [games[_index].cards['heap'].last];
          _move.addAll(message['moveCards']);
          var toDo = games[_index].makeRuleOperation(_move);
          print(toDo);
          break;
        case 'addHeap':
          //{'type' : 'inGame', 'gameType' : 'addHeap', 'heap' : game.heapCards.last, 'name' : widget.player, 'gameName' : widget.gameName}
          String _card = message['heap'].toString();
          _game.cards['heap'].add(_card);
          String _name = message['name'];
          _game.cards[_name].remove(_card);
          print('$_name made part of move by $_card');
          List<String> _coP = _game.humanPlayers;
          _coP.forEach((_player) {
            answerTo([
              _player
            ], {
              'type': 'inGame',
              'typeMove': 'playerPlacedCard',
              'name': _name,
              'card': _card
            });
          });
          break;
        default:
      }
    }
  }

  bool checkForAWinner(Uno _game) {
    String _winner = '';
    _game.humanPlayers.forEach((_player) {
      print(
          'player $_player has ${_game.cards[_player]}(${_game.cards[_player].length}) cards');
      if (_game.cards[_player].length == 0) _winner = _player;
    });
    if (_winner != '') {
      print('Got A Winner! $_winner');
      print('score before: ${_game.scores}');
      print('count score for ${_game.humanPlayers}');
      _game.humanPlayers.forEach((_player) {
        _game.cards[_player].forEach((_card) {
          if (_game.dostOf(_card) == '10' ||
              _game.dostOf(_card) == 'К' ||
              _game.dostOf(_card) == 'Д') {
            _game.scores[_player] += 10;
          }
          if (_game.dostOf(_card) == 'Т') _game.scores[_player] += 15;
          if (_game.dostOf(_card) == 'В') _game.scores[_player] += 20;
        });
        print('penalty for $_player is ${_game.scores[_player]}');
      });
      answerTo(_game.humanPlayers, {
        'type': 'inGame',
        'typeMove': 'winner',
        'winnerName': _winner,
        'scoreMap': json.encode(_game.scores)
      });
      print('Scores before: $scores');
      _game.scores.forEach((_player, _score) {
        scores[_player] += _score;
      });
      print('Scores after: $scores');
      games.remove(_game);
      return true;
    } else
      return false;
  }

  startGame(String gameName) {
    //ЗАПУСКАЕМ ИГРУ
    //формируем списки игроков и сокетов участников игры
    List<String> playersOfGame = []; //список игроков этой игры
    List<Socket> socketsTo = []; //список сокетов игроков этой игры
    playersInGames.forEach((String name, String game) {
      if (game == gameName) playersOfGame.add(name);
    });
    clientsSockets.forEach((String name, Socket socket) {
      if (playersOfGame.contains(name)) socketsTo.add(socket);
    });
    //создаем игру
    Uno game = Uno(gameName, playersOfGame);
    games.add(game);
    //определяем чей ход следующий
    game.currentMovePlayer = Random().nextInt(playersOfGame.length);
    print(
        'Current Move Player is: ${game.humanPlayers[game.currentMovePlayer]}');
    //достаем первую карту из колоды
    game.initMove();
    //отправляем игрокам сообщение о старте игры
    //Map<String, String> _msg = {};
    answerTo(playersOfGame,
        {'type': 'runGame', 'gameName': gameName, 'gameRunner': gameName});
  }
}

void main(List<String> args) {
  print('Сервер игры UNO:classic');
  GameServer unoServer = GameServer();
  runZoned(() async {
    ServerSocket.bind(InternetAddress.anyIPv4, 4040)
        .then((ServerSocket server) {
      server.listen(unoServer.handleSocketsStream);
      server.handleError((e) {
        print;
      });
    }).catchError((Object error) {
      print('error catched: $error');
    });
    Timer.periodic(Duration(minutes: 60), unoServer.hourTimer);
  }, onError: (e, StackTrace stack) {
    print('runtime error: $e');
  });
}
