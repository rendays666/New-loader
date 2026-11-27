#!/usr/bin/env python3
"""
Splitter Infinite Yield
=======================

Membaca file `original/source` (satu file Lua/Luau besar dari
EdgeIY/infiniteyield), lalu memecah setiap pemanggilan:

    addcmd("nama", {"alias1", "alias2"}, function(args, speaker)
        ...
    end)

menjadi satu file modul di `commands/<nama>.lua`.

Selain itu, deklarasi global top-level yang dipakai command (dan
dependensinya) dipindahkan ke `core/`:

    core/globals.lua   core/args.lua
    core/notify.lua    core/waypoint.lua
    core/index.lua     (require semuanya, urutan dependensi)

Cara kerja singkat:
1. Tokenizer membaca source dan "membuang" komentar, tetapi menyimpan
   string (termasuk long string) sebagai satu token. Jadi kata "addcmd"
   di dalam komentar/string tidak ikut terbaca.
2. Parser mencari token `addcmd`, lalu mencocokkan tanda kurung secara
   berimbang (bukan regex).
3. Blok `function ... end` dihitung dengan keyword: function/if/do/repeat
   menambah kedalaman, end/until mengurangi. String dan komentar sudah
   aman karena tokenizer.
4. Setiap command ditulis sebagai modul yang mengembalikan tabel
   { name, aliases, fn }.
5. Deklarasi global top-level (`function NAMA`, `NAMA = function`,
   `NAMA = { ... }`, `NAMA = Instance.new(...)`) dikumpulkan. Hanya yang
   dipakai command/helper yang ditulis ke core/.
6. Dependency scan menulis daftar dependency per command, UNRESOLVED,
   top-level local, dan blok gagal parse ke splitter/report.txt.

Tanpa dependency eksternal. Hanya Python 3 standard library.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


# ---------------------------------------------------------------------------
# Lokasi default
# ---------------------------------------------------------------------------

SPLITTER_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SPLITTER_DIR.parent
DEFAULT_SOURCE = PROJECT_DIR / "original" / "source"
DEFAULT_OUTPUT = PROJECT_DIR / "commands"
DEFAULT_CORE = PROJECT_DIR / "core"
DEFAULT_REPORT = SPLITTER_DIR / "report.txt"

# Urutan require di core/index.lua: fondasi dulu, baru helper yang memakainya.
CORE_CATEGORIES = ("globals", "args", "notify", "waypoint")

# Nama global yang masuk kategori selain globals.lua.
WAYPOINT_NAMES = {
    "waypointmover", "stopwpping", "wprm", "remove_waypoints",
    "refreshwaypoints", "waypointparts", "wpactivetween", "tweenspeed",
    "waypoints", "pwaypoints", "allwaypoints", "waypointwalkto", "walkto",
}
NOTIFY_NAMES = {
    "notify", "notifyy", "notification", "title_2", "text_2",
    "closebutton", "pinbutton", "pinnotification", "notifycount",
}
ARGS_NAMES = {
    "getstring", "getnum", "getbool", "getplayer", "getitem",
    "getplayersbyname", "parseboolean", "splitstring", "totokens",
    "onlyincludeintable", "removetablematches", "findintable", "getintable",
    "formatusername", "getprfx", "findcmd", "match", "indexcontents",
    "booly", "specialplayercases", "cargs",
}

LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return",
    "then", "true", "until", "while", "continue",
}

# Global bawaan Lua/Luau/Roblox/executor. Tidak dilaporkan sebagai UNRESOLVED.
# Kalau nama ini ternyata dideklarasikan di source (mis. cloneref), deklarasinya
# tetap diekstrak karena resolusi dilakukan sebelum filter ini.
BUILTIN_GLOBALS = {
    # Lua / Luau
    "_G", "_ENV", "_VERSION", "assert", "bit32", "buffer", "collectgarbage",
    "coroutine", "debug", "dofile", "elapsedTime", "error", "gcinfo", "getfenv",
    "getmetatable", "ipairs", "load", "loadfile", "loadstring", "math", "newproxy",
    "next", "os", "package", "pairs", "pcall", "print", "rawequal", "rawget",
    "rawlen", "rawset", "require", "select", "setfenv", "setmetatable", "spawn",
    "string", "table", "task", "tick", "time", "tonumber", "tostring", "type",
    "typeof", "unpack", "utf8", "vector", "wait", "warn", "xpcall", "ypcall",
    # Roblox
    "Axes", "BrickColor", "CFrame", "CatalogSearchParams", "Color3",
    "ColorSequence", "ColorSequenceKeypoint", "DateTime", "DockWidgetPluginGuiInfo",
    "Enum", "Faces", "FloatCurveKey", "Font", "Instance", "NumberRange",
    "NumberSequence", "NumberSequenceKeypoint", "OverlapParams", "PathWaypoint",
    "PhysicalProperties", "Random", "Ray", "RaycastParams", "Rect", "Region3",
    "RotationCurveKey", "SharedTable", "TweenInfo", "UDim", "UDim2", "UserSettings",
    "Vector2", "Vector3", "game", "plugin", "script", "settings", "shared",
    "workspace",
    # Executor
    "Krnl", "appendfile", "checkcaller", "cloneref", "compareinstances",
    "delfile", "delfolder", "dumpstring", "fireclickdetector",
    "fireproximityprompt", "firesignal", "firetouchinterest", "fluxus",
    "getactors", "getallthreads", "getargument", "getbytecode", "getcallbackvalue",
    "getcallingscript", "getconnections", "getconstants", "getcustomasset",
    "getexecutorname", "getfpscap", "getfunctionhash", "getgc", "getgenv",
    "gethiddenproperty", "gethui", "getinfo", "getinstances", "getloadedmodules",
    "getlocal", "getnamecallmethod", "getnetworkowner", "getnilinstances",
    "getpropertychanged", "getrawmetatable", "getreg", "getrenv",
    "getrunningscripts", "getscripts", "getscriptbytecode", "getscriptclosure",
    "getsenv", "getstack", "getthreadidentity", "getupvalue", "getupvalues",
    "hookfunction", "hookmetamethod", "http_request", "identifyexecutor",
    "iscclosure", "isfile", "isfolder", "isnetworkowner", "islclosure", "listfiles",
    "loadstring", "makefolder", "newcclosure", "queue_on_teleport", "readfile",
    "request", "setargument", "setclipboard", "setfpscap", "sethiddenproperty",
    "setlocal", "setrawmetatable", "setrenderproperty", "setstack",
    "setthreadidentity", "setupvalue", "syn", "toclipboard", "writefile",
}

# Baris pertama file hasil generate. Dipakai untuk membersihkan hasil lama
# tanpa menghapus file lain yang mungkin dibuat manual.
MARKER = "-- AUTO-GENERATED by splitter/split.py"

# Keyword Lua yang membuka/menutup blok.
# Catatan: `for` dan `while` TIDAK dihitung karena bloknya dibuka oleh `do`.
BLOCK_OPENERS = {"function", "if", "do", "repeat"}
BLOCK_CLOSERS = {"end", "until"}

# Token sebelum `if` yang menandakan bahwa `if` itu ekspresi Luau
# (if ... then ... else ... tanpa `end`), bukan statement.
EXPRESSION_PREFIXES = {
    "=", "return", ",", "(", "[", "{",
    "and", "or", "not",
    "+", "-", "*", "/", "%", "^", "..",
    "==", "~=", "<", ">", "<=", ">=",
}

# Nama file yang tidak boleh dipakai (bentrok dengan index / device Windows).
RESERVED_FILENAMES = {
    "index",
    "con", "prn", "aux", "nul",
    "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9",
    "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9",
}


# ---------------------------------------------------------------------------
# Tokenizer
# ---------------------------------------------------------------------------

@dataclass
class Token:
    kind: str   # "name", "string", "number", atau "symbol"
    text: str   # teks asli dari source
    start: int  # offset awal di source
    end: int    # offset akhir (eksklusif)


def _long_bracket_end(src: str, start: int):
    """
    Kalau src[start] adalah awal long bracket `[==[`, kembalikan
    (offset_setelah_penutup, level). Kalau bukan, kembalikan None.

    Long bracket Lua:
        [[ ... ]]
        [=[ ... ]=]
        [==[ ... ]==]
    """
    n = len(src)
    if start >= n or src[start] != "[":
        return None

    j = start + 1
    while j < n and src[j] == "=":
        j += 1

    if j >= n or src[j] != "[":
        return None

    level = j - start - 1
    closer = "]" + ("=" * level) + "]"
    end = src.find(closer, j + 1)
    if end == -1:
        return None
    return end + len(closer), level


def _read_short_string(src: str, start: int) -> int:
    """Kembalikan offset setelah tanda kutip penutup string '...' atau \"...\"."""
    quote = src[start]
    i = start + 1
    n = len(src)

    while i < n:
        c = src[i]
        if c == "\\":
            # Lewati karakter yang di-escape (termasuk \\ dan \").
            i += 2
            continue
        if c == quote:
            return i + 1
        i += 1

    return n


def _read_backtick_string(src: str, start: int) -> int:
    """
    Kembalikan offset setelah backtick penutup.

    Luau punya interpolated string: `Halo {nama}`.
    Bagian { ... } adalah ekspresi, jadi kita lewati dengan menghitung
    kurung kurawal dan melewati string di dalamnya. Seluruh literal
    diperlakukan sebagai satu token supaya isinya tidak dianggap kode.
    """
    i = start + 1
    n = len(src)

    while i < n:
        c = src[i]

        if c == "\\":
            i += 2
            continue

        if c == "`":
            return i + 1

        if c == "{":
            # Lewati ekspresi interpolasi sampai '}' yang seimbang.
            depth = 1
            i += 1
            while i < n and depth > 0:
                inner = src[i]

                if inner == "\\":
                    i += 2
                elif inner in "'\"":
                    i = _read_short_string(src, i)
                elif inner == "`":
                    i = _read_backtick_string(src, i)
                elif inner == "[":
                    long = _long_bracket_end(src, i)
                    i = long[0] if long is not None else i + 1
                elif inner == "-" and i + 1 < n and src[i + 1] == "-":
                    newline = src.find("\n", i + 2)
                    i = n if newline == -1 else newline + 1
                elif inner == "{":
                    depth += 1
                    i += 1
                elif inner == "}":
                    depth -= 1
                    i += 1
                else:
                    i += 1
            continue

        i += 1

    return n


def tokenize(src: str) -> list[Token]:
    """
    Ubah source menjadi daftar token.

    Komentar dibuang. String pendek dan long string menjadi satu token,
    sehingga isi string tidak pernah dianggap sebagai kode.
    """
    tokens: list[Token] = []
    i = 0
    n = len(src)

    while i < n:
        c = src[i]

        # Spasi / newline.
        if c in " \t\r\n\v\f":
            i += 1
            continue

        # Komentar: -- sampai newline, atau --[[ ... ]] / --[==[ ... ]==].
        if c == "-" and i + 1 < n and src[i + 1] == "-":
            j = i + 2
            if j < n and src[j] == "[":
                long = _long_bracket_end(src, j)
                if long is not None:
                    i = long[0]
                    continue
            newline = src.find("\n", i + 2)
            i = n if newline == -1 else newline + 1
            continue

        # Long string [[ ... ]] / [==[ ... ]==].
        if c == "[":
            long = _long_bracket_end(src, i)
            if long is not None:
                end, _ = long
                tokens.append(Token("string", src[i:end], i, end))
                i = end
                continue

        # String pendek '...' atau "...".
        if c in "'\"":
            end = _read_short_string(src, i)
            tokens.append(Token("string", src[i:end], i, end))
            i = end
            continue

        # Interpolated string Luau: `Halo {nama}`.
        if c == "`":
            end = _read_backtick_string(src, i)
            tokens.append(Token("string", src[i:end], i, end))
            i = end
            continue

        # Identifier / keyword.
        if c.isalpha() or c == "_":
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            tokens.append(Token("name", src[i:j], i, j))
            i = j
            continue

        # Angka (cukup untuk melewati, tidak dipakai untuk parsing).
        if c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit()):
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] in "._"):
                j += 1
            tokens.append(Token("number", src[i:j], i, j))
            i = j
            continue

        # Simbol satu karakter: ( ) { } [ ] , ; + - * / = dan lain-lain.
        tokens.append(Token("symbol", c, i, i + 1))
        i += 1

    return tokens


# ---------------------------------------------------------------------------
# Helper parsing
# ---------------------------------------------------------------------------

def match_bracket(tokens: list[Token], open_index: int):
    """
    Cari pasangan bracket untuk token di open_index.
    Mendukung nested bracket dengan tipe yang sama, misalnya ((...)).
    """
    pairs = {"(": ")", "[": "]", "{": "}"}
    open_text = tokens[open_index].text
    if open_text not in pairs:
        return None

    close_text = pairs[open_text]
    depth = 0

    for j in range(open_index, len(tokens)):
        token = tokens[j]
        if token.kind != "symbol":
            continue
        if token.text == open_text:
            depth += 1
        elif token.text == close_text:
            depth -= 1
            if depth == 0:
                return j

    return None


def find_function_end(tokens: list[Token], function_index: int):
    """
    Kembalikan index token `end` yang menutup `function` di function_index.
    Mengembalikan None kalau blok tidak seimbang.
    """
    depth = 0

    for j in range(function_index, len(tokens)):
        token = tokens[j]
        if token.kind != "name":
            continue

        if token.text in BLOCK_OPENERS:
            # Luau punya if-expression: `local x = if a then b else c`.
            # Bentuk ini tidak punya `end`, jadi jangan dihitung sebagai blok.
            if token.text == "if" and j > 0 and tokens[j - 1].text in EXPRESSION_PREFIXES:
                continue
            depth += 1
        elif token.text in BLOCK_CLOSERS:
            depth -= 1
            if depth == 0:
                return j
            if depth < 0:
                return None

    return None


def is_if_expression(tokens: list[Token], index: int) -> bool:
    """True kalau token `if` di index adalah if-expression Luau, bukan statement."""
    return index > 0 and tokens[index - 1].text in EXPRESSION_PREFIXES


def compute_depths(tokens: list[Token]) -> list[tuple[int, int]]:
    """
    Kembalikan (block_depth, bracket_depth) SEBELUM token ke-i.
    Deklarasi global hanya diambil saat keduanya 0.
    """
    result: list[tuple[int, int]] = []
    block_depth = 0
    bracket_depth = 0

    for index, token in enumerate(tokens):
        result.append((block_depth, bracket_depth))

        if token.kind == "symbol":
            if token.text in "([{":
                bracket_depth += 1
            elif token.text in ")]}":
                bracket_depth = max(0, bracket_depth - 1)
        elif token.kind == "name":
            if token.text in BLOCK_OPENERS:
                if token.text != "if" or not is_if_expression(tokens, index):
                    block_depth += 1
            elif token.text in BLOCK_CLOSERS:
                block_depth = max(0, block_depth - 1)

    return result


# Token yang membuat baris berikutnya masih bagian dari ekspresi yang sama.
_CONTINUATION_TOKENS = {
    "and", "or", "not", "then", "else", "elseif",
    "+", "-", "*", "/", "%", "^", "..", "=", ",", ".", ":",
    "==", "~=", "<", ">", "<=", ">=",
}


def gap_has_newline(gap: str) -> bool:
    """
    True kalau ada newline di luar komentar. Newline di dalam komentar
    tidak boleh memotong ekspresi multi-baris.
    """
    i = 0
    n = len(gap)

    while i < n:
        if gap[i] == "-" and i + 1 < n and gap[i + 1] == "-":
            j = i + 2
            if j < n and gap[j] == "[":
                long = _long_bracket_end(gap, j)
                if long is not None:
                    i = long[0]
                    continue
            newline = gap.find("\n", i + 2)
            if newline == -1:
                return False
            i = newline + 1
            continue

        if gap[i] == "\n":
            return True
        i += 1

    return False


def find_statement_end(src: str, tokens: list[Token], start_index: int) -> int:
    """
    Index token terakhir dari ekspresi yang dimulai di start_index.
    Berhenti di newline top-level, `;`, atau akhir token.
    Bracket dan blok function/if/do/repeat dihitung agar tabel/closure
    multi-baris tidak terpotong.
    """
    if start_index >= len(tokens):
        return len(tokens) - 1

    bracket_depth = 0
    block_depth = 0
    last = start_index

    for j in range(start_index, len(tokens)):
        token = tokens[j]

        if token.kind == "symbol":
            if token.text in "([{":
                bracket_depth += 1
            elif token.text in ")]}":
                bracket_depth -= 1
                if bracket_depth < 0:
                    return last
            elif token.text == ";" and bracket_depth == 0 and block_depth == 0:
                return last
        elif token.kind == "name":
            if token.text in BLOCK_OPENERS:
                if token.text != "if" or not is_if_expression(tokens, j):
                    block_depth += 1
            elif token.text in BLOCK_CLOSERS:
                block_depth -= 1
                if block_depth < 0:
                    return last

        last = j

        if bracket_depth == 0 and block_depth == 0:
            if j + 1 >= len(tokens):
                return j
            gap = src[token.end:tokens[j + 1].start]
            if (
                gap_has_newline(gap)
                and token.text not in _CONTINUATION_TOKENS
                and tokens[j + 1].text not in _CONTINUATION_TOKENS
            ):
                return j

    return len(tokens) - 1


def split_top_level_commas(
    src: str, tokens: list[Token], start_index: int, end_index: int
) -> list[str]:
    """Pisahkan ekspresi RHS pada koma top-level (untuk multiple assignment)."""
    parts: list[str] = []
    part_start = start_index
    bracket_depth = 0
    block_depth = 0

    for j in range(start_index, end_index + 1):
        token = tokens[j]

        if token.kind == "symbol":
            if token.text in "([{":
                bracket_depth += 1
            elif token.text in ")]}":
                bracket_depth -= 1
            elif token.text == "," and bracket_depth == 0 and block_depth == 0:
                parts.append(src[tokens[part_start].start:token.start].strip())
                part_start = j + 1
        elif token.kind == "name":
            if token.text in BLOCK_OPENERS:
                if token.text != "if" or not is_if_expression(tokens, j):
                    block_depth += 1
            elif token.text in BLOCK_CLOSERS:
                block_depth -= 1

    parts.append(src[tokens[part_start].start:tokens[end_index].end].strip())
    return parts


@dataclass
class GlobalDecl:
    name: str
    kind: str   # "function" atau "variable"
    line: int
    text: str
    deps: set[str]


def extract_globals(
    src: str, tokens: list[Token], depths: list[tuple[int, int]]
) -> tuple[dict[str, GlobalDecl], list[dict]]:
    """
    Kumpulkan deklarasi global di scope top-level saja.

    Didukung:
      function NAMA(...) ... end
      NAMA = function(...) ... end
      NAMA = { ... } / setmetatable(...) / Instance.new(...) / ekspresi lain
      NAMA, LAIN = ekspresi1, ekspresi2

    `local`, field (`a.b`), dan deklarasi di dalam addcmd/fungsi lain dilewati.
    """
    declarations: dict[str, GlobalDecl] = {}
    failures: list[dict] = []
    i = 0

    while i < len(tokens):
        token = tokens[i]

        if token.kind != "name" or depths[i] != (0, 0):
            i += 1
            continue

        # function NAMA(...) ... end
        if token.text == "function":
            if i > 0 and tokens[i - 1].text == "local":
                i += 1
                continue

            name_index = i + 1
            if name_index >= len(tokens) or tokens[name_index].kind != "name":
                i += 1
                continue

            # function a.b / a:b bukan global sederhana.
            if (
                name_index + 1 < len(tokens)
                and tokens[name_index + 1].text in {".", ":"}
            ):
                i += 1
                continue

            name = tokens[name_index].text
            end_index = find_function_end(tokens, i)
            if end_index is None:
                failures.append({
                    "line": line_number(src, token.start),
                    "name": name,
                    "reason": "blok function tidak seimbang",
                })
                i += 1
                continue

            text = src[token.start:tokens[end_index].end]
            if name not in declarations:
                declarations[name] = GlobalDecl(
                    name, "function", line_number(src, token.start),
                    text, scan_identifiers(text),
                )
            i = end_index + 1
            continue

        # NAMA = ... (termasuk multiple assignment)
        if token.text in LUA_KEYWORDS:
            i += 1
            continue
        if i > 0 and tokens[i - 1].text in {"local", "for", ".", ":"}:
            i += 1
            continue

        names = [token.text]
        j = i + 1
        while (
            j + 1 < len(tokens)
            and tokens[j].text == ","
            and tokens[j + 1].kind == "name"
        ):
            names.append(tokens[j + 1].text)
            j += 2

        if j >= len(tokens) or tokens[j].text != "=":
            i += 1
            continue

        rhs_start = j + 1
        if rhs_start >= len(tokens):
            i += 1
            continue

        end_index = find_statement_end(src, tokens, rhs_start)
        if end_index < rhs_start:
            i += 1
            continue

        parts = split_top_level_commas(src, tokens, rhs_start, end_index)
        if len(parts) != len(names):
            i = end_index + 1
            continue

        for name, part in zip(names, parts):
            if not part or name in LUA_KEYWORDS or name in declarations:
                continue
            kind = "function" if re.match(r"^function\b", part) else "variable"
            # Simpan assignment lengkap; menulis RHS saja akan menghasilkan
            # statement ekspresi yang bukan Lua valid.
            text = "{} = {}".format(name, part)
            declarations[name] = GlobalDecl(
                name, kind, line_number(src, token.start),
                text, scan_identifiers(part),
            )

        i = end_index + 1

    return declarations, failures


def collect_top_level_locals(
    src: str, tokens: list[Token], depths: list[tuple[int, int]]
) -> dict[str, int]:
    """
    Catat nama `local` di top-level. Dipakai hanya untuk membedakan
    dependency lokal dari UNRESOLVED; isinya tidak diekstrak.
    """
    result: dict[str, int] = {}

    for i, token in enumerate(tokens):
        if (
            token.kind != "name"
            or token.text != "local"
            or depths[i] != (0, 0)
        ):
            continue

        j = i + 1
        if j < len(tokens) and tokens[j].text == "function":
            j += 1
            if j < len(tokens) and tokens[j].kind == "name":
                result.setdefault(tokens[j].text, line_number(src, tokens[j].start))
            continue

        while j < len(tokens) and tokens[j].text not in {"=", ";"}:
            if tokens[j].text in LUA_KEYWORDS:
                break
            # `local x` tanpa initializer berhenti di newline; jangan
            # menelan statement berikutnya.
            if (
                j > i + 1
                and gap_has_newline(src[tokens[j - 1].end:tokens[j].start])
                and tokens[j - 1].text not in {",", ":", "<"}
            ):
                break
            if tokens[j].kind == "name":
                result.setdefault(tokens[j].text, line_number(src, tokens[j].start))
            j += 1

    return result


def scan_identifiers(text: str) -> set[str]:
    """
    Deteksi identifier global yang dipakai dalam potongan kode.

    Heuristik:
    - nama lokal (local/parameter/for) tidak dihitung;
    - field/metode (`obj.nama`, `obj:nama`) tidak dihitung;
    - target assignment (`nama =`) dan key tabel (`{ nama = ... }`) tidak dihitung.
    """
    tokens = tokenize(text)
    locals_: set[str] = {"self"}

    # Pass 1: kumpulkan nama lokal (cukup function-wide, bukan per-scope).
    i = 0
    while i < len(tokens):
        token = tokens[i]

        if token.kind == "name":
            if token.text == "local":
                j = i + 1
                if j < len(tokens) and tokens[j].text == "function":
                    j += 1
                    if j < len(tokens) and tokens[j].kind == "name":
                        locals_.add(tokens[j].text)
                else:
                    while j < len(tokens) and tokens[j].text not in {"=", ";"}:
                        if tokens[j].text in LUA_KEYWORDS:
                            break
                        if (
                            j > i + 1
                            and gap_has_newline(text[tokens[j - 1].end:tokens[j].start])
                            and tokens[j - 1].text not in {",", ":", "<"}
                        ):
                            break
                        if tokens[j].kind == "name":
                            locals_.add(tokens[j].text)
                        j += 1
            elif token.text == "for":
                j = i + 1
                while j < len(tokens) and tokens[j].text not in {"=", "in", "do"}:
                    if tokens[j].kind == "name":
                        locals_.add(tokens[j].text)
                    j += 1
            elif token.text == "function":
                j = i + 1
                if j < len(tokens) and tokens[j].kind == "name":
                    j += 1
                if j < len(tokens) and tokens[j].text == "(":
                    close = match_bracket(tokens, j)
                    if close is not None:
                        for k in range(j + 1, close):
                            if tokens[k].kind == "name":
                                locals_.add(tokens[k].text)

        i += 1

    # Pass 2: ambil identifier yang bukan lokal/field/keyword/assignment target.
    used: set[str] = set()
    for i, token in enumerate(tokens):
        if token.kind != "name":
            continue

        name = token.text
        if name in LUA_KEYWORDS or name in locals_:
            continue

        prev = tokens[i - 1].text if i > 0 else ""
        nxt = tokens[i + 1].text if i + 1 < len(tokens) else ""

        if prev in {".", ":"}:
            continue
        if prev == "function":
            continue
        if nxt == "=" and prev not in {
            "==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "^=", "..=",
        }:
            continue

        used.add(name)

    return used


def categorize(name: str) -> str:
    """Pilih file core berdasarkan nama global."""
    lower = name.lower()

    if lower in WAYPOINT_NAMES or "waypoint" in lower or lower.startswith("wp"):
        return "waypoint"
    if (
        lower in NOTIFY_NAMES
        or lower.startswith("notify")
        or lower.startswith("pinnotification")
        or lower.startswith("notification")
    ):
        return "notify"
    if lower in ARGS_NAMES:
        return "args"
    return "globals"


def scan_dependencies(
    commands: list[dict],
    declarations: dict[str, GlobalDecl],
    top_level_locals: dict[str, int],
) -> tuple[
    dict[str, set[str]], set[str], set[str], set[str], set[str], dict[str, set[str]]
]:
    """
    Hitung dependency langsung tiap command + closure global yang diekstrak.

    Kembalikan:
      per_command : nama command -> identifier yang dipakai
      extracted   : global yang punya deklarasi dan perlu diekstrak
      unresolved  : dipakai tapi tidak ada deklarasi (bukan builtin/local)
      local_deps  : top-level local yang dipakai (tidak diekstrak)
      seen_used   : semua identifier yang terlihat
      users       : identifier -> command/helper yang memakainya
    """
    per_command: dict[str, set[str]] = {}
    seen_used: set[str] = set()
    users: dict[str, set[str]] = {}

    for command in commands:
        used = scan_identifiers(command["function"])
        per_command[command["file"]] = used
        seen_used |= used
        label = command["file"] + ".lua"
        for name in used:
            users.setdefault(name, set()).add(label)

    extracted: set[str] = set()
    queue = [name for name in seen_used if name in declarations]

    while queue:
        name = queue.pop()
        if name in extracted:
            continue
        extracted.add(name)
        for dep in declarations[name].deps:
            users.setdefault(dep, set()).add(name)
            if dep not in seen_used:
                seen_used.add(dep)
                if dep in declarations:
                    queue.append(dep)

    local_names = set(top_level_locals)
    unresolved = seen_used - extracted - BUILTIN_GLOBALS - local_names
    local_deps = seen_used & local_names

    return per_command, extracted, unresolved, local_deps, seen_used, users


_SIMPLE_ESCAPES = {
    "a": "\a",
    "b": "\b",
    "f": "\f",
    "n": "\n",
    "r": "\r",
    "t": "\t",
    "v": "\v",
    "\\": "\\",
    "'": "'",
    '"': '"',
}


def decode_lua_string(raw: str) -> str:
    """
    Ubah literal string Lua menjadi teks biasa.
    Cukup untuk nama command dan alias; escape umum didukung.
    """
    if raw.startswith("["):
        match = re.match(r"\[(=*)\[", raw)
        if not match:
            return raw
        equal_signs = match.group(1)
        body = raw[match.end(): len(raw) - len("]" + equal_signs + "]")]
        # Lua membuang newline pertama tepat setelah long bracket.
        if body.startswith("\r\n"):
            body = body[2:]
        elif body.startswith("\n"):
            body = body[1:]
        return body

    body = raw[1:-1]
    result: list[str] = []
    i = 0

    while i < len(body):
        c = body[i]
        if c != "\\":
            result.append(c)
            i += 1
            continue

        i += 1
        if i >= len(body):
            break

        escape = body[i]

        if escape in _SIMPLE_ESCAPES:
            result.append(_SIMPLE_ESCAPES[escape])
            i += 1

        elif escape == "z":
            # \z melewati semua whitespace berikutnya.
            i += 1
            while i < len(body) and body[i].isspace():
                i += 1

        elif escape == "x":
            hex_digits = body[i + 1:i + 3]
            if len(hex_digits) == 2 and all(ch in "0123456789abcdefABCDEF" for ch in hex_digits):
                result.append(chr(int(hex_digits, 16)))
                i += 3
            else:
                result.append(escape)
                i += 1

        elif escape.isdigit():
            j = i
            while j < len(body) and j < i + 3 and body[j].isdigit():
                j += 1
            result.append(chr(int(body[i:j]) % 256))
            i = j

        elif escape == "u" and i + 1 < len(body) and body[i + 1] == "{":
            closing = body.find("}", i + 2)
            if closing != -1:
                try:
                    result.append(chr(int(body[i + 2:closing], 16)))
                except ValueError:
                    pass
                i = closing + 1
            else:
                result.append(escape)
                i += 1

        else:
            result.append(escape)
            i += 1

    return "".join(result)


def lua_quote(value: str) -> str:
    """Buat literal string Lua yang aman dari teks biasa."""
    escaped = (
        value
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return '"' + escaped + '"'


def sanitize_filename(name: str) -> str:
    """
    Ubah nama command menjadi nama file yang aman.
    Contoh: "Anti-AFK" -> "Anti-AFK", "foo/bar" -> "foo_bar".
    """
    filename = re.sub(r"[^A-Za-z0-9_.-]+", "_", name).strip(" .")
    if not filename:
        filename = "command"
    if filename.lower() in RESERVED_FILENAMES:
        filename = "cmd_" + filename
    return filename


def line_number(src: str, offset: int) -> int:
    """Nomor baris (1-based) untuk offset tertentu."""
    return src.count("\n", 0, offset) + 1


def display_path(path: Path) -> str:
    """Tampilkan path relatif ke folder project kalau memungkinkan."""
    try:
        return str(path.resolve().relative_to(PROJECT_DIR))
    except ValueError:
        return str(path)


# ---------------------------------------------------------------------------
# Parser addcmd
# ---------------------------------------------------------------------------

def parse_addcmd(src: str, tokens: list[Token], index: int):
    """
    Parse satu pemanggilan addcmd pada posisi token `index`.

    Hasil berupa dict kalau berhasil, atau dict dengan key "error"/"skipped"
    kalau tidak bisa diproses.
    """
    # addcmd harus diikuti '('.
    if index + 1 >= len(tokens) or tokens[index + 1].text != "(":
        return None

    call_open = index + 1
    call_close = match_bracket(tokens, call_open)
    if call_close is None:
        return {
            "error": "tanda kurung addcmd tidak seimbang",
            "line": line_number(src, tokens[index].start),
        }

    first_arg = call_open + 1
    if first_arg >= call_close:
        return None

    # Argumen pertama harus string literal. Kalau bukan (misalnya
    # addcmd(cmdName, ...)), itu pendaftaran dinamis dan kita lewati.
    if tokens[first_arg].kind != "string":
        return {
            "skipped": "argumen nama bukan string literal",
            "line": line_number(src, tokens[index].start),
        }

    name = decode_lua_string(tokens[first_arg].text)

    # Cari token `function` pada kedalaman bracket 0 (di dalam argumen call).
    function_index = None
    bracket_depth = 0
    for j in range(first_arg + 1, call_close):
        token = tokens[j]
        if token.kind == "symbol":
            if token.text in "([{":
                bracket_depth += 1
            elif token.text in ")]}":
                bracket_depth -= 1
        elif bracket_depth == 0 and token.kind == "name" and token.text == "function":
            function_index = j
            break

    if function_index is None:
        return {
            "error": "tidak menemukan blok function",
            "line": line_number(src, tokens[index].start),
            "name": name,
        }

    # Cari tabel alias (argumen kedua) sebelum function.
    alias_open = None
    for j in range(first_arg + 1, function_index):
        if tokens[j].kind == "symbol" and tokens[j].text == "{":
            alias_open = j
            break

    aliases: list[str] = []
    if alias_open is not None:
        alias_close = match_bracket(tokens, alias_open)
        if alias_close is None or alias_close > function_index:
            return {
                "error": "tabel alias tidak seimbang",
                "line": line_number(src, tokens[index].start),
                "name": name,
            }

        depth = 0
        for j in range(alias_open + 1, alias_close):
            token = tokens[j]
            if token.kind == "symbol":
                if token.text == "{":
                    depth += 1
                elif token.text == "}":
                    depth -= 1
            elif token.kind == "string" and depth == 0:
                aliases.append(decode_lua_string(token.text))

    function_end = find_function_end(tokens, function_index)
    if function_end is None or function_end >= call_close:
        return {
            "error": "blok function tidak seimbang",
            "line": line_number(src, tokens[index].start),
            "name": name,
        }

    function_text = src[tokens[function_index].start:tokens[function_end].end]

    return {
        "name": name,
        "aliases": aliases,
        "function": function_text,
        "line": line_number(src, tokens[index].start),
        "call_start": tokens[index].start,
        "call_end": tokens[call_close].end,
    }


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def clean_generated(output_dir: Path) -> None:
    """Hapus file .lua lama yang punya marker generate, bukan file manual."""
    for path in output_dir.glob("*.lua"):
        try:
            with path.open("r", encoding="utf-8") as handle:
                first_line = handle.readline()
        except OSError:
            continue
        if first_line.startswith(MARKER):
            path.unlink()


def command_header(command: dict, source_label: str) -> str:
    aliases = ", ".join(command["aliases"]) if command["aliases"] else "(tanpa alias)"
    return "\n".join([
        MARKER,
        "-- Command : " + command["name"],
        "-- Aliases : " + aliases,
        "-- Source  : " + source_label + ":" + str(command["line"]),
        "-- License : MIT - refactored from EdgeIY/infiniteyield",
        "",
    ])


def command_module(command: dict, source_label: str) -> str:
    aliases = ", ".join(lua_quote(alias) for alias in command["aliases"])
    return (
        command_header(command, source_label)
        + "return {\n"
        + "\tname = " + lua_quote(command["name"]) + ",\n"
        + "\taliases = {" + aliases + "},\n"
        + "\tfn = " + command["function"] + ",\n"
        + "}\n"
    )


def index_module(commands: list[dict]) -> str:
    lines = [
        MARKER,
        "-- Daftar modul command. File ini yang melakukan require ke setiap modul.",
        "-- Urutan mengikuti urutan addcmd di original/source.",
        "return {",
    ]
    for command in commands:
        lines.append("\trequire(script.Parent[" + lua_quote(command["file"]) + "]),")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def core_module(
    category: str, declarations: list[GlobalDecl], source_label: str
) -> str:
    """Tulis satu file core/ berisi deklarasi global sesuai kategori."""
    names = [declaration.name for declaration in declarations]
    if names:
        summary = ", ".join(names[:20])
        if len(names) > 20:
            summary += ", ... ({} total)".format(len(names))
    else:
        summary = "(tidak ada deklarasi yang dipakai command)"

    lines = [
        MARKER,
        "-- Core      : " + category,
        "-- Source    : " + source_label,
        "-- License   : MIT - refactored from EdgeIY/infiniteyield",
        "-- Berisi    : " + summary,
        "",
    ]

    # Urutan source menjaga dependensi load-time tetap seperti aslinya.
    for declaration in sorted(declarations, key=lambda item: (item.line, item.name)):
        lines.append(
            "-- line {}: {} ({})".format(
                declaration.line, declaration.name, declaration.kind
            )
        )
        lines.append(declaration.text)
        lines.append("")

    lines.append("return {}")
    lines.append("")
    return "\n".join(lines)


def core_index_module() -> str:
    lines = [
        MARKER,
        "-- Helper global dipisah per kategori.",
        "-- Urutan: fondasi dulu, lalu helper yang memakainya.",
        "require(script.Parent.globals)",
        "require(script.Parent.args)",
        "require(script.Parent.notify)",
        "require(script.Parent.waypoint)",
        "return true",
        "",
    ]
    return "\n".join(lines)


def write_report(
    path: Path,
    source_path: Path,
    output_dir: Path,
    core_dir: Path,
    commands: list[dict],
    skipped: list[dict],
    warnings: list[str],
    check: dict | None,
    core_stats: dict[str, dict],
    dependencies: dict[str, set[str]],
    extracted: set[str],
    unresolved: set[str],
    local_deps: set[str],
    users: dict[str, set[str]],
    parse_failures: list[dict],
) -> None:
    lines = [
        "Infinite Yield split report",
        "=" * 28,
        "Source        : " + display_path(source_path),
        "Output        : " + display_path(output_dir),
        "Core          : " + display_path(core_dir),
        "Commands found: " + str(len(commands)),
        "Files written : " + str(len(commands)),
        "Skipped addcmd: " + str(len(skipped)),
        "",
        "Files:",
    ]

    if commands:
        for command in commands:
            aliases = ", ".join(command["aliases"]) if command["aliases"] else "-"
            lines.append(
                "  {:<32} line {:<6} aliases: {}".format(
                    command["file"] + ".lua", command["line"], aliases
                )
            )
    else:
        lines.append("  (tidak ada)")

    lines.append("")
    lines.append("Skipped addcmd (bukan string literal / dinamis):")
    if skipped:
        for item in skipped:
            lines.append("  line {}: {}".format(item["line"], item["skipped"]))
    else:
        lines.append("  (tidak ada)")

    lines.append("")
    lines.append("Core declarations:")
    total_core = 0
    for category in CORE_CATEGORIES:
        stat = core_stats.get(category, {
            "total": 0, "functions": 0, "variables": 0,
        })
        total_core += stat["total"]
        lines.append(
            "  {:<12} : {:>3} (fungsi {}, variabel {})".format(
                category + ".lua", stat["total"],
                stat["functions"], stat["variables"],
            )
        )
    lines.append("  {:<12} : {:>3}".format("Total", total_core))

    def dep_label(name: str) -> str | None:
        if name in extracted:
            return name
        if name in local_deps:
            return name + " (local)"
        if name in unresolved:
            return name + "?"
        return None

    dependency_rows: list[tuple[str, str]] = []
    for command in commands:
        labels = [
            label
            for label in (
                dep_label(name)
                for name in sorted(dependencies.get(command["file"], set()))
            )
            if label is not None
        ]
        dependency_rows.append(
            (command["file"] + ".lua", ", ".join(labels) if labels else "-")
        )

    lines.append("")
    lines.append(
        "Dependencies per command (global yang dipakai; "
        "`?` = tidak ditemukan, `(local)` = top-level local):"
    )
    if dependency_rows:
        width = max(len(label) for label, _ in dependency_rows)
        for label, deps in dependency_rows:
            lines.append("  {:<{}} → {}".format(label, width, deps))
    else:
        lines.append("  (tidak ada)")

    lines.append("")
    lines.append("UNRESOLVED (dipakai tapi tidak ada deklarasi top-level):")
    if unresolved:
        for name in sorted(unresolved):
            used_by = ", ".join(sorted(users.get(name, set()))) or "-"
            lines.append("  {:<24} ← {}".format(name, used_by))
    else:
        lines.append("  (tidak ada)")

    lines.append("")
    lines.append("Top-level local (tidak diekstrak; hanya terlihat di file aslinya):")
    if local_deps:
        for name in sorted(local_deps):
            used_by = ", ".join(sorted(users.get(name, set()))) or "-"
            lines.append("  {:<24} ← {}".format(name, used_by))
    else:
        lines.append("  (tidak ada)")

    lines.append("")
    lines.append("Blok gagal di-parse (bracket/blok tidak seimbang):")
    if parse_failures:
        for item in parse_failures:
            lines.append(
                "  line {}: {} - {}".format(
                    item["line"], item.get("name", "?"), item["reason"]
                )
            )
    else:
        lines.append("  (tidak ada)")

    lines.append("")
    lines.append("Warnings:")
    if warnings:
        for warning in warnings:
            lines.append("  - " + warning)
    else:
        lines.append("  (tidak ada)")

    if check is not None:
        lines.append("")
        lines.append("luac -p check:")
        if not check["available"]:
            lines.append("  luac tidak ditemukan; pengecekan dilewati.")
        else:
            lines.append("  OK        : {}".format(len(check["ok"])))
            lines.append("  Luau-only : {}".format(len(check["luau"])))
            lines.append("  Gagal     : {}".format(len(check["failed"])))
            for item in check["luau"]:
                lines.append("  [luau] {}: {}".format(item["file"], item["message"]))
            for item in check["failed"]:
                lines.append("  [FAIL] {}: {}".format(item["file"], item["message"]))

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# --check dengan luac -p
# ---------------------------------------------------------------------------

def _has_luau_only_syntax(text: str) -> bool:
    """
    Deteksi sintaks Luau yang tidak dikenal luac (Lua 5.4):
    `continue` dan compound assignment seperti `+=`, `-=`, `..=`.
    Dipakai hanya untuk memberi label pada error luac, bukan untuk mengubah file.
    """
    tokens = tokenize(text)

    for i, token in enumerate(tokens):
        if token.kind == "string" and token.text.startswith("`"):
            return True

        if token.kind == "name" and token.text == "continue":
            return True

        if (
            token.kind == "name"
            and token.text == "if"
            and i > 0
            and tokens[i - 1].text in EXPRESSION_PREFIXES
        ):
            return True

        if token.kind == "symbol" and token.text in {"+", "-", "*", "/", "%", "^", "."}:
            # Cek pola operator diikuti '=' tanpa spasi: += -= *= /= %= ^= ..=
            j = i + 1
            while j < len(tokens) and tokens[j].kind == "symbol" and tokens[j].text == token.text:
                j += 1
            if (
                j < len(tokens)
                and tokens[j].kind == "symbol"
                and tokens[j].text == "="
                and tokens[j].start == tokens[j - 1].end
            ):
                return True

    return False


def run_luac_check(paths: list[Path]) -> dict:
    """Jalankan `luac -p` untuk setiap file. Kembalikan ringkasan hasil."""
    luac = shutil.which("luac")
    result = {"available": luac is not None, "ok": [], "luau": [], "failed": []}
    if luac is None:
        return result

    for path in paths:
        # Jalankan dari root project dengan path relatif supaya pesan error
        # di report.txt tidak berisi path absolut mesin pembuatnya.
        try:
            run_path = str(path.resolve().relative_to(PROJECT_DIR))
            run_cwd = str(PROJECT_DIR)
        except ValueError:
            run_path = str(path)
            run_cwd = None

        try:
            process = subprocess.run(
                [luac, "-p", run_path],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=run_cwd,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            result["failed"].append({"file": path.name, "message": str(error)})
            continue

        if process.returncode == 0:
            result["ok"].append(path.name)
            continue

        message = (process.stderr or process.stdout).strip().replace("\n", " ")
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            text = ""

        bucket = "luau" if _has_luau_only_syntax(text) else "failed"
        result[bucket].append({"file": path.name, "message": message})

    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Pecah file source Infinite Yield menjadi modul per command."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help="file source asli (default: original/source)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="folder output command (default: commands/)",
    )
    parser.add_argument(
        "--core",
        type=Path,
        default=DEFAULT_CORE,
        help="folder output helper global (default: core/)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="validasi hasil dengan `luac -p` kalau luac tersedia",
    )
    args = parser.parse_args()

    source_path: Path = args.source
    output_dir: Path = args.out
    core_dir: Path = args.core

    # Dukung dua nama file: original/source (sesuai README) atau
    # original/source.txt (nama yang sering dipakai saat upload lewat GitHub).
    if source_path == DEFAULT_SOURCE and not source_path.is_file():
        fallback = PROJECT_DIR / "original" / "source.txt"
        if fallback.is_file():
            source_path = fallback

    if not source_path.is_file():
        print("ERROR: file source tidak ditemukan: {}".format(source_path), file=sys.stderr)
        print(
            "Taruh file `source` (atau `source.txt`) dari EdgeIY/infiniteyield di folder original/.",
            file=sys.stderr,
        )
        return 2

    try:
        # utf-8-sig membuang BOM kalau ada.
        src = source_path.read_text(encoding="utf-8-sig")
    except OSError as error:
        print("ERROR: tidak bisa membaca source: {}".format(error), file=sys.stderr)
        return 2

    output_dir.mkdir(parents=True, exist_ok=True)
    core_dir.mkdir(parents=True, exist_ok=True)
    clean_generated(output_dir)
    clean_generated(core_dir)

    tokens = tokenize(src)
    depths = compute_depths(tokens)
    declarations, global_failures = extract_globals(src, tokens, depths)
    top_level_locals = collect_top_level_locals(src, tokens, depths)

    commands: list[dict] = []
    warnings: list[str] = []
    skipped: list[dict] = []
    used_filenames: dict[str, str] = {}

    for index, token in enumerate(tokens):
        if token.kind != "name" or token.text != "addcmd":
            continue

        # Abaikan method/field bernama addcmd (misalnya obj:addcmd(...)).
        if index > 0 and tokens[index - 1].text in {".", ":"}:
            continue

        parsed = parse_addcmd(src, tokens, index)
        if parsed is None:
            continue

        if "skipped" in parsed:
            skipped.append(parsed)
            continue

        if "error" in parsed:
            name = parsed.get("name", "?")
            warnings.append(
                "line {}: {} (command '{}') - dilewati".format(
                    parsed["line"], parsed["error"], name
                )
            )
            continue

        filename = sanitize_filename(parsed["name"])

        # Tangani nama file yang bentrok (misalnya dua command bernama sama
        # atau nama berbeda yang setelah sanitasi menjadi sama).
        if filename in used_filenames:
            base = filename
            counter = 2
            while "{}_{}".format(base, counter) in used_filenames:
                counter += 1
            filename = "{}_{}".format(base, counter)
            warnings.append(
                "line {}: nama file '{}' bentrok, memakai '{}'".format(
                    parsed["line"], base, filename
                )
            )

        used_filenames[filename] = parsed["name"]
        parsed["file"] = filename
        commands.append(parsed)

    if not commands:
        print("ERROR: tidak ada addcmd yang berhasil diproses.", file=sys.stderr)
        return 1

    # Tulis modul command.
    source_label = display_path(source_path)
    for command in commands:
        path = output_dir / (command["file"] + ".lua")
        path.write_text(command_module(command, source_label), encoding="utf-8")

    # Tulis index yang me-require semua modul.
    (output_dir / "index.lua").write_text(index_module(commands), encoding="utf-8")

    # Dependency scan + ekstraksi helper global ke core/.
    (
        dependencies,
        extracted,
        unresolved,
        local_deps,
        _seen_used,
        users,
    ) = scan_dependencies(commands, declarations, top_level_locals)

    core_declarations: dict[str, list[GlobalDecl]] = {
        category: [] for category in CORE_CATEGORIES
    }
    for name in sorted(extracted):
        core_declarations[categorize(name)].append(declarations[name])

    core_stats: dict[str, dict] = {}
    for category in CORE_CATEGORIES:
        items = core_declarations[category]
        (core_dir / (category + ".lua")).write_text(
            core_module(category, items, source_label), encoding="utf-8"
        )
        functions = sum(1 for item in items if item.kind == "function")
        core_stats[category] = {
            "total": len(items),
            "functions": functions,
            "variables": len(items) - functions,
        }

    (core_dir / "index.lua").write_text(core_index_module(), encoding="utf-8")

    # Validasi opsional.
    check_result = None
    if args.check:
        check_paths = [output_dir / (command["file"] + ".lua") for command in commands]
        check_paths.append(output_dir / "index.lua")
        for category in CORE_CATEGORIES:
            check_paths.append(core_dir / (category + ".lua"))
        check_paths.append(core_dir / "index.lua")
        loader_path = core_dir / "loader.lua"
        if loader_path.is_file():
            check_paths.append(loader_path)
        check_result = run_luac_check(check_paths)

    write_report(
        DEFAULT_REPORT,
        source_path,
        output_dir,
        core_dir,
        commands,
        skipped,
        warnings,
        check_result,
        core_stats,
        dependencies,
        extracted,
        unresolved,
        local_deps,
        users,
        global_failures,
    )

    print("Sumber    : {}".format(display_path(source_path)))
    print("Output    : {}".format(display_path(output_dir)))
    print("Core      : {}".format(display_path(core_dir)))
    print("Ditemukan : {} command".format(len(commands)))
    print("Ditulis   : {} file + index.lua".format(len(commands)))
    print("Core      : {} deklarasi global".format(len(extracted)))
    print("Dilewati  : {} addcmd dinamis".format(len(skipped)))
    print("UNRESOLVED: {}".format(len(unresolved)))
    print("Parse gagal: {}".format(len(global_failures)))
    print("Peringatan: {}".format(len(warnings)))
    print("Laporan   : {}".format(display_path(DEFAULT_REPORT)))

    if check_result is not None:
        if not check_result["available"]:
            print("luac      : tidak ditemukan, pengecekan dilewati")
        else:
            print(
                "luac -p   : {} OK, {} Luau-only, {} gagal".format(
                    len(check_result["ok"]),
                    len(check_result["luau"]),
                    len(check_result["failed"]),
                )
            )

    if warnings:
        for warning in warnings:
            print("  ! " + warning)

    # Luau-only bukan kegagalan splitter: source upstream memang Luau.
    if warnings:
        return 1
    if check_result is not None and check_result["failed"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
