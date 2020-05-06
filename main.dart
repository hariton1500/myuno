

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class Uno {
  List<String> humanPlayers = [], compPlayers = [], gamesList = [];
  List<String> mastList = ['П', 'Т', 'Б', 'Ч'];
  List<String> dostList = ['6', '7', '8', '9', '10', 'В', 'Д', 'К', 'Т'];
  int currentMovePlayer = 1, basePlayer = 0;
  Map<String, List<String>> cards = {};
  Map<String, String> playersInGames = {};
  
  Uno() {
    cards['base'] = [];
    cards['heap'] = [];
    //humanPlayers.forEach((player) => cards[player] = []);
    //compPlayers.forEach((player) => cards[player] = []);
    mastList.forEach((mast) {
      dostList.forEach((dost) {
        cards['base'].add(dost + '-' + mast);
      });
    });
    print('Карты: $cards');
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

  List<String> initMove() {
    List<String> _move = [];
    cards['heap'].add(cards['base'].first);
    print(cards['heap']);
    _move.add(cards['base'].first);
    cards['base'].removeAt(0);
    String _dost = cards['heap'].first.split('-')[0];
    bool _sameDostCards = false;
    cards[humanPlayers[currentMovePlayer]].forEach((card){
      if (card.startsWith(_dost)) _sameDostCards = true;
      }
    );
    if (_sameDostCards) {
      _move.addAll(letPlayerEndMoveWithSameDostCards(_dost));
      print('Ход: $_move');
    }
    else {
      print('Ход: $_move');
      print('Переход хода игроку: ${setNextPlayer()}');
    }
    return _move;
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

  String setNextPlayer() {
    int numberOfPlayers = humanPlayers.length + compPlayers.length;
    if (currentMovePlayer == numberOfPlayers) {
      currentMovePlayer = 0;
    } else {
      currentMovePlayer++;
    }
    return humanPlayers[currentMovePlayer];
  }

  void razdachaToCurrentPlayer(int num) {
    for (var i = 0; i < num; i++) {
      cards[currentMovePlayer].add(cards['base'].first);
      cards['base'].removeAt(0);
    }
  }
  void makeRuleOperation(List<String> moveCards) {
    List<String> _card;
    _card = cards['heap'].last.split('-');
    String _dost = _card[0];
    switch (_dost) {
      case '6': {
        razdachaToCurrentPlayer(2);
      }
      break;
      case '7': {
        razdachaToCurrentPlayer(1);
      }
      break;
      case '8': {
        setNextPlayer();
      }
    }
  }
}

class GameServer extends Uno {
  List<Socket> clients = [];
  Map<String, Socket> clientsSockets = {};
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
      client.write(msg);
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
        if (!humanPlayers.contains(msg['name'])) {
          humanPlayers.add(msg['name']);
          print('Добавлен игрок по имени: ${msg['name']}');
          clientsSockets[msg['name']] = clients.last;
          answerTo([clients.last], {'type' : 'answer', 'result' : 'ok', 'mess' : 'Регистрация пройдена'});
          answerTo(clients, {'type' : 'playersListUpdate', 'playersList' : jsonEncode(humanPlayers)});
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
        answerTo(clients, {'type' : 'playersInGamesUpdate', 'newPlayerInGame' : '${msg['who']};${msg['gameName']}'});
        break;
      default:
    }
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