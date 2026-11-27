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


if __name__ == "__main__":
    unittest.main()
