import importlib.util
import json
import plistlib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("sgen_assembler", ROOT / "assemble.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
catalog = json.loads((ROOT / "action-catalog.json").read_text(encoding="utf-8"))

class AssemblyTests(unittest.TestCase):
    def compile(self, recipe):
        return mod.Assembler(catalog, target=recipe.get("ios", 27)).build(recipe)

    def test_complex_recipe(self):
        recipe = json.loads((ROOT / "examples" / "centre-iphone.json").read_text(encoding="utf-8"))
        result = self.compile(recipe)
        actions = result["WFWorkflowActions"]
        self.assertGreaterEqual(len(actions), 20)
        self.assertEqual(result["WFWorkflowName"], "Centre de commandes iPhone")
        self.assertTrue(mod.validate_graph(result))
        self.assertEqual(plistlib.loads(plistlib.dumps(result))["WFWorkflowName"], result["WFWorkflowName"])

    def test_linked_output_ref(self):
        p = self.compile({"name":"Demo","ios":27,"actions":[
            {"action":"text","as":"hello","params":{"text":"Bonjour"}},
            {"action":"show","params":{"source":{"ref":"hello"}}}
        ]})
        first, second = p["WFWorkflowActions"]
        u = first["WFWorkflowActionParameters"]["UUID"]
        self.assertEqual(second["WFWorkflowActionParameters"]["Text"]["Value"]["attachmentsByRange"]["{0, 1}"]["OutputUUID"], u)

    def test_unknown_action_rejected(self):
        with self.assertRaises(mod.BuildError):
            self.compile({"name":"Demo","ios":27,"actions":[{"action":"unknown"}]})

    def test_missing_reference_rejected(self):
        with self.assertRaises(mod.BuildError):
            self.compile({"name":"Demo","ios":27,"actions":[
                {"action":"show","params":{"source":{"ref":"non_existant"}}}
            ]})

    def test_invalid_menu_rejected(self):
        with self.assertRaises(mod.BuildError):
            self.compile({"name":"Demo","ios":27,"actions":[
                {"menu":{"cases":[{"title":"A","actions":[]},{"title":"A","actions":[]}]}}
            ]})

    def test_target_guard(self):
        with self.assertRaises(mod.BuildError):
            mod.Assembler(catalog, target=26).build({"name":"Demo","ios":26,"actions":[
                {"action":"text","as":"s","params":{"text":"X"}},
                {"action":"extract_text","as":"r","params":{"source":{"ref":"s"}}}
            ]})

if __name__ == "__main__":
    unittest.main()
