import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'uno.dart';


class GameServer {
  List<Socket> clients = [];
  Map<String, Socket> clientsSockets = {};
  Map<String, int> scoreMap = {};
  Map<String, String> playersInGames = {};
  List<String> players = [], gamesList = [];

  //список игр
  List<Uno> games;
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
      client.add(utf8.encode(json.encode(msg)));
      //client.writeln();
      //Future.delayed(Duration(milliseconds: 100));
    });
  }

  handleServerSocket(Socket client) {
    print('Socket client:');
    print(client.remoteAddress.address + ':' + client.remotePort.toString());
    client.listen(hadleMsgInts);
    clients.add(client);
    //clientsSockets['$client.remoteAddress.address:${client.remotePort.toString()}'] = client;
  }

  hadleMsgInts(List<int> data) {
    String msg = String.fromCharCodes(data).trim();
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
          scoreMap[msg['name']] = 0; //инициализация счетчика очков
          answerTo([clients.last], {'type' : 'answer', 'result' : 'ok', 'mess' : 'Регистрация пройдена'});
          sleep(Duration(milliseconds: 100));
          answerTo(clients, {'type' : 'playersListUpdate', 'playersList' : jsonEncode(players)});
          sleep(Duration(milliseconds: 100));
          answerTo(clients, {'type' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)});
        }
        else {
          answerTo([clients.last], {'type' : 'answer', 'result' : 'notOk', 'mess' : 'Это имя уже занято'});
        }
        break;
      case 'createGame':
        gamesList.add(msg['name']);
        answerTo(clients, {'type' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)});
        break;
      case 'deleteGame':
        gamesList.remove(msg['name']);
        answerTo(clients, {'type' : 'gamesListUpdate', 'gamesList' : jsonEncode(gamesList)});
        break;
      case 'enterGame':
        playersInGames[msg['who']] = msg['gameName'];
        answerTo(clients, {'type' : 'playersInGamesUpdate', 'newPlayerInGame' : jsonEncode(playersInGames)});
        break;
      case 'runGame':
        startGame(msg['gameName']);
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
    //отправляем игрокам сообщение о старте игры
    answerTo(socketsTo, {'type' : 'startGame', 'gameName' : gameName, 'gameRunner' : gameName});
    //отправляем игрокам их карты
    game.humanPlayers.forEach((String player){
      answerTo([clientsSockets[player]], {'type' : 'yourCards', 'cards' : json.encode(game.cards[player])});
    });
    //определяем чей ход
    game.currentMovePlayer = Random().nextInt(playersOfGame.length);

  }
}
//WebSocket socket;

void main(List<String> args) {
  print('Сервер игры UNO:classic');
  GameServer unoServer = GameServer();
  runZoned(() async {
    /*var server = await HttpServer.bind(InternetAddress.anyIPv4, 4040);
    await for (var req in server) {
      //print(req.uri.pathSegments);
      if (req.uri.path == '/') {
        // Upgrade a HttpRequest to a WebSocket connection.
        socket = await WebSocketTransformer.upgrade(req);
        socket.listen(unoServer.handleMsg);
      }
    }*/
    ServerSocket.bind(InternetAddress.anyIPv4, 4040).then((ServerSocket server) {
      server.listen(unoServer.handleServerSocket);
    });
  }, onError: (e) => print(e));

}