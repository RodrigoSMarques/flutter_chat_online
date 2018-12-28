import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
//Comprimir a imagem
import 'package:image/image.dart' as Im;
import 'dart:math' as Math;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';


void main() {
  //Escrever
  /*
  //Firestore.instance.collection("teste").document("teste3").setData({"teste3":"teste3"});

  //msg1 = chave
  Firestore.instance.collection("mensagens").document("msg1").setData({"from":"Daniel", "texto":"Olá"});
  //gera chave
  Firestore.instance.collection("mensagens").document().setData({"from":"Daniel", "texto":"Olá 2"});
  //Subcolections
  Firestore.instance.collection("mensagens").document().collection("arquimidia").document().setData({"from":"Daniel", "texto":"Olá 2"});
  */

  runApp(new MyApp());
}

final ThemeData KDefaultTheme = ThemeData(
  primarySwatch: Colors.purple,
  accentColor: Colors.orangeAccent[400],
);

final ThemeData KIOSTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.grey[100],
    primaryColorBrightness: Brightness.light);

final googleSigIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSigIn.currentUser;

  //Tenta login silecinsioso
  if (user == null) {
    user = await googleSigIn.signInSilently();
  }

  if (user == null) {
    user = await googleSigIn.signIn();
  }

  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials =
        await googleSigIn.currentUser.authentication;
    await auth.signInWithGoogle(
        idToken: credentials.idToken, accessToken: credentials.accessToken);
  }
}

Future<Null> _handleSubmitted(String text) async {
  await _ensureLoggedIn();
  _sendMessage(text: text);
}

_sendMessage({String text, String imgUrl}) {
  Firestore.instance.collection("messages").add({
    "text": text,
    "imgUrl": imgUrl,
    "senderName": googleSigIn.currentUser.displayName,
    "senderPhotoURL": googleSigIn.currentUser.photoUrl
  });
}

//https://stackoverflow.com/questions/46515679/flutter-firebase-compression-before-upload-image
Future<File> _selectedImage() async {

  File imgFile = await ImagePicker.pickImage(source: ImageSource.gallery);
  final tempDir = await getTemporaryDirectory();
  final path = tempDir.path;
  int rand = new Math.Random().nextInt(10000);

  Im.Image image = Im.decodeImage(imgFile.readAsBytesSync());
  Im.Image smallerImage = Im.copyResize(image, 1024); // choose the size here, it will maintain aspect ratio

  //return new File('$path/img_$rand.jpg')..writeAsBytesSync(Im.encodeJpg(image, quality: 85));
  //Imagem reduzida e com 85% de compressão
  return new File('$path/img_$rand.jpg')..writeAsBytesSync(Im.encodeJpg(smallerImage, quality: 85));
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ChatApp Flutter",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS
          ? KIOSTheme
          : KDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      top: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Chat App"),
          centerTitle: true,
          elevation:
              Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                  stream: Firestore.instance.collection("messages").snapshots(),
                  builder: (context, snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      default:
                        print(snapshot.data);
                        return ListView.builder(
                            reverse: true, //debaixo para cima
                            itemCount: snapshot.data.documents.length,
                            itemBuilder: (context, index) {
                              //return ChatMessage(snapshot.data.documents[index].data);
                              //inverter documentos mais atuais em baixo
                              List r =
                                  snapshot.data.documents.reversed.toList();
                              return ChatMessage(r[index].data);
                            });
                    }
                  }),
            ),
            Divider(
              height: 1.0,
            ),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: TextComposer(),
            )
          ],
        ),
      ),
    );
  }
}

//Padding é externo
//margin é externo

class _TextComposerState extends State<TextComposer> {
  bool _isComposing = false;
  final _textController = TextEditingController();

  void _reset() {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        //bordar
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200])))
            : null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                  icon: Icon(Icons.photo_camera),
                  onPressed: () async {
                    await _ensureLoggedIn();
                    //File imgFile = await ImagePicker.pickImage(source: ImageSource.gallery);

                    File imgFile = await _selectedImage();

                    if (imgFile == null) {
                      return;
                    }

                    StorageUploadTask task = FirebaseStorage.instance
                        .ref()
                        .child(googleSigIn.currentUser.id.toString() +
                            DateTime.now().millisecondsSinceEpoch.toString())
                        .putFile(imgFile);

                    task.onComplete.then((returnTask) {
                      returnTask.ref.getDownloadURL().then((url) {
                        _sendMessage(imgUrl: url);
                      });
                    });
                  }),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration:
                    InputDecoration.collapsed(hintText: "Enviar uma mensagem"),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: (text) {
                  _handleSubmitted(text);
                  _reset();
                },
              ),
            ),
            Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton(
                        child: Text("Enviar"),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmitted(_textController.text);
                                _reset();
                              }
                            : null,
                      )
                    : IconButton(
                        icon: Icon(Icons.send),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmitted(_textController.text);
                                _reset();
                              }
                            : null,
                      ))
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final Map<String, dynamic> data;

  ChatMessage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(data["senderPhotoURL"]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(data["senderName"],
                    style: Theme.of(context).textTheme.subhead),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  /*
                  child: data["imgUrl"] != null
                      ? Image.network(
                          data["imgUrl"],
                          width: 250.0,
                        )
                      : Text(data["text"]),
                      */
                  child: data["imgUrl"] != null
                      ? CachedNetworkImage(imageUrl: data["imgUrl"], width: 250.0, placeholder: new CircularProgressIndicator(),)
                      : Text(data["text"]),
                  
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
