#!/usr/bin/env python3
"""Builds a luacheck standard library from the WoW Forever UI source.

    forever_std.py <AddOns directory> <output dir>

<AddOns directory> is Interface/AddOns of a checkout of the Forever UI source (the "forever" branch of
Gethe/wow-ui-source). Writes into <output dir>:

    forever_std.lua     luacheck std (read_globals); C_* namespaces and Enum with their exact fields
    forever_events.txt  every event name of the API documentation, one per line
    forever_methods.txt every widget/mixin method name found in the UI source, one per line
    forever_atlases.txt every texture atlas name that the loaded UI files mention, one per line

What it does:
 1. Reads all .toc files and works out which files game type "camelot" (WoW Forever) really loads
    ([Family] = Mainline, [Game] = Camelot, [AllowLoadGameType ...] / [ExcludeLoadGameType ...]),
    following <Include>/<Script> in the .xml files.
 2. Runs luacheck over exactly those files - and over the Lua code embedded in the XML scripts of the loaded
    XML files (OnClick, OnLoad, ...) - and collects the globals that Blizzard code sets or reads.
 3. Reads the API documentation (namespaces, functions, events, enumerations).
 4. Writes the std. Documented namespaces and Enum are strict (a misspelled function is an error).
    A few Lua-defined tables (Settings, TooltipUtil, ...) are strict one level deep. Everything else
    that exists only as a name (frames, templates, GlobalStrings) accepts any field.
"""
import html
import os
import re
import subprocess
import sys
from collections import defaultdict

GAME = "camelot"
FAMILY_DIR = "Mainline"
GAME_DIR = "Camelot"
FAMILY_NAMES = {"mainline"}          # game types whose files camelot includes

# Lua-defined tables whose first-level fields are checked
STRICT_TABLES = ["Settings", "TooltipUtil", "TooltipDataProcessor", "MenuUtil", "SettingsPanel"]


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def matches(types):
    names = {t.strip().lower() for t in re.split(r"[,\s]+", types) if t.strip()}
    return GAME in names or bool(names & FAMILY_NAMES)


def toc_info(path):
    meta, files = {}, []
    for raw in read(path).splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("##"):
            m = re.match(r"##\s*([A-Za-z0-9_-]+)\s*:?\s*(.*)", line)
            if m:
                meta[m.group(1)] = m.group(2).strip()
            continue
        if line.startswith("#"):
            continue
        # [Family] and [Game] are part of the path, the other brackets are load conditions
        line = line.replace("[Family]", FAMILY_DIR).replace("[Game]", GAME_DIR)
        directives = re.findall(r"\[([A-Za-z]+)([^\]]*)\]", line)
        entry = re.sub(r"\s*\[[^\]]*\]", "", line).strip()
        files.append((entry, directives))
    return meta, files


def addon_loads(meta):
    allow = meta.get("AllowLoadGameType")
    if allow and not matches(allow):
        return False
    exclude = meta.get("ExcludeLoadGameType")
    if exclude and GAME in {t.strip().lower() for t in re.split(r"[,\s]+", exclude)}:
        return False
    return meta.get("AllowLoad", "Both").lower() in ("game", "both")


def file_loads(directives):
    allow = None
    for name, args in directives:
        if name == "AllowLoadGameType":
            allow = matches(args) if allow is None else (allow or matches(args))
        elif name == "ExcludeLoadGameType":
            if GAME in {t.strip().lower() for t in re.split(r"[,\s]+", args) if t.strip()}:
                return False
    return True if allow is None else allow


def resolve(path):
    return path.replace("\\", "/").replace("[Family]", FAMILY_DIR).replace("[Game]", GAME_DIR)


def collect_loaded(root):
    lua, xml_seen = [], set()

    def add_xml(path, seen):
        if path in seen or not os.path.exists(path):
            return
        seen.add(path)
        base = os.path.dirname(path)
        for m in re.finditer(r"<(?:Script|Include)\s+file=\"([^\"]+)\"", read(path)):
            sub = os.path.normpath(os.path.join(base, m.group(1).replace("\\", "/")))
            if sub.endswith(".lua"):
                if os.path.exists(sub):
                    lua.append(sub)
            elif sub.endswith(".xml"):
                add_xml(sub, seen)

    addons = []
    for addon in sorted(os.listdir(root)):
        d = os.path.join(root, addon)
        toc = os.path.join(d, addon + ".toc")
        if not os.path.isfile(toc):
            continue
        meta, files = toc_info(toc)
        if not addon_loads(meta):
            continue
        addons.append(addon)
        for entry, directives in files:
            if not file_loads(directives):
                continue
            p = os.path.normpath(os.path.join(d, resolve(entry)))
            if p.endswith(".lua") and os.path.exists(p):
                lua.append(p)
            elif p.endswith(".xml"):
                add_xml(p, xml_seen)
    seen, out = set(), []
    for p in lua:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return addons, out, xml_seen


# not self-closing (<OnLoad method="..."/> has no code): the tag must not end in "/>"
SCRIPT_BLOCK = re.compile(r"<(On[A-Za-z]+|PreClick|PostClick|Script)(?:\s[^>]*?)?(?<!/)>(.*?)</\1>", re.S)


def extract_xml_scripts(xml_files, outdir):
    """Lua code that sits inside XML script elements, written to .lua files so that luacheck can read it."""
    folder = os.path.join(outdir, "xmlscripts")
    os.makedirs(folder, exist_ok=True)
    for old in os.listdir(folder):
        os.remove(os.path.join(folder, old))
    out = []
    for i, path in enumerate(sorted(xml_files)):
        parts = []
        for m in SCRIPT_BLOCK.finditer(read(path)):
            body = html.unescape(m.group(2)).strip()
            if body.startswith("<![CDATA["):
                body = body[len("<![CDATA["):]
                if body.endswith("]]>"):
                    body = body[:-3]
            if body.strip():
                parts.append("local function f(self, ...)\n%s\nend\n" % body)
        if parts:
            target = os.path.join(folder, "x%05d.lua" % i)
            with open(target, "w", encoding="utf-8") as f:
                f.write("\n".join(parts))
            out.append(target)
    return out


def run_luacheck(files):
    out = []
    for i in range(0, len(files), 400):
        r = subprocess.run(["luacheck", "--no-config", "--std", "lua51", "--codes", "--formatter", "plain",
                            "--no-color", "-j", "4", "--only", "111", "112", "113", "--"] + files[i:i + 400],
                           capture_output=True, text=True)
        out.append(r.stdout)
    return "\n".join(out)


def parse_luacheck(text):
    set_g, read_g = set(), set()
    for m in re.finditer(r"\((W11[123])\) (?:setting|mutating|accessing)[^']*'([^']+)'", text):
        (set_g if m.group(1) in ("W111", "W112") else read_g).add(m.group(2))
    return set_g, read_g


def parse_docs(docdir):
    namespaces = defaultdict(set)
    globals_, events, enums = set(), set(), {}
    for fn in sorted(os.listdir(docdir)):
        if not fn.endswith("Documentation.lua"):
            continue
        text = read(os.path.join(docdir, fn))
        ns = re.search(r"^\s*Namespace = \"([^\"]+)\"", text, re.M)
        ns = ns.group(1) if ns else None
        for m in re.finditer(r"Name = \"([A-Za-z0-9_]+)\",\s*Type = \"Function\"", text):
            (namespaces[ns].add(m.group(1)) if ns else globals_.add(m.group(1)))
        for m in re.finditer(r"LiteralName = \"([A-Z0-9_]+)\"", text):
            events.add(m.group(1))
        for m in re.finditer(r"Name = \"([A-Za-z0-9_]+)\",\s*Type = \"Enumeration\".*?Fields =\s*\{(.*?)\n\t\t\t\},", text, re.S):
            fields = re.findall(r"Name = \"([A-Za-z0-9_]+)\", Type = \"[A-Za-z0-9_]+\", EnumValue", m.group(2))
            enums.setdefault(m.group(1), set()).update(fields)
    return namespaces, globals_, events, enums


def doc_methods(docdir):
    """Widget methods are documented as functions of the systems whose objects are frames."""
    names = set()
    for fn in os.listdir(docdir):
        if fn.endswith("Documentation.lua"):
            names.update(re.findall(r"Name = \"([A-Za-z0-9_]+)\",\s*Type = \"Function\"", read(os.path.join(docdir, fn))))
    return names


def lua_methods(files):
    """Methods defined in Lua (mixins) and every method the Blizzard code itself calls with ":" -
    a method the shipped UI calls exists in the client even if the API documentation omits it."""
    names = set()
    for p in files:
        text = read(p)
        names.update(re.findall(r"function\s+[A-Za-z_][\w.]*:([A-Za-z_]\w*)\s*\(", text))
        names.update(re.findall(r"^\s*[A-Za-z_][\w.]*\.([A-Za-z_]\w*)\s*=\s*function", text, re.M))
        names.update(re.findall(r":([A-Za-z_]\w*)\s*[({\"']", text))
    return names


def atlas_names(files, xml_files):
    names = set()
    kebab = re.compile(r"^[A-Za-z0-9_]+(?:-[A-Za-z0-9_]+)+$")
    for p in files:
        for s in re.findall(r"\"([^\"\n]{3,80})\"", read(p)):
            if kebab.match(s):
                names.add(s)
    for p in xml_files:
        names.update(re.findall(r"atlas=\"([^\"]+)\"", read(p)))
    return names


def strict_fields(files):
    fields = {t: set() for t in STRICT_TABLES}
    for p in files:
        text = read(p)
        for g, f in re.findall(r"^\s*function\s+([A-Za-z_]\w*)\.([A-Za-z_]\w*)", text, re.M):
            if g in fields:
                fields[g].add(f)
        for g, f in re.findall(r"^\s*([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*=", text, re.M):
            if g in fields:
                fields[g].add(f)
    return fields


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    root = os.path.abspath(sys.argv[1])
    outdir = os.path.abspath(sys.argv[2])
    os.makedirs(outdir, exist_ok=True)

    addons, files, xml_files = collect_loaded(root)
    print("addons camelot loads: %d   Lua files: %d   XML files: %d" % (len(addons), len(files), len(xml_files)))

    scripts = extract_xml_scripts(xml_files, outdir)
    print("XML files with embedded scripts: %d" % len(scripts))
    set_g, read_g = parse_luacheck(run_luacheck(files + scripts))
    print("globals set by Blizzard code: %d   read but never set: %d" % (len(set_g), len(read_g)))

    xml_names = set()
    for p in xml_files:
        xml_names.update(re.findall(r"\bname=\"([A-Za-z_][A-Za-z0-9_]*)\"", read(p)))

    docdir = os.path.join(root, "Blizzard_APIDocumentationGenerated")
    namespaces, doc_globals, events, enums = parse_docs(docdir)
    ns_names = {k for k in namespaces if k}
    print("namespaces: %d   documented global functions: %d   enumerations: %d   events: %d"
          % (len(ns_names), len(doc_globals), len(enums), len(events)))

    names = (set_g | read_g | xml_names | doc_globals) - ns_names - {"Enum"}
    names = {n for n in names if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", n)}
    strict = strict_fields(files)

    lines = ["-- Generated by forever_std.py from the Forever UI source. Do not edit.", "return {", "  read_globals = {"]
    for n in sorted(names):
        if n in strict and strict[n]:
            lines.append("    %s = { other_fields = false, fields = {" % n)
            for f in sorted(strict[n]):
                lines.append("      %s = { other_fields = true }," % f)
            lines.append("    } },")
        else:
            lines.append("    %s = { other_fields = true }," % n)
    for ns in sorted(ns_names):
        lines.append("    %s = { fields = {" % ns)
        for f in sorted(namespaces[ns]):
            lines.append("      %s = {}," % f)
        lines.append("    } },")
    lines.append("    Enum = { fields = {")
    for en in sorted(enums):
        lines.append("      %s = { fields = {" % en)
        for f in sorted(enums[en]):
            lines.append("        %s = {}," % f)
        lines.append("      } },")
    lines.append("    } },")
    lines.append("  },")
    lines.append("}")
    with open(os.path.join(outdir, "forever_std.lua"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    with open(os.path.join(outdir, "forever_events.txt"), "w") as f:
        f.write("\n".join(sorted(events)) + "\n")
    with open(os.path.join(outdir, "forever_atlases.txt"), "w") as f:
        f.write("\n".join(sorted(atlas_names(files, xml_files))) + "\n")
    with open(os.path.join(outdir, "forever_methods.txt"), "w") as f:
        f.write("\n".join(sorted(doc_methods(docdir) | lua_methods(files))) + "\n")
    print("written to", outdir)


if __name__ == "__main__":
    main()
