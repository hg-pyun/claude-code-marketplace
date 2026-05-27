# REPLACE-WITH-PLUGIN-NAME — Plugin Working Guide

<!--
  Per-plugin working guide, auto-loaded when Claude works inside this plugin dir.
  Repo-wide governance (versioning, author field, 9-section house style,
  settings.language) lives in the root CLAUDE.md — do NOT duplicate it here.
  Keep this file lean (it is injected every session); link to the root for rules.
  This marketplace uses a 2-surface model per plugin: CLAUDE.md + README.md
  (no SPEC.md). Fill the sections below with this plugin's specifics.
-->

Repo-wide governance lives in the root [CLAUDE.md](../../CLAUDE.md); this file is the working guide for this plugin.

## Structure
<!-- Directory tree of this plugin (agents/ commands/ skills/ as applicable). -->

## Agent / skill / command boundary
<!-- What this plugin ships and where each kind of asset lives. -->

## Conventions
<!-- Plugin-specific conventions: Task(subagent_type=...) usage, MCP deps, $LANGUAGE. -->

## Adding a skill or command
<!-- 1. Author in the 9-section XML house style.
     2. Bump version in BOTH plugin.json and the marketplace.json entry (same value).
     3. bash scripts/validate.sh — exit 0 is the gate. -->

## Debugging
<!-- Common failure modes specific to this plugin and their fixes. -->
