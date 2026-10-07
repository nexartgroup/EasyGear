#!/usr/bin/env python3
"""Offline tests for EasyGear.

Runs the addon under real Lua 5.1 (via the `lupa` package) against a small WoW API
stub (tests/wow_stub.lua) and checks the files statically.

    pip install lupa
    python3 tests/run_tests.py            # everything
    python3 tests/run_tests.py -k egup    # only cases whose name contains "egup"

What is covered:
  * static  - ASCII-only code, UTF-8 language files, .toc completeness, language
              keys (used in code / present in enUS / same placeholders / no duplicates)
  * runtime - every .toc file loads in Lua 5.1; the test cases in tests/cases.lua run
              once per language (enUS, deDE, an unsupported one) so that the locale
              fallback is exercised, too.
"""
import os
import re
import sys

try:
    from lupa import lua51
except ImportError:
    sys.exit("lupa is required:  pip install lupa")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "tests")

failures = []
passed = 0


def fail(msg):
    failures.append(msg)
    print("  FAIL", msg)


def ok(n=1):
    global passed
    passed += n


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def toc_files():
    files = []
    for line in read(os.path.join(ROOT, "EasyGear.toc")).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(line.replace("\\", "/"))
    return files


# ----------------------------------------------------------------------------
# static checks
# ----------------------------------------------------------------------------

def static_checks():
    print("static checks")
    files = toc_files()

    # every listed file exists, every addon file is listed
    for f in files:
        if os.path.exists(os.path.join(ROOT, f)):
            ok()
        else:
            fail(f".toc lists a missing file: {f}")
    on_disk = [f for f in os.listdir(ROOT) if f.endswith(".lua")]
    on_disk += ["Locales/" + f for f in os.listdir(os.path.join(ROOT, "Locales")) if f.endswith(".lang.lua")]
    for f in on_disk:
        if f in files:
            ok()
        else:
            fail(f"file is not listed in EasyGear.toc: {f}")

    # code files are pure ASCII (the original project guarantee)
    for f in [f for f in files if not f.endswith(".lang.lua")] + ["EasyGear.toc"]:
        data = open(os.path.join(ROOT, f), "rb").read()
        bad = [i for i, b in enumerate(data) if b > 127]
        if bad:
            fail(f"{f} contains non-ASCII bytes (first at offset {bad[0]})")
        else:
            ok()
        if b"\t" in data:
            fail(f"{f} contains tab characters")
        else:
            ok()

    # language files: UTF-8 without BOM
    for f in [f for f in files if f.endswith(".lang.lua")]:
        data = open(os.path.join(ROOT, f), "rb").read()
        if data.startswith(b"\xef\xbb\xbf"):
            fail(f"{f} has a BOM")
        try:
            data.decode("utf-8")
            ok()
        except UnicodeDecodeError as e:
            fail(f"{f} is not valid UTF-8: {e}")

    locale_checks(files)


def parse_lang(path):
    """Return (dict key->value, [duplicate keys]) from a .lang file via Lua."""
    rt = lua51.LuaRuntime()
    rt.execute("EasyGearLocales = nil")
    rt.execute(read(path))
    tables = rt.eval("EasyGearLocales")
    out = {}
    for code in tables.keys():
        out[code] = {k: v for k, v in tables[code].items()}
    text = read(path)
    keys = re.findall(r"^\s*([A-Z][A-Z0-9_]*)\s*=", text, re.M)
    dups = sorted({k for k in keys if keys.count(k) > 1})
    return out, dups


PLACEHOLDER = re.compile(r"%(?:%|[sd])")


def placeholders(s):
    return [p for p in PLACEHOLDER.findall(s) if p != "%%"]


def locale_checks(files):
    print("language files")
    langs = {}
    for f in [f for f in files if f.endswith(".lang.lua")]:
        parsed, dups = parse_lang(os.path.join(ROOT, f))
        code = os.path.basename(f)[:-len(".lang.lua")]
        if code not in parsed:
            fail(f"{f} does not register EasyGearLocales[\"{code}\"]")
            continue
        if len(parsed) != 1:
            fail(f"{f} registers more than one locale: {list(parsed)}")
        langs[code] = parsed[code]
        if dups:
            fail(f"{f} has duplicate keys: {dups}")
        else:
            ok()

    base = langs.get("enUS")
    if not base:
        fail("enUS.lang.lua missing")
        return

    # keys used by the code
    used = set()
    for f in os.listdir(ROOT):
        if f.endswith(".lua"):
            src = read(os.path.join(ROOT, f))
            used |= set(re.findall(r"\bL\.([A-Z][A-Z0-9_]+)", src))
            used |= set(re.findall(r'"(H_[A-Z_]+)"', src))
    for k in sorted(used):
        if k in base:
            ok()
        else:
            fail(f"enUS.lang.lua lacks key {k} used by the code")

    # subtype names for every token
    tokens = ["CLOTH", "LEATHER", "MAIL", "PLATE", "SHIELD", "LIBRAM", "IDOL", "TOTEM", "SIGIL", "MISC",
              "AXE1", "AXE2", "MACE1", "MACE2", "SWORD1", "SWORD2", "DAGGER", "FIST", "POLEARM",
              "STAFF", "BOW", "GUN", "CROSSBOW", "WAND", "THROWN", "FISHING"]
    for t in tokens:
        if "SUBTYPE_" + t in base:
            ok()
        else:
            fail(f"enUS.lang.lua lacks SUBTYPE_{t}")

    # unused keys (information only)
    spec_or_sub = lambda k: k.startswith("SPEC_") or k.startswith("SUBTYPE_")
    unused = sorted(k for k in base if k not in used and not spec_or_sub(k))
    if unused:
        print("  note: enUS keys not referenced by the code:", ", ".join(unused))

    for code, table in langs.items():
        if code == "enUS":
            continue
        for k, v in table.items():
            if k not in base:
                fail(f"{code}.lang.lua has key {k} that enUS.lang.lua does not")
                continue
            if placeholders(v) != placeholders(base[k]):
                fail(f"{code}.lang.lua {k}: placeholders {placeholders(v)} differ from enUS {placeholders(base[k])}")
            elif v.count("|c") != v.count("|r") + 0 and "|c" in v:
                fail(f"{code}.lang.lua {k}: unbalanced colour codes")
            else:
                ok()
        missing = [k for k in base if k not in table]
        pct = 100 * (len(base) - len(missing)) / len(base)
        print(f"  {code}: {len(table)} keys, {pct:.0f}% of enUS")

    # every placeholder string in enUS is itself sane
    for k, v in base.items():
        if "\n" in v and k != "DROP_HINT":
            fail(f"enUS {k} contains a line break")
        else:
            ok()


# ----------------------------------------------------------------------------
# runtime
# ----------------------------------------------------------------------------

RUN_CASE = r"""
function RunCase(name)
    T.failures = {}
    local before = T.checks
    local ok, err = xpcall(Cases[name], function(e) return debug.traceback(tostring(e), 2) end)
    return ok, err, T.failures, T.checks - before
end
function CaseNames()
    local names = {}
    for k in pairs(Cases) do names[#names + 1] = k end
    table.sort(names)
    return names
end
"""


def load_addon(rt, locale):
    rt.execute(read(os.path.join(TESTS, "wow_stub.lua")))
    rt.execute('T.reset({locale="%s"})' % locale)
    loader = rt.eval("function(src, name) local f, e = loadstring(src, name); if not f then error(e) end; f() end")
    for f in toc_files():
        try:
            loader(read(os.path.join(ROOT, f)), "@" + f)
        except Exception as e:  # lupa.LuaError
            raise RuntimeError(f"loading {f}: {e}")
    rt.execute('T.fire("ADDON_LOADED", "EasyGear"); T.fire("PLAYER_LOGIN")')
    loader(read(os.path.join(TESTS, "cases.lua")), "@tests/cases.lua")
    rt.execute(RUN_CASE)


ALIAS = {"enGB": "enUS", "esMX": "esES"}


def runtime_checks(only):
    global passed
    codes = sorted(f[:-len(".lang.lua")] for f in os.listdir(os.path.join(ROOT, "Locales")) if f.endswith(".lang.lua"))
    # every language file, the two client aliases and one unsupported language
    for locale in codes + ["enGB", "esMX", "itIT"]:
        if only and locale not in ("enUS", "deDE", "itIT"):
            continue
        print(f"runtime ({locale})")
        rt = lua51.LuaRuntime(unpack_returned_tuples=True)
        try:
            load_addon(rt, locale)
        except Exception as e:
            fail(f"[{locale}] {e}")
            continue

        # language selection itself
        probe = rt.eval("function() return EasyGear.L.UPGRADE, EasyGear.L.R_LEVEL, EasyGear.locale.active, EasyGear.locale.translated end")
        upgrade, rlevel, active, translated = probe()
        expect_active = ALIAS.get(locale, locale if locale in codes else "enUS")
        expect_translated = expect_active != "enUS"
        base = {}
        if locale == "deDE":
            base["VERBESSERUNG"] = upgrade == "VERBESSERUNG"
        if expect_active == "enUS":
            base["English UPGRADE"] = upgrade == "UPGRADE"
        checks = [(active == expect_active, f"active language file {active} (expected {expect_active})"),
                  (bool(translated) == expect_translated, f"translated flag {translated} (expected {expect_translated})"),
                  ("%d" in rlevel, "R_LEVEL keeps its placeholder")]
        checks += [(good, what) for what, good in base.items()]
        for good, what in checks:
            if good:
                ok()
            else:
                fail(f"[{locale}] {what}")

        names = list(rt.eval("CaseNames()").values())
        names.sort(key=lambda n: (n != "load", n))
        run_case = rt.globals().RunCase
        for name in names:
            if only and only not in name:
                continue
            success, err, fails, checks_n = run_case(name)
            if not success:
                fail(f"[{locale}] {name}: error {str(err).splitlines()[0]}")
                for line in str(err).splitlines()[1:6]:
                    print("        " + line)
            elif len(fails) > 0:
                for m in fails.values():
                    fail(f"[{locale}] {name}: {m}")
            else:
                ok(checks_n)


def main():
    only = None
    if "-k" in sys.argv:
        only = sys.argv[sys.argv.index("-k") + 1]
    if not only:
        static_checks()
    runtime_checks(only)
    print()
    print(f"{passed} checks passed, {len(failures)} failed")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
