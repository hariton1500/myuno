import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'uno.dart';
import 'unoai.dart';


class GameServer {
  Map<String, Socket> clientsSockets = {};
  Map<String, Map<String, int>> scoreMap = {};
  Map<String, String> playersInGames = {}, GamesWithPlayers = {};
  List<String> players = [], gamesList = [];
  Map<String, DateTime> lastAction = {};
  Socket currentSocket;
  //список игр
  List<Uno> games = [];
  Map<String, bool> playerIsHuman = {};

  answerTo(List<Socket> to, Map<String, String> msg) {
    to.forEach((socket) {
      String _name = clientsSockets.keys.firstWhere((__name) => clientsSockets[__name] == socket, orElse: () => null);
      if (playerIsHuman[_name]) {
        print('Sending to $_name: ${socket.remoteAddress.address}:${socket.remotePort}');
        print(msg);
        socket.add(utf8.encode(json.encode(msg) + '|-|'));
      } else {
        print('Sending to bot');
        print(msg);
        BridgeAI(_name, playersInGames[_name], utf8.encode(json.encode(msg) + '|-|'));
      }
    });
  }

  handleSocketsStream(Socket client) {
    print('Socket client:');
    print(client.remoteAddress.address + ':' + client.remotePort.toString());
    currentSocket = client;
    client.listen(hadleMsgInts, onDone: onClientSocketDone(client), onError: onClientSocketError, cancelOnError: true);
  }

  onClientSocketDone(Socket socket) {
    print('Client Socket is done');
    print('${socket.remoteAddress.address}:${socket.remotePort}} closing');
    String _player = clientsSockets.keys.firstWhere((__name) => clientsSockets[__name] == socket, orElse: () => null);
    if (_player != null) {
      print('Remove player: $_player');
      players.remove(_player);
      out(players, 'Players');
    } else print('unknown connection closed');
  }

  onClientSocketError(e) {
    print('Client Socket is Error $e');
  }

  hadleMsgInts(List<int> data) {
    //print('msgInts: $data');
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
      print('For $_player diff is ${lastAction[_player].difference(DateTime.now())}');
      if (-lastAction[_player].difference(DateTime.now()) >= Duration(minutes: 55)) _namesToDelete.add(_player);
    });
    _namesToDelete.forEach((_player) {
        try {
          print('removing what I have from $_player');
          //убрать все что можно
          print('in clientsSockets: $clientsSockets');
          clientsSockets.removeWhere((_player, _socket) => clientsSockets.keys.contains(_player));
          print('in players: $players');
          players.remove(_player);
          print('in gameList $gamesList');
          if (gamesList.contains(_player)) gamesList.remove(_player);
        } on Exception catch (e) {print(e);}
    });
  }

  handleMsg(message, Socket _socket) {
    print('Message received: $message');
    var msg;
    try {
      msg = jsonDecode(message);
    } on FormatException catch (e) {
      print(e);
      msg = {'type' : 'errorParsing'};
    }
    switch (msg['type']) {
      case 'addPlayer':
        if (!players.contains(msg['name'])) {
          players.add(msg['name']);
          out(players, 'Players');
          print('Добавлен игрок по имени: ${msg['name']}');
          print('client IP:${_socket.remoteAddress.address}:${_socket.remotePort}');
          clientsSockets[msg['name']] = _socket;//clients.last; //закрепляем сокет за игроком, чтобы знать кому отправлять сообщение
          lastAction[players.last] = DateTime.now();
          //scoreMap[msg['name']] = {0}; //инициализация счетчика очков
          out(scoreMap, 'Score');
          answerTo([_socket], {'type' : 'answer', 'result' : 'ok', 'mess' : 'Регистрация пройдена'});
        }
        else {
          answerTo([_socket], {'type' : 'answer', 'result' : 'notOk', 'mess' : 'Это имя уже занято'});
        }
        break;
      case 'getGamesList':
        String _fromName = msg['name'];
        answerTo([clientsSockets[_fromName]], {'type' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)});
        break;
      case 'createGame':
        gamesList.add(msg['name']);
        out(gamesList, 'Games List');
        playersInGames[msg['name']] = msg['name'];
        out(playersInGames, 'Players in Games');
        //answerTo(socketsClients.keys.toList(), {'type' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)});
        break;
      case 'deleteGame':
        String _gameName = msg['name'];
        gamesList.remove(_gameName);
        List<String> _playersOfGame = playersInGames.keys.where((_name) => playersInGames[_name] == _gameName).toList();
        playersInGames.removeWhere((_player, _gameName) => _gameName == msg['name']);
        out(gamesList, 'Games List');
        out(playersInGames, 'Players in Games');
        _playersOfGame.forEach((_player) => answerTo([clientsSockets[_player]], {'type' : 'gameDestroyed', 'name' : msg['name'], 'type2' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)}));
        break;
      case 'enterGame':
        String _gameName = msg['gameName'];
        playersInGames[msg['who']] = _gameName;
        out(playersInGames, 'Players in Games');
        List<String> _toPlayers = playersInGames.keys.where((__name) => playersInGames[__name] == _gameName).toList();
        print('in game $_gameName are players: $_toPlayers');
        print('clientsSockets are: $clientsSockets');
        List<Socket> _to = [];
        _toPlayers.forEach((_player) {
          print('Player $_player ${clientsSockets[_player].remoteAddress.address}:${clientsSockets[_player].remotePort}');
          _to.add(clientsSockets[_player]);
        });
        answerTo(_to, {'type' : 'playersInGamesUpdate', 'newPlayerInGame' : jsonEncode(playersInGames.keys.where((__name) => playersInGames[__name] == _gameName).toList())});
        break;
      case 'leaveGame':
        String _gameName = msg['gameName'];
        playersInGames.remove(msg['who']);
        out(playersInGames, 'Players in Games');
        List<String> _toPlayers = playersInGames.keys.where((__name) => playersInGames[__name] == _gameName).toList();
        List<Socket> _to = [];
        print('sending update of game $_gameName to players: ${_toPlayers}');
        _toPlayers.forEach((_player) => _to.add(clientsSockets[_player]));
        answerTo(_to, {'type' : 'playersInGamesUpdate', 'newPlayerInGame' : jsonEncode(playersInGames.keys.where((__name) => playersInGames[__name] == _gameName).toList())});
        break;
      case 'runGame':
        //TODO msg['players']
        /*
        List<String> _players = [];
        json.decode(msg['players']).forEach((_player) {
          _players.add(_player);
        });
        */
        startGame(msg['gameName']);
        break;
      case 'inGame':
        onInGameAnswer(msg);
        break;
      case 'dataReady':
        answerTo([clientsSockets[msg['from']]], {'type' : 'dataReadyOk'});
        break;
      default:
        print('Error of parsing (');
        List<String> _commands = message.toString().split('}{');
        print('Separated: $_commands');
        _commands[0] += '}';
        _commands[1] = '{' + _commands[1];
        handleMsg(_commands[0], _socket);
        handleMsg(_commands[1], _socket);
    }
  }

  onInGameAnswer(dynamic message) {
    print('ingame recieve: $message');
    int _index = games.indexWhere((game){return game.name == message['gameName'];});
    if (_index != -1) {
      Uno _game = games[_index];
      print('Game: ${_game.name}; Human players: ${_game.humanPlayers}; Players sockets:');
      _game.humanPlayers.forEach((_name) {
        print('$_name: ${clientsSockets[_name].address.toString()}:${clientsSockets[_name].port.toString()}');
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
          answerTo([clientsSockets[_to]], {'type' : 'inGame', 'typeMove': 'addCards', 'cards' : json.encode([_card])});
          List<String> _coP = _game.humanPlayers;
          //_coP.remove(_to);
          _coP.forEach((_name) {
            answerTo([clientsSockets[_name]], {'type' : 'inGame', 'typeMove': 'addCardsToCoPlayer', 'name' : _to, 'cardsNumber' : '1'});
          });
          break;
        case 'playerMove':
          List _move = json.decode(message['move']);
          List<String> __move = [];
          _move.forEach((_card) {__move.add(_card.toString());});
          print('Recieved ${_game.humanPlayers[_game.currentMovePlayer]}-s move: $__move');
          lastAction[_game.humanPlayers[_game.currentMovePlayer]] = DateTime.now();
          print('Next Player now: ${_game.setNextPlayer(1)}');
          var toDo = _game.makeRuleOperation(__move);
          print('toDo is: $toDo');
          if (toDo['updateCards']) {
            //{'updateCards' : false, 'countCards' : 0, 'setMast' : false, 'simpleCard' : false, 'moveTo' : false, 'adding' : <String>[], 'addingForWho' : ''}
            int _cardsNumber = toDo['adding'].length;
            List<String> _cards = toDo['adding'];
            String _to = toDo['addingForWho'];
            answerTo([clientsSockets[_to]], {'type' : 'inGame', 'typeMove': 'addCards', 'cards' : json.encode(_cards)});
            List<String> _coP = _game.humanPlayers;
            //_coP.remove(_to);
            _coP.forEach((_name) {
              answerTo([clientsSockets[_name]], {'type' : 'inGame', 'typeMove': 'addCardsToCoPlayer', 'name' : _to, 'cardsNumber' : _cardsNumber.toString()});
            });
          }
          if (toDo['setMast']) {
            _game.orderedMast = message['mast'];
            answerTo([clientsSockets[_game.humanPlayers[_game.currentMovePlayer]]], {'type' : 'inGame', 'typeMove' : 'setMast', 'mast' : _game.orderedMast});
          }
          if (toDo['simpleCard']) {
            _game.humanPlayers.forEach((_name) {
              answerTo([clientsSockets[_name]], {'type' : 'inGame', 'typeMove' : 'moverIs', 'movePlayer' : _game.humanPlayers[_game.currentMovePlayer]});
            });
          }
          if (toDo['moveTo']) {
            print('Sending to ${_game.humanPlayers} who is move now');
            _game.humanPlayers.forEach((_player){
              answerTo([clientsSockets[_player]], {'type' : 'inGame', 'typeMove' : 'moverIs', 'movePlayer' : _game.humanPlayers[_game.currentMovePlayer]});
            });
          }
          //TODO проверка на то что кто-то выиграл
          String _winner = '';
          _game.humanPlayers.forEach((_player) {
            print('player $_player has ${_game.cards[_player]}(${_game.cards[_player].length}) cards');
            if (_game.cards[_player].length == 0) _winner = _player;
          });
          if (_winner != '') {
            print('Got A Winner! $_winner');
            _game.humanPlayers.forEach((_player){
              if (_player != _winner) {
                int _score = 0;
                _game.cards[_player].forEach((_card) {
                  if (_game.dostOf(_card) == '10' ||
                      _game.dostOf(_card) == 'К' ||
                      _game.dostOf(_card) == 'Д') {
                    _score += 10;
                  }
                  if (_game.dostOf(_card) == 'Т') _score += 15;
                  if (_game.dostOf(_card) == 'В') _score += 20;
                });
              scoreMap[_game.name].update(_player, (__score) {return __score += _score;}); 
              answerTo([clientsSockets[_player]], {'type' : 'inGame', 'typeMove' : 'winner', 'winnerName' : _winner, 'score' : _score.toString()});
              } else
              answerTo([clientsSockets[_player]], {'type' : 'inGame', 'typeMove' : 'winner', 'winnerName' : _winner});
            });
            games.remove(_game);
          };
          break;
        case 'setMast':
          games[_index].orderedMast = message['orderedMast'];
        break;
        case 'getMyCardsAndInitMove':
          Map<String, String> _msg = {'type' : 'inGame'};
          Map<String, int> _coPlayers = {};
          games[_index].cards.forEach((name, cardsOfName){
            if (name != 'base' && name != 'heap' && message['name'].toString() != name) {
              _coPlayers[name] = games[_index].cards[name].length;
            }
          });
          _msg.addAll({
            'typeMove' : 'yourCardsAndInitMove',
            'cards' : json.encode(games[_index].cards[message['name']]),
            'heap' : games[_index].cards['heap'].first,
            'base' : json.encode(games[_index].cards['base'].length),
            'coPlayers' : json.encode(_coPlayers)
          });
          //if (games[_index].playerCanAddCardsToMove()) _msg.addAll({'typeMove' : 'youCanAddCards', 'dost' : games.last.dostOf(games.last.cards['heap'].first)});
          answerTo([clientsSockets[message['name']]], _msg);
        break;
        case 'whatNextFirst?':
          String _player = message['name'], _currentPlayer = _game.humanPlayers[_game.currentMovePlayer];
          if (_player == _currentPlayer) {
            if (_game.playerCanAddCardsToMove()) {
              answerTo([clientsSockets[message['name']]], {'type' : 'inGame', 'typeMove' : 'youCanAddCards', 'dost' : games.last.dostOf(games.last.cards['heap'].first)});
            } else {
              print('Player $_player has no cards to add for first move');
              onInGameAnswer({'type' : 'inGame', 'gameType' : 'playerMove', 'move' : json.encode([_game.cards['heap'].last]), 'gameName' : message['gameName']});}
          } else answerTo([clientsSockets[message['name']]], {'type' : 'inGame', 'typeMove' : 'moverIs', 'movePlayer' : _game.humanPlayers[_game.currentMovePlayer]});
          break;
        case 'getMyCards':
        //отправляем игроку его карты
          answerTo([clientsSockets[message['name']]], {'type' : 'yourCards', 'cards' : json.encode(games[_index].cards[message['name']])});
        break;
        case 'getInitMove':
          //сообщаем про первую карту в куче
          answerTo([clientsSockets[message['name']]], {'type' : 'initMove', 'heap' : games[_index].cards['heap'].first});
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
          //_coP.remove(_name);
          _coP.forEach((_player) {
            answerTo([clientsSockets[_player]], {'type' : 'inGame', 'typeMove': 'playerPlacedCard', 'name' : _name, 'card' : _card});
          });
          break;
        default:
      }
    }
  }

  void grepOfMove(Map<String, dynamic> move, int index) {
    if (move['setMast']) {
      //answerTo(to, msg);
    }
  }

  startGame(String gameName) {
    //ЗАПУСКАЕМ ИГРУ
    gamesList.remove(gameName);
    //формируем списки игроков и сокетов участников игры
    List<String> playersOfGame = []; //список игроков этой игры
    List<Socket> socketsTo = []; //список сокетов игроков этой игры
    playersInGames.forEach((String name, String game){
      if (game == gameName) playersOfGame.add(name);
    });
    Map<String, int> _score = {};
    playersOfGame.forEach((_name) => _score[_name] = 0);
    scoreMap[gameName] = _score;
    clientsSockets.forEach((String name, Socket socket){
      if (playersOfGame.contains(name)) socketsTo.add(socket);
    });
    //создаем игру
    Uno game = Uno(gameName, playersOfGame);
    games.add(game);
    //определяем чей ход следующий
    game.currentMovePlayer = Random().nextInt(playersOfGame.length);
    print('Current Move Player is: ${game.humanPlayers[game.currentMovePlayer]}');
    //достаем первую карту из колоды
    game.initMove();
    //отправляем игрокам сообщение о старте игры
    //Map<String, String> _msg = {};
    answerTo(socketsTo, {'type' : 'runGame', 'gameName' : gameName, 'gameRunner' : gameName});
  }
}

void main(List<String> args) {
  print('Сервер игры UNO:classic');
  GameServer unoServer = GameServer();
  runZoned(() async {
    ServerSocket.bind(InternetAddress.anyIPv4, 4040).then((ServerSocket server) {
      server.listen(unoServer.handleSocketsStream);
      server.handleError((e){print;});
    }).catchError((Object error){print('error catched: $error');});
    Timer.periodic(Duration(minutes: 60), unoServer.hourTimer);
  }, onError: (e, StackTrace stack){
    print('runtime error: $e');
  });
}