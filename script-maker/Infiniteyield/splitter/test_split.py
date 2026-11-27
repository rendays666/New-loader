#!/usr/bin/env python3
"""
Tes kecil untuk splitter/split.py.
Jalankan: python3 splitter/test_split.py
"""

import importlib.util
import sys
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("split.py")
SPEC = importlib.util.spec_from_file_location("iy_splitter", MODULE_PATH)
split = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = split
SPEC.loader.exec_module(split)


def parse_all(src):
    tokens = split.tokenize(src)
    results = []
    for index, token in enumerate(tokens):
        if token.kind != "name" or token.text != "addcmd":
            continue
        if index > 0 and tokens[index - 1].text in {".", ":"}:
            continue
        result = split.parse_addcmd(src, tokens, index)
        if result is not None:
            results.append(result)
    return results


class SplitterTest(unittest.TestCase):
    def test_ignores_comments_strings_and_long_strings(self):
        src = (
            '-- addcmd("commentfake", {}, function() end)\n'
            '--[[ addcmd("longcommentfake", {}, function() end) ]]\n'
            'local a = "addcmd(\'stringfake\', {}, function() end)"\n'
            'local b = [[ addcmd("longstringfake", {}, function() end) ]]\n'
            'addcmd("real", {"r", "rr"}, function(args)\n'
            '    local x = {1, {2, {3}}}\n'
            '    if args[1] then print(")") end\n'
            'end)\n'
        )
        results = parse_all(src)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["name"], "real")
        self.assertEqual(results[0]["aliases"], ["r", "rr"])
        self.assertIn("function(args)", results[0]["function"])
        self.assertTrue(results[0]["function"].endswith("end"))

    def test_luau_if_expression_backtick_and_long_string(self):
        src = (
            'addcmd("luau", {}, function(args)\n'
            '    local value = if args[1] then `hello {args[1]}` else "no"\n'
            '    local text = [==[ end addcmd("fake", {}, function() end) ]==]\n'
            '    if value then print(value) end\n'
            'end)\n'
        )
        results = parse_all(src)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["name"], "luau")
        self.assertIn("`hello", results[0]["function"])
        self.assertTrue(results[0]["function"].endswith("end"))

    def test_unbalanced_function_is_reported(self):
        src = (
            'addcmd("broken", {}, function(args)\n'
            '    if args[1] then\n'
            '        print("x")\n'
            'end)\n'
        )
        results = parse_all(src)
        self.assertEqual(len(results), 1)
        self.assertIn("error", results[0])
        self.assertIn("tidak seimbang", results[0]["error"])

    def test_dynamic_addcmd_is_skipped(self):
        src = 'addcmd(name, {}, function() end)\n'
        results = parse_all(src)
        self.assertEqual(len(results), 1)
        self.assertIn("skipped", results[0])

    def test_sanitize_filename(self):
        self.assertEqual(split.sanitize_filename("Anti-AFK"), "Anti-AFK")
        self.assertEqual(split.sanitize_filename("foo/bar"), "foo_bar")
        self.assertEqual(split.sanitize_filename("index"), "cmd_index")

    def test_extract_globals_only_top_level(self):
        src = (
            '-- function fake() end\n'
            'local function ignored() end\n'
            'local localvar = 1\n'
            'function real(a)\n'
            '    local x = {1, {2}}\n'
            '    return a\n'
            'end\n'
            'assigned = function(x) return x end\n'
            'tablev = { a = 1, b = {2} }\n'
            'inst = Instance.new("Frame")\n'
            'addcmd("cmd", {}, function(args)\n'
            '    function nested() end\n'
            'end)\n'
        )
        tokens = split.tokenize(src)
        depths = split.compute_depths(tokens)
        declarations, failures = split.extract_globals(
            src, tokens, depths
        )

        self.assertEqual(failures, [])
        self.assertEqual(
            set(declarations), {"real", "assigned", "tablev", "inst"}
        )
        self.assertEqual(declarations["real"].kind, "function")
        self.assertEqual(declarations["assigned"].kind, "function")
        self.assertTrue(declarations["assigned"].text.startswith("assigned = function"))
        self.assertEqual(declarations["tablev"].kind, "variable")
        self.assertTrue(declarations["tablev"].text.startswith("tablev = {"))

    def test_extract_globals_handles_long_comments_and_strings(self):
        src = (
            'svc = setmetatable({}, {\n'
            '    __index = function(self, name)\n'
            '        return name --[[ komentar\n'
            'multiline ]] .. "function fake() end"\n'
            '    end,\n'
            '})\n'
            'nextvar = 1\n'
        )
        tokens = split.tokenize(src)
        depths = split.compute_depths(tokens)
        declarations, failures = split.extract_globals(
            src, tokens, depths
        )

        self.assertEqual(failures, [])
        self.assertEqual(set(declarations), {"svc", "nextvar"})
        self.assertIn("multiline", declarations["svc"].text)
        self.assertNotIn("nextvar", declarations["svc"].text)

    def test_categorize(self):
        self.assertEqual(split.categorize("waypointmover"), "waypoint")
        self.assertEqual(split.categorize("WayPoints"), "waypoint")
        self.assertEqual(split.categorize("notify"), "notify")
        self.assertEqual(split.categorize("PinNotification"), "notify")
        self.assertEqual(split.categorize("getstring"), "args")
        self.assertEqual(split.categorize("getPlayer"), "args")
        self.assertEqual(split.categorize("getRoot"), "globals")

    def test_scan_identifiers_ignores_locals_fields_and_table_keys(self):
        src = (
            'local function f(a, b)\n'
            '    local x = a + b\n'
            '    obj.field = x\n'
            '    obj:method(y)\n'
            '    local t = { key = global1, [global2] = 1 }\n'
            '    return global3 + t.key\n'
            'end\n'
        )
        used = split.scan_identifiers(src)

        self.assertEqual(
            used, {"obj", "y", "global1", "global2", "global3"}
        )

    def test_dependency_closure_and_unresolved(self):
        def decl(name, deps):
            return split.GlobalDecl(name, "function", 0, "function " + name + "() end", deps)

        declarations = {
            "waypointmover": decl("waypointmover", {"getstring"}),
            "getstring": decl("getstring", set()),
            "notify": decl("notify", set()),
        }
        commands = [{
            "file": "cmd",
            "function": (
                'function(args, speaker)\n'
                '    waypointmover("x")\n'
                '    notify(getstring(1, args))\n'
                '    print(game.PlaceId)\n'
                'end'
            ),
        }]

        (
            per_command,
            extracted,
            unresolved,
            local_deps,
            _seen_used,
            users,
        ) = split.scan_dependencies(commands, declarations, {})

        self.assertEqual(extracted, {"waypointmover", "getstring", "notify"})
        self.assertEqual(unresolved, set())
        self.assertEqual(local_deps, set())
        self.assertEqual(
            per_command["cmd"],
            {"waypointmover", "notify", "getstring", "print", "game"},
        )
        self.assertIn("notify", users)


if __name__ == "__main__":
    unittest.main()
