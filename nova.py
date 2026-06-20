#!/usr/bin/env python3
"""
Nova — a lightweight AI assistant for a-Shell on iOS.
Uses only Python standard library + requests.
"""

import json
import os
import sys
import textwrap
import datetime

try:
    import requests
except ImportError:
    print("Error: 'requests' is required. Run: pip install requests")
    sys.exit(1)

# ── Paths ────────────────────────────────────────────────────────────────────

HOME = os.path.expanduser("~")
CONFIG_PATH = os.path.join(HOME, ".nova_config.json")
HISTORY_PATH = os.path.join(HOME, ".nova_history.json")

# ── Defaults ─────────────────────────────────────────────────────────────────

TERMINAL_WIDTH = 60  # comfortable on an iPhone screen

DEFAULT_CONFIG = {
    "api_key": "",
    "api_url": "https://api.anthropic.com/v1/messages",
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
}

MODES = {
    "chat": {
        "label": "General Chat",
        "system": (
            "You are Nova, a friendly and concise AI assistant. "
            "Keep responses short and clear — the user is on a small iPhone screen."
        ),
    },
    "coding": {
        "label": "Coding Help",
        "system": (
            "You are Nova, an expert programming assistant. "
            "Provide clean, well-explained code. "
            "Use short code blocks. Assume the user is on a small screen — "
            "keep prose brief and code tightly formatted."
        ),
    },
    "notes": {
        "label": "Quick Notes",
        "system": (
            "You are Nova, a note-taking assistant. "
            "Help the user capture, organise, and recall ideas. "
            "Be brief and bullet-point-friendly."
        ),
    },
}

# ── Config ───────────────────────────────────────────────────────────────────

def load_config():
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH) as f:
            cfg = json.load(f)
        # fill in any missing keys from defaults
        for k, v in DEFAULT_CONFIG.items():
            cfg.setdefault(k, v)
        return cfg
    return dict(DEFAULT_CONFIG)


def save_config(cfg):
    with open(CONFIG_PATH, "w") as f:
        json.dump(cfg, f, indent=2)


def setup_wizard(cfg):
    print(wrap("Welcome to Nova! Let's set up your API key."))
    print()
    key = input("Anthropic API key: ").strip()
    if key:
        cfg["api_key"] = key
    model = input(f"Model [{cfg['model']}]: ").strip()
    if model:
        cfg["model"] = model
    save_config(cfg)
    print()
    print(wrap("Config saved to ~/.nova_config.json"))
    print()

# ── History ──────────────────────────────────────────────────────────────────

def load_history():
    if os.path.exists(HISTORY_PATH):
        with open(HISTORY_PATH) as f:
            return json.load(f)
    return []


def save_history(history):
    with open(HISTORY_PATH, "w") as f:
        json.dump(history, f, indent=2)


def clear_history():
    if os.path.exists(HISTORY_PATH):
        os.remove(HISTORY_PATH)

# ── Formatting ────────────────────────────────────────────────────────────────

def wrap(text, width=TERMINAL_WIDTH):
    """Word-wrap a block of text, preserving existing newlines."""
    lines = []
    for paragraph in text.split("\n"):
        if paragraph.strip() == "":
            lines.append("")
        else:
            lines.extend(textwrap.wrap(paragraph, width=width) or [""])
    return "\n".join(lines)


def divider(char="─", width=TERMINAL_WIDTH):
    return char * width


def print_nova(text):
    print()
    print(f"Nova:")
    print(wrap(text))
    print()


def print_error(text):
    print(f"\n[!] {wrap(text)}\n")


def print_info(text):
    print(f"    {wrap(text)}")

# ── API call ─────────────────────────────────────────────────────────────────

def call_api(cfg, messages, system_prompt):
    headers = {
        "x-api-key": cfg["api_key"],
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }
    payload = {
        "model": cfg["model"],
        "max_tokens": cfg["max_tokens"],
        "system": system_prompt,
        "messages": messages,
    }
    try:
        r = requests.post(cfg["api_url"], headers=headers, json=payload, timeout=60)
        r.raise_for_status()
        data = r.json()
        return data["content"][0]["text"]
    except requests.exceptions.ConnectionError:
        return None, "Connection failed. Check your internet connection."
    except requests.exceptions.Timeout:
        return None, "Request timed out."
    except requests.exceptions.HTTPError as e:
        try:
            msg = r.json().get("error", {}).get("message", str(e))
        except Exception:
            msg = str(e)
        return None, f"API error: {msg}"
    except Exception as e:
        return None, f"Unexpected error: {e}"

# ── Commands ──────────────────────────────────────────────────────────────────

def cmd_help():
    print()
    print(divider())
    print("Nova Commands")
    print(divider())
    cmds = [
        ("/help",         "Show this help"),
        ("/mode <name>",  "Switch mode: chat | coding | notes"),
        ("/modes",        "List available modes"),
        ("/clear",        "Clear conversation history"),
        ("/history",      "Show conversation so far"),
        ("/save [file]",  "Export conversation to a text file"),
        ("/config",       "Show current config"),
        ("/key <apikey>", "Update API key"),
        ("/model <id>",   "Change model"),
        ("/quit",         "Exit Nova"),
    ]
    for cmd, desc in cmds:
        left = cmd.ljust(18)
        print(f"  {left}{desc}")
    print(divider())
    print()


def cmd_modes(current_mode):
    print()
    for key, info in MODES.items():
        marker = " *" if key == current_mode else "  "
        print(f"{marker} {key:10}  {info['label']}")
    print()


def cmd_history(history):
    if not history:
        print_info("No conversation history yet.")
        return
    print()
    print(divider())
    for msg in history:
        role = "You" if msg["role"] == "user" else "Nova"
        content = msg["content"]
        print(f"{role}:")
        print(wrap(content))
        print()
    print(divider())
    print()


def cmd_save(history, filename=None):
    if not history:
        print_error("Nothing to save yet.")
        return
    if not filename:
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(HOME, f"nova_conversation_{ts}.txt")
    else:
        if not os.path.isabs(filename):
            filename = os.path.join(HOME, filename)

    lines = [f"Nova Conversation — {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}", ""]
    for msg in history:
        role = "You" if msg["role"] == "user" else "Nova"
        lines.append(f"[{role}]")
        lines.append(msg["content"])
        lines.append("")

    with open(filename, "w") as f:
        f.write("\n".join(lines))
    print_info(f"Saved to: {filename}")


def cmd_config(cfg, current_mode):
    print()
    print(divider())
    print("Current Config")
    print(divider())
    key_display = (cfg["api_key"][:6] + "…") if len(cfg["api_key"]) > 6 else "(not set)"
    print(f"  api_key   : {key_display}")
    print(f"  model     : {cfg['model']}")
    print(f"  max_tokens: {cfg['max_tokens']}")
    print(f"  mode      : {current_mode} ({MODES[current_mode]['label']})")
    print(f"  api_url   : {cfg['api_url']}")
    print(divider())
    print()

# ── Main loop ─────────────────────────────────────────────────────────────────

def main():
    cfg = load_config()

    if not cfg["api_key"]:
        setup_wizard(cfg)

    history = load_history()
    current_mode = "chat"

    print()
    print(divider("═"))
    print("  Nova — AI Assistant  (type /help for commands)")
    print(divider("═"))
    mode_info = MODES[current_mode]
    print(f"  Mode: {mode_info['label']}")
    if history:
        print(f"  Resuming {len(history)//2} previous exchange(s).")
    print(divider("═"))
    print()

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n\nGoodbye!")
            save_history(history)
            break

        if not user_input:
            continue

        # ── Command dispatch ──────────────────────────────────────────────
        if user_input.startswith("/"):
            parts = user_input.split(maxsplit=1)
            cmd = parts[0].lower()
            arg = parts[1] if len(parts) > 1 else ""

            if cmd == "/quit" or cmd == "/exit":
                print("\nGoodbye!")
                save_history(history)
                break

            elif cmd == "/help":
                cmd_help()

            elif cmd == "/modes":
                cmd_modes(current_mode)

            elif cmd == "/mode":
                if arg in MODES:
                    current_mode = arg
                    print_info(f"Mode: {MODES[current_mode]['label']}")
                else:
                    print_error(f"Unknown mode '{arg}'. Try: {', '.join(MODES)}")

            elif cmd == "/clear":
                history = []
                clear_history()
                print_info("History cleared.")

            elif cmd == "/history":
                cmd_history(history)

            elif cmd == "/save":
                cmd_save(history, arg or None)

            elif cmd == "/config":
                cmd_config(cfg, current_mode)

            elif cmd == "/key":
                if arg:
                    cfg["api_key"] = arg
                    save_config(cfg)
                    print_info("API key updated.")
                else:
                    print_error("Usage: /key <your-api-key>")

            elif cmd == "/model":
                if arg:
                    cfg["model"] = arg
                    save_config(cfg)
                    print_info(f"Model set to: {arg}")
                else:
                    print_error("Usage: /model <model-id>")

            else:
                print_error(f"Unknown command '{cmd}'. Type /help.")

            continue

        # ── Normal message ────────────────────────────────────────────────
        history.append({"role": "user", "content": user_input})

        system_prompt = MODES[current_mode]["system"]

        print("  ...")

        result = call_api(cfg, history, system_prompt)

        # call_api returns either a string (success) or a (None, error) tuple
        if isinstance(result, tuple):
            _, error_msg = result
            history.pop()  # don't keep failed turn in history
            print_error(error_msg)
            continue

        assistant_text = result
        history.append({"role": "assistant", "content": assistant_text})
        save_history(history)

        # Clear the "..." line
        print("\033[1A\033[2K", end="")

        print_nova(assistant_text)


if __name__ == "__main__":
    main()
