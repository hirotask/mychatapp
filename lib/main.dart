import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';

//ユーザー情報の受け渡しを行うためのProvider
final userProvider = StateProvider((ref) {
  return FirebaseAuth.instance.currentUser;
});

// エラー情報の受け渡しを行うためのProvider
// ※ autoDisposeを付けることで自動的に値をリセットできる
final infoTextProvider = StateProvider.autoDispose((ref) {
  return '';
});

// メールアドレスの受け渡しを行うためのProvider
// ※ autoDisposeを付けることで自動的に値をリセットできます
final emailProvider = StateProvider.autoDispose((ref) {
  return '';
});

// パスワードの受け渡しを行うためのProvider
// ※ autoDisposeを付けることで自動的に値をリセットできます
final passwordProvider = StateProvider.autoDispose((ref) {
  return '';
});

// メッセージの受け渡しを行うためのProvider
// ※ autoDisposeを付けることで自動的に値をリセットできます
final messageTextProvider = StateProvider.autoDispose((ref) {
  return '';
});

// StreamProviderを使うことでStreamも扱うことができる
// ※ autoDisposeを付けることで自動的に値をリセットできます
final postsQueryProvider = StreamProvider.autoDispose((ref) {
  return FirebaseFirestore.instance
      .collection('posts')
      .orderBy('date')
      .snapshots();
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Add this

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(
    child: ChatApp(),
  ));
}

class ChatApp extends StatelessWidget {
  const ChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatApp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends ConsumerWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, ScopedReader watch) {
    String infoText = watch(infoTextProvider).state;
    String email = watch(emailProvider).state;
    String password = watch(passwordProvider).state;

    return Scaffold(
      body: Center(
          child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // メールアドレス入力
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'メールアドレス'),
                    onChanged: (String value) {
                      context.read(emailProvider).state = value;
                    },
                  ),
                  // パスワード入力
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'パスワード'),
                    obscureText: true,
                    onChanged: (String value) {
                      context.read(passwordProvider).state = value;
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    // メッセージ表示
                    child: Text(infoText),
                  ),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      child: const Text("ユーザー登録"),
                      onPressed: () async {
                        try {
                          final FirebaseAuth auth = FirebaseAuth.instance;
                          final result =
                              await auth.createUserWithEmailAndPassword(
                                  email: email, password: password);

                          //登録完了時の処理
                          await Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) {
                              return ChatPage(result.user!);
                            }),
                          );
                        } catch (e) {
                          //エラー処理
                          context.read(infoTextProvider).state =
                              "登録に失敗しました：${e.toString()}";
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                      width: double.infinity,
                      child: OutlinedButton(
                        child: const Text("ログイン"),
                        onPressed: () async {
                          try {
                            final FirebaseAuth auth = FirebaseAuth.instance;
                            final result =
                                await auth.signInWithEmailAndPassword(
                                    email: email, password: password);

                            await Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) {
                                return ChatPage(result.user!);
                              }),
                            );
                          } catch (e) {
                            context.read(infoTextProvider).state =
                                "ログインに失敗しました: ${e.toString()}";
                          }
                        },
                      )),
                ],
              ))),
    );
  }
}

class ChatPage extends StatelessWidget {
  ChatPage(this.user);

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チャット'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              //ログアウト処理
              await FirebaseAuth.instance.signOut();

              // ログイン画面に遷移＋チャット画面を破棄
              await Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) {
                  return const LoginPage();
                }),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(8),
            child: Text("ログイン情報: ${user.email}"),
          ),
          Expanded(
            // FutureBuilder
            // 非同期処理の結果を元にWidgetを作れる
            child: StreamBuilder<QuerySnapshot>(
              // 投稿メッセージ一覧を取得（非同期処理）
              // 投稿日時でソート

              stream: FirebaseFirestore.instance
                  .collection("posts")
                  .orderBy("date")
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final List<DocumentSnapshot> documents = snapshot.data!.docs;
                  // 取得した投稿メッセージ一覧を元にリスト表示
                  return ListView(
                    children: documents.map((document) {
                      return Card(
                        child: ListTile(
                          title: Text(document["text"]),
                          subtitle: Text(document["email"]),
                          trailing: document["email"] == user.email
                              ? IconButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection("posts")
                                        .doc(document.id)
                                        .delete();
                                  },
                                  icon: Icon(Icons.delete))
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                }
                return const Center(
                  child: Text("読込中..."),
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          // 投稿画面に遷移
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) {
              return AddPostPage(user);
            }),
          );
        },
      ),
    );
  }
}

class AddPostPage extends StatefulWidget {
  const AddPostPage(this.user);

  final User user;

  @override
  _AddPostPageState createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  String messageText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チャット投稿'),
      ),
      body: Center(
        child: Container(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextFormField(
                  decoration: const InputDecoration(labelText: "投稿メッセージ"),
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  onChanged: (String value) {
                    setState(() {
                      messageText = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      child: Text("投稿"),
                      onPressed: () async {
                        final date = DateTime.now().toIso8601String();
                        final email = widget.user.email;

                        await FirebaseFirestore.instance
                            .collection("posts")
                            .doc()
                            .set({
                          "text": messageText,
                          "email": email,
                          "date": date
                        });

                        Navigator.of(context).pop();
                      },
                    ))
              ],
            )),
      ),
    );
  }
}
