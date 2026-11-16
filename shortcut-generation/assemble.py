#!/usr/bin/env python3
"""SGEN v0.2: compile a curated JSON recipe to an UNSIGNED Apple Shortcuts plist.
Pure Python, no paid services. This is NOT a shortcut signer or iOS emulator.
"""
import argparse
import json
import plistlib
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MARKER = "\ufffc"

class BuildError(ValueError):
    pass

def uid():
    return str(uuid.uuid4()).upper()

def attachment(source):
    return {"Value": {"Type": "ActionOutput",
                      "OutputUUID": source["uuid"], "OutputName": source["output"]},
            "WFSerializationType": "WFTextTokenAttachment"}

def display_token(source):
    return {"Value": {"string": MARKER,
                      "attachmentsByRange": {"{0, 1}": {
                          "Type": "ActionOutput", "OutputUUID": source["uuid"],
                          "OutputName": source["output"]}}},
            "WFSerializationType": "WFTextTokenString"}

def wf_action(identifier, parameters=None):
    return {"WFWorkflowActionIdentifier": identifier,
            "WFWorkflowActionParameters": dict(parameters or {})}

class Assembler:
    def __init__(self, catalog, target=27):
        self.catalog = catalog["actions"]
        self.target = target
        self.bindings = {}
        self.result = []

    def reference(self, value):
        if not isinstance(value, dict) or set(value) != {"ref"}:
            raise BuildError("Référence attendue: {\"ref\": \"nom_de_l_action\"}")
        name = value["ref"]
        if name not in self.bindings:
            raise BuildError("Référence inconnue ou située après son utilisation: " + str(name))
        return self.bindings[name]

    def emit_action(self, node):
        key = node.get("action")
        if key not in self.catalog:
            raise BuildError("Action absente du catalogue: " + str(key))
        schema = self.catalog[key]
        if self.target < schema.get("min_ios", 0):
            raise BuildError(str(key) + " requiert iOS " + str(schema["min_ios"]))
        values = node.get("params", {})
        if not isinstance(values, dict):
            raise BuildError("params doit être un objet")
        unknown = set(values) - set(schema["parameters"])
        if unknown:
            raise BuildError("Paramètres inconnus pour " + key + ": " + ", ".join(sorted(unknown)))
        missing = set(schema.get("required", [])) - set(values)
        if missing:
            raise BuildError("Paramètres requis pour " + key + ": " + ", ".join(sorted(missing)))
        params = dict(schema.get("defaults", {}))
        params["UUID"] = uid()
        for friendly, val in values.items():
            wf_key = schema["parameters"][friendly]
            if isinstance(val, dict) and "ref" in val:
                upstream = self.reference(val)
                params[wf_key] = (display_token(upstream) if
                                  wf_key in schema.get("display_parameters", [])
                                  else attachment(upstream))
            elif isinstance(val, (str, bool, int, float)):
                params[wf_key] = val
            else:
                raise BuildError("Type de paramètre invalide : " + friendly)
        self.result.append(wf_action(schema["identifier"], params))
        alias = node.get("as")
        if alias:
            if not isinstance(alias, str) or not alias.isidentifier():
                raise BuildError("Alias invalide: " + str(alias))
            if alias in self.bindings:
                raise BuildError("Alias déjà utilisé: " + alias)
            if not schema.get("output"):
                raise BuildError("Action sans sortie: " + key)
            self.bindings[alias] = {"uuid": params["UUID"], "output": schema["output"]}

    def emit_menu(self, node):
        cases = node["menu"].get("cases")
        if not isinstance(cases, list) or len(cases) < 2:
            raise BuildError("Un menu nécessite au moins deux choix")
        titles = [case.get("title") for case in cases]
        if any(not isinstance(t, str) or not t.strip() for t in titles):
            raise BuildError("Titre de choix vide ou invalide")
        if len(set(titles)) != len(titles):
            raise BuildError("Titres de choix répétés")
        self.emit_action({"action":"comment","params":{"text":"Menu principal : choisir une fonction."}})
        group = uid()
        ident = "is.workflow.actions.choosefrommenu"
        self.result.append(wf_action(ident, {"GroupingIdentifier": group,
                                            "WFControlFlowMode": 0,
                                            "WFMenuPrompt": node["menu"].get("prompt", "Choisis une option"),
                                            "WFMenuItems": titles}))
        for case in cases:
            self.result.append(wf_action(ident, {"GroupingIdentifier": group,
                                                "WFControlFlowMode": 1,
                                                "WFMenuItemTitle": case["title"]}))
            self.emit_many(case["actions"])
        self.result.append(wf_action(ident, {"GroupingIdentifier": group, "WFControlFlowMode": 2}))

    def emit_if(self, node):
        spec = node["if_present"]
        upstream = self.reference({"ref": spec["ref"]})
        group = uid()
        ident = "is.workflow.actions.conditional"
        self.result.append(wf_action(ident, {
            "GroupingIdentifier": group, "WFControlFlowMode": 0,
            "WFCondition": 100,
            "WFInput": {"Type": "Variable", "Variable": attachment(upstream)}}))
        self.emit_many(spec.get("then", []))
        if spec.get("else"):
            self.result.append(wf_action(ident, {
                "GroupingIdentifier": group, "WFControlFlowMode": 1}))
            self.emit_many(spec["else"])
        self.result.append(wf_action(ident, {
            "GroupingIdentifier": group, "WFControlFlowMode": 2}))

    def emit_many(self, nodes):
        if not isinstance(nodes, list):
            raise BuildError("actions doit être une liste")
        for node in nodes:
            if not isinstance(node, dict):
                raise BuildError("Chaque bloc doit être un objet")
            kinds = set(node) & {"action", "menu", "if_present"}
            if len(kinds) != 1:
                raise BuildError("Un seul type de bloc par élément")
            if "action" in node:
                self.emit_action(node)
            elif "menu" in node:
                self.emit_menu(node)
            else:
                self.emit_if(node)

    def build(self, recipe):
        if not isinstance(recipe.get("name"), str) or not recipe["name"].strip():
            raise BuildError("name est obligatoire")
        if recipe.get("ios", 27) != self.target:
            raise BuildError("La version iOS de la recette ne correspond pas à la cible")
        self.emit_many(recipe.get("actions", []))
        if not self.result:
            raise BuildError("Aucune action à compiler")
        plist = {
            "WFWorkflowName": recipe["name"],
            "WFWorkflowClientVersion": "2700.0.4",
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowHasOutputFallback": False,
            "WFWorkflowIcon": {
                "WFWorkflowIconGlyphNumber": 59511,
                "WFWorkflowIconStartColor": 4282601983
            },
            "WFWorkflowImportQuestions": [],
            "WFWorkflowInputContentItemClasses": [],
            "WFWorkflowOutputContentItemClasses": [],
            "WFWorkflowTypes": [],
            "WFWorkflowActions": self.result
        }
        validate_graph(plist)
        return plist

def validate_graph(plist):
    """Check control-flow pairing and that every referenced output was emitted first."""
    seen = set()
    stack = []
    for idx, item in enumerate(plist["WFWorkflowActions"]):
        p = item["WFWorkflowActionParameters"]
        ident = item["WFWorkflowActionIdentifier"]
        if ident.endswith(("choosefrommenu", "conditional")):
            mode = p["WFControlFlowMode"]
            group = p["GroupingIdentifier"]
            if mode == 0:
                stack.append((ident, group))
            elif not stack or stack[-1] != (ident, group):
                raise BuildError("Structure de menu/condition invalide au bloc " + str(idx))
            elif mode == 2:
                stack.pop()
        def walk(value):
            if isinstance(value, dict):
                if value.get("Type") == "ActionOutput" and value.get("OutputUUID") not in seen:
                    raise BuildError("Variable non définie avant le bloc " + str(idx))
                for v in value.values():
                    walk(v)
            elif isinstance(value, list):
                for v in value:
                    walk(v)
        walk(p)
        if "UUID" in p:
            if p["UUID"] in seen:
                raise BuildError("UUID dupliqué")
            seen.add(p["UUID"])
    if stack:
        raise BuildError("Blocs de contrôle non fermés")
    return True

def main():
    parser = argparse.ArgumentParser(description="Assemble une recette JSON en .shortcut NON SIGNÉ")
    parser.add_argument("recipe", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, default=ROOT / "action-catalog.json")
    args = parser.parse_args()
    try:
        recipe = json.loads(args.recipe.read_text(encoding="utf-8"))
        catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
        plist = Assembler(catalog, target=recipe.get("ios", 27)).build(recipe)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(plistlib.dumps(plist, fmt=plistlib.FMT_BINARY))
        print("OK:", len(plist["WFWorkflowActions"]), "blocs ->", args.output)
        print("NON SIGNÉ : import direct sur iPhone impossible.")
    except (BuildError, OSError, ValueError) as exc:
        parser.exit(1, "ERREUR : " + str(exc) + "\n")

if __name__ == "__main__":
    main()
