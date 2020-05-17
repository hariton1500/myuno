import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'uno.dart';


class GameServer {
  List<Socket> clients = [];
  Map<String, Socket> clientsSockets = {};
  Map<String, int> scoreMap = {};
  Map<String, String> playersInGames = {}, GamesWithPlayers = {};
  List<String> players = [], gamesList = [];
  Map<Socket, String> socketsClients = {};


  //список игр
  List<Uno> games = [];
  /*void answerTo(List<String> to, Map<String, dynamic> msg) {
    to.forEach((element) {
      msg['msgTo'] = element;
      socket.add(jsonEncode(msg));
    });
    //msg['msgTo'] = to.first;
    //socket.add(jsonEncode(msg));
  }*/
  answerTo(List<Socket> to, Map<String, String> msg) {
    to.forEach((client) {
      print('Sending to ${socketsClients[client]}: ${client.remoteAddress.address}');
      print(msg);
      client.add(utf8.encode(json.encode(msg)));
    });
  }

  handleSocketsStream(Socket client) {
    print('Socket client:');
    print(client.remoteAddress.address + ':' + client.remotePort.toString());
    StreamSubscription<List<int>> subscript = client.listen(hadleMsgInts, onDone: onClientSocketDone(client), onError: onClientSocketError, cancelOnError: true);
    clients.add(client);
  }

  onClientSocketDone(Socket socket) {
    print('Client Socket is done');
    print('${socket.remoteAddress.address} closing');
    String _player = socketsClients[socket];
    if (_player != null) {
      print('Remove player: $_player');
      players.remove(_player);
      clients.remove(socket);
    }
  }

  onClientSocketError(e) {
    print('Client Socket is Error $e');
  }

  hadleMsgInts(List<int> data) {
    //print('msgInts: $data');
    String msg = utf8.decode(data);
    handleMsg(msg);
  }

  handleMsg(message) {
    print('Message received: $message');
    var msg = jsonDecode(message);
    switch (msg['type']) {
      case 'addPlayer':
        if (!players.contains(msg['name'])) {
          players.add(msg['name']);
          print('Добавлен игрок по имени: ${msg['name']}');
          print('client IP:${clients.last.remoteAddress.address}');
          clientsSockets[msg['name']] = clients.last; //закрепляем сокет за игроком, чтобы знать кому отправлять сообщение
          socketsClients[clients.last] = msg['name'];
          scoreMap[msg['name']] = 0; //инициализация счетчика очков
          answerTo([clients.last], {'type' : 'answer', 'result' : 'ok', 'mess' : 'Регистрация пройдена'});
        }
        else {
          answerTo([clients.last], {'type' : 'answer', 'result' : 'notOk', 'mess' : 'Это имя уже занято'});
        }
        break;
      case 'getGamesList':
        answerTo(clients, {'type' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)});
        break;
      case 'createGame':
        gamesList.add(msg['name']);
        playersInGames[msg['name']] = msg['name'];
        answerTo(clients, {'type' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)});
        break;
      case 'deleteGame':
        gamesList.remove(msg['name']);
        answerTo(clients, {'type' : 'gameDestroyed', 'name' : msg['name'], 'type2' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)});
        break;
      case 'enterGame':
        playersInGames[msg['who']] = msg['gameName'];
        answerTo(clients, {'type' : 'playersInGamesUpdate', 'newPlayerInGame' : jsonEncode(playersInGames)});
        break;
      case 'leaveGame':
        playersInGames.remove(msg['who']);
        answerTo(clients, {'type' : 'playersInGamesUpdate', 'newPlayerInGame' : jsonEncode(playersInGames)});
        break;
      case 'runGame':
        startGame(msg['gameName']);
        break;
      case 'inGame':
        onInGameAnswer(msg);
        break;
      case 'dataReady':
        answerTo([clientsSockets[msg['from']]], {'type' : 'dataReadyOk'});
        break;
      default:
    }
  }

  onInGameAnswer(dynamic message) {
    int _index = games.indexWhere((game){return game.name == message['gameName'];});
    switch (message['gameType']) {
      case 'playerMove':
        String answer = games[_index].makeRuleOperation(message['move']);
        var toDo = json.decode(answer);
        if (toDo['updateCards']) {
          String _whoGotNewCards = games[_index].nextPlayer();
          answerTo([clientsSockets[_whoGotNewCards]], {'type' : 'updateCards', 'cards' : json.encode(games[_index].cards[_whoGotNewCards])});
        }
        if (toDo['setMast']) {
          answerTo([clientsSockets[games[_index].currentMovePlayer]], {'type' : 'setMast'});
        }
        break;
      case 'setMast':
        games[_index].orderedMast = message['orderedMast'];
      break;
      case 'getMyCards':
      //отправляем игрокам их карты
        int _index = games.indexWhere((game){return game.name == message['gameName'];});
        answerTo([clientsSockets[message['name']]], {'type' : 'yourCards', 'cards' : json.encode(games[_index].cards[message['name']])});
      break;
      case 'getInitMove':
        //сообщаем про первую карту в куче
        int _index = games.indexWhere((game){return game.name == message['gameName'];});
        answerTo([clientsSockets[message['name']]], {'type' : 'initMove', 'heap' : games[_index].cards['heap'].first});
      break;
      default:
    }
  }

  startGame(String gameName) {
    //ЗАПУСКАЕМ ИГРУ
    //формируем списки игроков и сокетов участников игры
    List<String> playersOfGame = []; //список игроков этой игры
    List<Socket> socketsTo = []; //список сокетов игроков этой игры
    playersInGames.forEach((String name, String game){
      if (game == gameName) playersOfGame.add(name);
    });
    clientsSockets.forEach((String name, Socket socket){
      if (playersOfGame.contains(name)) socketsTo.add(socket);
    });
    //создаем игру
    Uno game = Uno(gameName, playersOfGame);
    games.add(game);
    //определяем чей ход следующий
    games.last.currentMovePlayer = Random().nextInt(playersOfGame.length);
    //достаем первую карту из колоды
    games.last.initMove();
    //отправляем игрокам сообщение о старте игры
    Map<String, String> _msg = {};
    _msg = {'type' : 'runGame', 'gameName' : gameName, 'gameRunner' : gameName, 'movePlayer' : playersOfGame[games.last.currentMovePlayer]};
    //sleep(Duration(milliseconds: 100));
    //если у текущего игрока есть карты того же достоинства то даем ему ими походить по желанию
    if (games.last.playerCanAddCardsToMove()) {
      //answerTo([socketsTo[games.last.currentMovePlayer]], {});
      _msg.addAll({'typeMove' : 'youCanAddCards', 'dost' : games.last.dostOf(games.last.cards['heap'].first)});
    }
    answerTo(socketsTo, _msg);

  }
}

void main(List<String> args) {
  print('Сервер игры UNO:classic');
  GameServer unoServer = GameServer();
  runZoned(() async {
    ServerSocket.bind(InternetAddress.anyIPv4, 4040).then((ServerSocket server) {
      server.listen(unoServer.handleSocketsStream);
      server.handleError((e){print;});
    }).catchError((Object error){});
  }, onError: (e, StackTrace stack){
    print('ServerSocket error: $e');
  });
}