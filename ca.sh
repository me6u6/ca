#!/bin/sh
mkdir -p CA
cd CA/

# https://users.rust-lang.org/t/use-tokio-tungstenite-with-rustls-instead-of-native-tls-for-secure-websockets/90130
# https://dev.to/anshulgoyal15/a-beginners-guide-to-grpc-with-rust-3c7o
# https://stackoverflow.com/questions/76049656/unexpected-notvalidforname-with-rusts-tonic-with-tls

cat <<'EOF' >> server.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
EOF

#1. 認証局の準備
#1.1. 認証局(CA)の秘密鍵 my_ca.key を作成
openssl genpkey -out my_ca.key -algorithm ED25519
# openssl genrsa -out my_ca.key 2048

#1.2. 認証局の秘密鍵 my_ca.key を使い、ルート証明書（自己署名証明書）my_ca.pem を発行
openssl req -x509 -new -days 365 -nodes -key my_ca.key -out my_ca.pem
# openssl req -x509 -new -nodes -key my_ca.key -sha256 -days 1825 -out my_ca.pem

#2. サーバー証明書の準備
#2.1. サーバーの秘密鍵 server.key を作成
openssl genpkey -out server.key -algorithm ED25519
# openssl genrsa -out server.key 2048

#2.2. サーバーの秘密鍵 server.key を使い、証明書署名要求 server.crt を発行
openssl req -new -key server.key -out server.csr
# openssl req -new -sha256 -key server.key -out server.csr

#2.3. 今回は中間認証局ではなくルート認証局に直接証明書の発行を依頼するとします。
#    ルート認証局が "証明書署名要求 server.csr" と "認証局の自己署名証明書 my_ca.pem" "認証局の秘密鍵 my_ca.key"を使い、サーバー証明書を発行します。
openssl x509 -req -in server.csr -CA my_ca.pem -CAkey my_ca.key -CAcreateserial -out server.pem -days 365 -ED25519 -extfile server.ext
# openssl x509 -req -in server.csr -CA my_ca.pem -CAkey my_ca.key -CAcreateserial -out server.pem -days 1825 -sha256 -extfile server.ext

#3. クライアント証明書の準備
openssl genpkey -out client.key -algorithm ED25519
openssl req -new -key client.key -out client.csr
openssl x509 -req -in client.csr -CA my_ca.pem -CAkey my_ca.key -CAcreateserial -out client.pem -days 365 -ED25519 -extfile server.ext
# openssl genrsa -out client.key 2048
# openssl req -new -sha256 -key client.key -out client.csr
# openssl x509 -req -in client.csr -CA my_ca.pem -CAkey my_ca.key -CAcreateserial -out client.pem -days 1825 -sha256 -extfile server.ext

# ※. ルート証明書 my_ca.pem の内容をテキストで表示
# openssl x509 -in my_ca.pem -noout -text

# ※. 証明書のIssuerとSubjectと有効期間を表示
# openssl x509 -noout -issuer -subject -dates -in my_ca.pem