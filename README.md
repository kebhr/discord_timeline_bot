# discord_timeline_bot

## Dependencies

- cpanminus
- Carton
- openssl
    - If you're using **Debian**, please run `apt install libssl-dev`

## Installation

```bash
$ carton install
$ cp app.conf.example app.conf
$ nano app.conf                 # set token and webhook url
```

## Launch

```bash
$ perl ./main.pl
```