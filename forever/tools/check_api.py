#!/usr/bin/env python3
"""Checks the addon's use of the client API against the lists tools/forever_std.py builds.

    check_api.py [cache dir]        (default: .cache)

 * every event name the addon registers must exist in the API documentation;
 * every method called with ":" (frames, textures, tooltips, menu descriptions, ...) must exist somewhere in
   the Forever UI source (documented widget API, mixins) or in the addon itself, or be a Lua string method.

 * names the addon reaches through _G, hooksecurefunc and Hook(...) must be globals of the UI source;
 * templates, fonts and texture atlases the addon names must exist in the UI source.

Exit code 1 on any finding.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ADDON = os.path.join(ROOT, "EasyGear")
cache = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".cache")

events = set(open(os.path.join(cache, "forever_events.txt")).read().split())
methods = set(open(os.path.join(cache, "forever_methods.txt")).read().split())
atlases = set(open(os.path.join(cache, "forever_atlases.txt")).read().split())
std_text = open(os.path.join(cache, "forever_std.lua"), encoding="utf-8").read()
ui_globals = set(re.findall(r"^    ([A-Za-z_]\w*) = ", std_text, re.M))
# GlobalStrings of the client that the UI source never mentions (the addon only reads them, guarded)
CLIENT_STRINGS = {
    "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONPROC",
    "ITEM_UNIQUE", "ITEM_UNIQUE_EQUIPPABLE", "ITEM_MIN_LEVEL", "ITEM_SOCKET_BONUS",
    "DPS_TEMPLATE", "SPELL_STATALL",
}
# what the addon defines itself (see .luacheckrc)
OWN_GLOBALS = {"EasyGear", "EasyGearDB", "EasyGearCharDB", "EasyGearLocales"}
OWN_PREFIXES = ("SLASH_EASYGEAR", "EasyGear_")

STRING_METHODS = {"find", "format", "gmatch", "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper", "byte"}
# Methods of Lua tables from the standard library or of objects that are not UI objects
OTHER = set()

lua_files = []
for dirpath, _, names in os.walk(ADDON):
    for n in names:
        if n.endswith(".lua") and "Locales" not in dirpath:
            lua_files.append(os.path.join(dirpath, n))

own = set()
for p in lua_files:
    text = open(p, encoding="utf-8").read()
    own.update(re.findall(r"function\s+[A-Za-z_][\w.]*[:.]([A-Za-z_]\w*)\s*\(", text))
    own.update(re.findall(r"^\s*[A-Za-z_][\w.]*\.([A-Za-z_]\w*)\s*=\s*function", text, re.M))

bad = []
for p in sorted(lua_files):
    rel = os.path.relpath(p, ROOT)
    text = open(p, encoding="utf-8").read()
    # drop comments and long strings roughly so that prose does not count
    code = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    code = re.sub(r"--[^\n]*", "", code)
    for lineno, line in enumerate(code.split("\n"), 1):
        # events: EG:On("X", ...), :RegisterEvent("X"), RegisterUnitEvent
        for m in re.finditer(r"(?:EG:On|:RegisterEvent|:RegisterUnitEvent)\(\s*\"([A-Z0-9_]+)\"", line):
            if m.group(1) not in events:
                bad.append("%s:%d: unknown event %s" % (rel, lineno, m.group(1)))
        for m in re.finditer(r"_G\.([A-Za-z_]\w*)|_G\[\"([A-Za-z_]\w*)\"\]", line):
            name = m.group(1) or m.group(2)
            if (name not in ui_globals and name not in OWN_GLOBALS and name not in CLIENT_STRINGS
                    and not name.startswith(OWN_PREFIXES)):
                bad.append("%s:%d: _G.%s is not a global of the UI source" % (rel, lineno, name))
        for m in re.finditer(r"hooksecurefunc\(\s*\"([A-Za-z_]\w*)\"|\bHook\(\s*\"[^\"]*\",\s*\"([A-Za-z_]\w*)\"", line):
            name = m.group(1) or m.group(2)
            if name not in ui_globals:
                bad.append("%s:%d: hook target %s is not a global of the UI source" % (rel, lineno, name))
        for m in re.finditer(r"\"((?:Game|System|Number|Friz|Quest|Tooltip)[A-Za-z]*Font[A-Za-z0-9]*|[A-Z][A-Za-z0-9]*Template)\"", line):
            if m.group(1) not in ui_globals:
                bad.append("%s:%d: template or font %s is not in the UI source" % (rel, lineno, m.group(1)))
        for m in re.finditer(r"\"([a-z0-9_]+(?:-[a-z0-9_]+)+)\"", line):
            if m.group(1) not in atlases:
                bad.append("%s:%d: atlas %s is not in the UI source" % (rel, lineno, m.group(1)))
        for m in re.finditer(r":([A-Za-z_]\w*)\s*[({\"']", line):
            name = m.group(1)
            if name in STRING_METHODS or name in own or name in methods or name in OTHER:
                continue
            bad.append("%s:%d: unknown method :%s" % (rel, lineno, name))

if bad:
    print("\n".join(bad))
    print("%d finding(s)" % len(bad))
    sys.exit(1)
print("API check: %d files, no unknown events or methods" % len(lua_files))
