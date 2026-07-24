#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
本地预览 Godot Web 导出产物（带 COOP/COEP 跨域隔离头）。
用法:
  python tools/serve_web.py            # 默认 build/web, 端口 8060
  python tools/serve_web.py --port 9000 --dir build/web
浏览器打开 http://127.0.0.1:8060/
"""
from __future__ import annotations

import argparse
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class COOPHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--dir", default="build/web")
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args()

    root = os.path.abspath(args.dir)
    os.chdir(root)
    server = ThreadingHTTPServer((args.host, args.port), COOPHandler)
    print(f"预览服务器: http://{args.host}:{args.port}/   目录={root}")
    print("已带 COOP/COEP 头（Godot 4 多线程 Web 必需）。Ctrl+C 停止。")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止")
        server.server_close()


if __name__ == "__main__":
    main()
