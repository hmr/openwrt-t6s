# openwrt-t6s

OpenWrt protocol for Transix's static IPv4 address connection.

This package enables to configure, connect, disconnect Transix static IPv4 connection service on LuCI.

## Usage

### Install dependent packages

Dependencies below are as same as ds-lite package which you may need too.

- kmod-iptunnel6
- kmod-ip6-tunnel
- resolveip

### Transfer files

Copy the files in repository following the guide below:

- `t6s.sh -> /lib/netifd/proto/`
    - needs execute permission
- `t6s.js -> /www/luci-static/resources/protocol/`

### Restart the device

You will find **Transix Static IPv4(t6s)** at `Network` -> `Interfaces` -> `Add new interface` -> `Protocol` pulldown.

# openwrt-t6s

OpenWrtで[Transix IPv4接続(固定IP)](https://www.mfeed.ad.jp/transix/staticip/) を利用可能にするファイルです。

このパッケージによりLuCI上でTransix IPv4接続(固定IP)の設定、接続、切断が行えます。

## 使用方法

### 依存パッケージをインストール

以下の依存パッケージは ds-lite と同じです。

- kmod-iptunnel6
- kmod-ip6-tunnel
- resolveip

### ファイルを転送

リポジトリ内のファイルを下記の通りルータに転送してください。

- `t6s.sh -> /lib/netifd/proto/`
    - 実行権限が必要です
- `t6s.js -> /www/luci-static/resources/protocol/`

### ルータをリブートする

転送と権限が正しければ、LuCIの `Network` -> `Interfaces` -> `Add new interface` -> `Protocol` プルダウンに **Transix Static IPv4(t6s)** があります。
