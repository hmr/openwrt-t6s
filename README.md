# openwrt-t6s
OpenWrt protocol for Transix's static IPv4 address connection.

## Usage

### Install dependent packages
- bash(sorry but some debug feature needs true bash functionality)

Dependencies below are as same as ds-lite package.
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
OpenWrt で [Transix IPv4接続(固定IP)](https://www.mfeed.ad.jp/transix/staticip/) に接続するためのプロトコルです。

## 使用方法

### 依存パッケージをインストール
- bash(現時点では一部のデバッグ機能に本物のbashが必要です)

以下の依存パッケージは ds-lite と同じです。
- kmod-iptunnel6
- kmod-ip6-tunnel
- resolveip

### ファイルを転送
リポジトリ内のファイルを下記の通りファイルをルータに転送してください。

- `t6s.sh -> /lib/netifd/proto/`
    - 実行権限が必要です
- `t6s.js -> /www/luci-static/resources/protocol/`

### ルータをリブートする
転送と権限が正しければ、LuCIの `Network` -> `Interfaces` -> `Add new interface` -> `Protocol` プルダウンに **Transix Static IPv4(t6s)** があります。
