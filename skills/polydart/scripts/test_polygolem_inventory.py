#!/usr/bin/env python3
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("polygolem_inventory.py")


def load_inventory_module():
    spec = importlib.util.spec_from_file_location("polygolem_inventory", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PolygolemInventoryTest(unittest.TestCase):
    def test_builds_surface_rows_and_marks_safety_review(self):
        module = load_inventory_module()

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for path in [
                "polygolem/pkg/clob",
                "polygolem/internal/auth",
                "polygolem/internal/cli",
                "polygolem/docs",
                "lib/src/clob",
                "test/clob",
            ]:
                (root / path).mkdir(parents=True)
            (root / "polygolem/internal/cli/cmd_clob.go").write_text(
                "package cli\n"
            )
            (root / "polygolem/docs/README.md").write_text("# docs\n")
            (root / "test/clob/clob_client_test.dart").write_text(
                "void main() {}\n"
            )

            inventory = module.build_inventory(root)

        names = {row["feature"] for row in inventory["rows"]}
        self.assertIn("pkg/clob", names)
        self.assertIn("internal/auth", names)
        self.assertIn("cli/cmd_clob", names)
        self.assertIn("docs/README.md", names)

        auth_row = next(
            row for row in inventory["rows"] if row["feature"] == "internal/auth"
        )
        self.assertEqual(auth_row["safety_review"], "required")
        self.assertEqual(auth_row["polydart_path"], "")

        clob_row = next(row for row in inventory["rows"] if row["feature"] == "pkg/clob")
        self.assertEqual(clob_row["polydart_path"], "lib/src/clob")
        self.assertEqual(clob_row["tests"], "test/clob")


if __name__ == "__main__":
    unittest.main()
