import importlib.util
import plistlib
import unittest
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "compile.py"
spec = importlib.util.spec_from_file_location("sgen", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Tests(unittest.TestCase):
    def test_text(self):
        data = plistlib.loads(module.compile_shortcut('NOM "Bonjour"\nTEXTE "Salut"\nAFFICHER'))
        self.assertEqual(data["WFWorkflowName"], "Bonjour")
        self.assertEqual(len(data["WFWorkflowActions"]), 2)
        self.assertEqual(data["WFWorkflowActions"][0]["WFWorkflowActionIdentifier"], "is.workflow.actions.gettext")

    def test_notify(self):
        data = plistlib.loads(module.compile_shortcut('NOTIFIER "A" "B"'))
        self.assertEqual(data["WFWorkflowActions"][0]["WFWorkflowActionParameters"]["WFNotificationActionBody"], "B")

    def test_raw_action(self):
        data = plistlib.loads(module.compile_shortcut('ACTION is.workflow.actions.showresult {"Text":"Hello"}'))
        self.assertEqual(data["WFWorkflowActions"][0]["WFWorkflowActionParameters"]["Text"], "Hello")

    def test_unknown(self):
        with self.assertRaises(module.ShortcutError):
            module.compile_shortcut("INCONNU 123")

    def test_empty(self):
        with self.assertRaises(module.ShortcutError):
            module.compile_shortcut('NOM "Vide"')

if __name__ == "__main__":
    unittest.main()
