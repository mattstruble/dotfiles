"""Kitten for smart-splits.nvim integration with kitty.

When invoked, checks if the active kitty window is running neovim.
If so, sends the corresponding Ctrl+<key> to neovim so smart-splits
can handle cross-boundary navigation. If not running neovim, uses
kitty's native neighboring window navigation.

Based on: https://github.com/mrjones2014/smart-splits.nvim#kitty
"""

import re
import sys

from kittens.tui.handler import result_handler
from kitty.key_encoding import KeyEvent, parse_shortcut


def is_window_vim(window, vim_id):
    fp = window.child.foreground_processes
    return any(
        re.search(vim_id, p["cmdline"][0] if len(p["cmdline"]) else "", re.I)
        for p in fp
    )


def encode_key_mapping(window, key_mapping):
    mods, key = parse_shortcut(key_mapping)
    event = KeyEvent(
        mods=mods,
        key=key,
        shift=bool(mods & 1),
        alt=bool(mods & 2),
        ctrl=bool(mods & 4),
        super=bool(mods & 8),
        hyper=bool(mods & 16),
        meta=bool(mods & 32),
    ).as_window_system_event()

    return window.encoded_key(event)


def main():
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    direction = args[1]
    key_mapping = args[2] if len(args) > 2 else None
    vim_id = args[3] if len(args) > 3 else "n?vim"

    if is_window_vim(window, vim_id):
        if key_mapping:
            encoded = encode_key_mapping(window, key_mapping)
            window.write_to_child(encoded)
        else:
            # Default ctrl+<direction_key> mappings
            direction_key_map = {
                "left": "h",
                "bottom": "j",
                "top": "k",
                "right": "l",
            }
            key = direction_key_map.get(direction, direction)
            encoded = encode_key_mapping(window, f"ctrl+{key}")
            window.write_to_child(encoded)
    else:
        boss.active_tab.neighboring_window(direction)
