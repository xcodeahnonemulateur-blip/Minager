#!/usr/bin/env python3
"""Compilateur SGEN v0.1 vers un fichier Apple .shortcut NON SIGNÉ."""
import argparse
import json
import plistlib
import re
import shlex
import sys
from pathlib import Path

class ShortcutError(ValueError):
    pass

def action(identifier, params):
    return {"WFWorkflowActionIdentifier": identifier, "WFWorkflowActionParameters": params}

def args_for(command, payload, n, lengths):
    try:
        args = shlex.split(payload)
    except ValueError as e:
        raise ShortcutError(f"Ligne {n}: guillemets invalides: {e}") from e
    if len(args) not in lengths:
        raise ShortcutError(f"Ligne {n}: {command} attend {lengths} arguments (reçu: {len(args)})")
    return args

def parse_sgen(source):
    name = "Mon raccourci"
    actions = []
    previous_text = None
    for n, raw in enumerate(source.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        command, _, payload = line.partition(" ")
        command = command.upper()
        payload = payload.strip()
        if command == "NOM":
            name = args_for(command, payload, n, (1,))[0]
        elif command == "TEXTE":
            previous_text = args_for(command, payload, n, (1,))[0]
            actions.append(action("is.workflow.actions.gettext", {"WFTextActionText": previous_text}))
        elif command == "AFFICHER":
            values = args_for(command, payload, n, (0, 1))
            message = values[0] if values else previous_text
            if message is None:
                raise ShortcutError(f"Ligne {n}: écrire TEXTE avant AFFICHER")
            actions.append(action("is.workflow.actions.showresult", {"Text": message}))
        elif command == "NOTIFIER":
            title, body = args_for(command, payload, n, (2,))
            actions.append(action("is.workflow.actions.notification", {
                "WFNotificationActionTitle": title,
                "WFNotificationActionBody": body,
            }))
        elif command == "ALERTE":
            title, body = args_for(command, payload, n, (2,))
            actions.append(action("is.workflow.actions.alert", {
                "WFAlertActionTitle": title,
                "WFAlertActionMessage": body,
            }))
        elif command == "ACTION":
            identifier, separator, json_payload = payload.partition(" ")
            if not separator or not re.fullmatch(r"[A-Za-z0-9_.-]+", identifier):
                raise ShortcutError(f"Ligne {n}: ACTION identifiant {{paramètres JSON}}")
            try:
                parameters = json.loads(json_payload)
            except json.JSONDecodeError as e:
                raise ShortcutError(f"Ligne {n}: JSON invalide: {e}") from e
            if not isinstance(parameters, dict):
                raise ShortcutError(f"Ligne {n}: paramètres attendus sous forme d'objet JSON")
            actions.append(action(identifier, parameters))
        else:
            raise ShortcutError(f"Ligne {n}: instruction inconnue: {command}")
    if not actions:
        raise ShortcutError("Aucune action dans le raccourci")
    return name, actions

def compile_shortcut(source):
    name, actions = parse_sgen(source)
    data = {
        "WFWorkflowName": name,
        "WFWorkflowActions": actions,
        "WFWorkflowClientVersion": "2700.0.4",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowHasOutputFallback": False,
        "WFWorkflowIcon": {
            "WFWorkflowIconStartColor": 4282601983,
            "WFWorkflowIconGlyphNumber": 59511,
        },
        "WFWorkflowImportQuestions": [],
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowTypes": [],
        "WFQuickActionSurfaces": [],
    }
    return plistlib.dumps(data, fmt=plistlib.FMT_BINARY)

def main():
    parser = argparse.ArgumentParser(description="SGEN -> Apple .shortcut NON SIGNÉ")
    parser.add_argument("source", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    options = parser.parse_args()
    try:
        payload = compile_shortcut(options.source.read_text(encoding="utf-8"))
        options.output.parent.mkdir(parents=True, exist_ok=True)
        options.output.write_bytes(payload)
    except (ShortcutError, OSError) as e:
        print(f"ERREUR: {e}", file=sys.stderr)
        return 1
    print(f"Créé: {options.output} (NON SIGNÉ, import impossible sur iPhone)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
