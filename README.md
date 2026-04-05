If you are only interested in using `ms-rust` skill in Claude:
1. Download the folder `ms_rust_skill/ms-rust` in `%userprofile%/.claude/skills` (alternatively in `~/.claude/skills`)
1. `/clear` - to force claude to list the skills
1. `/skills` - just to check `ms-rust` appears in the list

The `ms-rust` is automatically invoqued when you ask Claude to write/modify Rust code.


Read the Companion Web Page on [40tude](https://www.40tude.fr/docs/06_programmation/rust/019_ms_rust/ms_rust.html).

## Usage
```powershell
.\new-skill.ps1                # normal run, `ms-rust/` is created/overwritten
.\new-skill.ps1 -Help          # print usage and exit 0
.\new-skill.ps1 -Verbose       # print diagnostic lines during processing
```