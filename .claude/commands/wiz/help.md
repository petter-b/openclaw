---
description: List available wizard commands
---

# Wizard Commands

Show available wizard commands to the user.

## Instructions

Display this help information:

---

## Wizard Commands (`/wiz:*`)

Summon domain-expert wizards for interactive sessions. Each wizard primes the agent with deep knowledge before you ask questions.

| Command | Domain | Description |
|---------|--------|-------------|
| `/wiz:core [path]` | Architecture | OpenClaw product internals: gateway, agents, providers, data flow |
| `/wiz:workflow [path]` | Dev Process | Development workflow, hotfixes, releases, project management |
| `/wiz:help` | - | This help |

## Usage

```bash
# Prime for architecture questions (silent mode)
/wiz:core

# Prime and display report to screen
/wiz:core /dev/stdout

# Prime and save report to file
/wiz:core /tmp/architecture-report.txt

# Prime for workflow/project questions
/wiz:workflow
```

## How It Works

1. Agent explores relevant files and documentation
2. Builds internal understanding of the domain
3. Generates comprehensive report
4. Writes report to specified path:
   - `/dev/null` (default): Silent mode, just confirms primed
   - `/dev/stdout`: Displays report to screen
   - Any other path: Saves report to that file
5. Ready for interactive Q&A session

## Examples

```
> /wiz:core
Primed for OpenClaw architecture questions.

> How does message routing work?
[Agent answers with specific file references from exploration]

> /wiz:workflow /dev/stdout
Dev Workflow Primed
===================
[Full summary shown]
...

> /wiz:core /tmp/arch.txt
Report written to /tmp/arch.txt. Primed for OpenClaw architecture questions.
```

---
