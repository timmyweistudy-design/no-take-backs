#!/usr/bin/env python3
"""音效試聽表（第十輪）的產生方式記錄：掃 game/audio/*.wav，輸出 docs/playtest/listen.html。
目前的頁面已經產生好；新增音效後要更新時，照 listen.html 的格式重新產生。"""
import glob, os
print(len(glob.glob(os.path.join(os.path.dirname(__file__), "..", "..", "audio", "*.wav"))), "個音效檔")
