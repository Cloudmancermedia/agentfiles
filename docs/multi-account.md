# Multi-account: running two Claude homes on one machine

By default agentfiles installs a single **home** — one Claude Code config
directory (`~/.claude`) bound to one profile. That is all most machines need.

This guide adds a second home so two Claude Code accounts run side by side on the
same machine, each with its own login, config, and MCP servers. The machinery
ships with agentfiles; a single home just never turns it on. Every step below is
scriptable — an agent can follow it end to end.

## What a home is

A home is a Claude Code config directory plus the account logged into it.

| Home | Directory | App-state file | Selected by |
|------|-----------|----------------|-------------|
| Default | `~/.claude` | `~/.claude.json` | nothing — the default |
| Secondary | `~/.claude-<name>` | `~/.claude-<name>/.claude.json` | `CLAUDE_CONFIG_DIR=~/.claude-<name>` |

Claude Code reads `CLAUDE_CONFIG_DIR` to decide which home to use. Unset, it uses
`~/.claude`. Set, it uses that directory — and looks for the app-state file
(`.claude.json`) *inside* it, not at `~/.claude.json`.

Which profile deploys into which home is recorded in `local/.homes` (gitignored,
per-machine):

```
# <label>  <profile>  <dir>
personal    personal   ~/.claude
work        work       ~/.claude-work
```

The binding is explicit: any profile can go to any home. The `label` names the
home (used by `bin/claude-home`) and is independent of the profile name.

## How two logins coexist (the Keychain)

Two accounts do not collide because Claude Code namespaces its Keychain
credential by config directory. The credential for a home is stored under the
service name:

```
Claude Code-credentials-<first 8 hex of sha256(CLAUDE_CONFIG_DIR)>
```

So `~/.claude` and `~/.claude-work` each get their own Keychain item. A launch
under one home reads only that home's credential and can never pick up the
other's. Both homes use an ordinary interactive `/login` — no OAuth token, no
manual credential juggling. (Observed in Claude Code 2.1.216; the per-config-dir
namespacing is what makes the whole scheme work.)

You log each home in **once**; the credential persists in the Keychain across
sessions.

## Add a second home

1. **Add a row to `local/.homes`.** Pick a label and a directory of the form
   `~/.claude-<name>`, and bind it to a profile:

   ```
   work    work    ~/.claude-work
   ```

   Any profile that ships in `profiles/` works, including `factory-zero`.

2. **Deploy it.** `sync.sh` iterates every row in `.homes`, so it creates and
   fills the new home in the same run as the existing one:

   ```bash
   ./sync.sh
   ```

   You should now see the new home in the deployment map, and `~/.claude-work/`
   populated with `CLAUDE.md`, `rules/`, `skills/`, and `settings.json`.

3. **Log the new home in once.** Launch Claude Code *inside* the new home and run
   `/login` with the account that home should use:

   ```bash
   ./bin/claude-home work
   # then, at the prompt:
   /login
   ```

   After the login completes, the credential is in the Keychain and every future
   launch of that home is authenticated.

4. **Verify.** `./status.sh` prints one block per home — dir, bound profile, and
   the logged-in account read from that home's `.claude.json`:

   ```
   [work] profile: work  ->  ~/.claude-work
       account: you@example.com (org: ...)
   ```

## Launch a specific home

`bin/claude-home <label>` looks the label up in `local/.homes`, points
`CLAUDE_CONFIG_DIR` at that home, and execs the real `claude`:

```bash
./bin/claude-home work            # launch the work home
./bin/claude-home work --resume   # extra args pass through to claude
```

If a shim named `claude` shadows the real binary on your `PATH`, point the
launcher at the real one:

```bash
CLAUDE_REAL_BIN=/path/to/real/claude ./bin/claude-home work
```

### A shell shortcut (optional)

agentfiles does not edit your shell config. If you want a short command, add a
function to `~/.zshrc` (or `~/.bashrc`) yourself:

```zsh
# Launch Claude Code in the work home.
ccw() { CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude "$@"; }
```

This is the same thing `bin/claude-home work` does; use whichever you prefer.

## Point an external tool at a home

Any tool that lets you set the Claude binary path (an IDE integration, a task
runner, a cron job) can be pinned to a home by pointing it at the launcher
instead of `claude`:

```
/path/to/agentfiles/bin/claude-home work
```

The tool then always runs under the work home. A tool left pointing at plain
`claude` uses the default home — which is why the default home should hold the
account you want unconfigured launches to land on.

## Migrating an existing single-home machine

If you installed agentfiles before the homes model, your machine has a
`local/.current-profile` file and no `local/.homes`. Nothing to do by hand:
`scripts/resolve-homes.sh` migrates it automatically the first time any
entrypoint runs, writing a one-row `.homes` that binds the default home to your
current profile. Confirm it:

```bash
./scripts/resolve-homes.sh
cat local/.homes
```

If you had set up a second home manually (a `~/.claude-<name>` directory you
created yourself), add its row to `local/.homes` and run `./sync.sh` to bring it
under management. The directory is reused in place — `sync.sh` tears it down to
factory-zero and redeploys, so back up anything in it you want to keep first
(session state under `.claude-<name>/` is user data agentfiles does not manage).

## Remove a home

Delete its row from `local/.homes`. `sync.sh` no longer touches that directory,
but it also does not delete it — remove `~/.claude-<name>` by hand if you want it
gone, and log its account out first if you no longer need the credential.
