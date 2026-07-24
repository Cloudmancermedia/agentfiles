# Multi-account: running two Claude accounts on one machine

By default agentfiles installs a single **home** — one Claude Code config
directory (`~/.claude`) bound to one profile. That is all most machines need.

This guide adds a second home so two Claude Code accounts run side by side on the
same machine, each with its own login, config, and MCP servers. The machinery
ships with agentfiles; a single home just never turns it on. Every step below is
scriptable — an agent can follow it end to end.

> **Scope: Claude Code only.**
> Multi-home support is built for Claude Code, and that is the only tool it has
> been tested with. Codex CLI is deliberately single-home — `sync.sh` deploys it
> once from the default profile into `~/.codex`. See
> [Codex and multi-account](#codex-and-multi-account) before you try to run two
> Codex accounts this way.

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

### Which account belongs in the default home

Put the account you want **unconfigured launches** to land on in `~/.claude`.

Anything that runs `claude` without setting `CLAUDE_CONFIG_DIR` — an IDE
integration, a cron job, a script, a tool with its own shim — gets the default
home. That is the safer default for your personal account: a forgotten launcher
falls back to personal rather than silently doing work under a work seat. The
secondary home then requires an explicit opt-in every time.

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
manual credential juggling.

You log each home in **once**; the credential persists in the Keychain across
sessions.

### Verify it yourself

Derive the service name from a home directory and confirm the item exists. This
prints no secret:

```bash
HOME_DIR="$HOME/.claude-work"
HEX=$(printf '%s' "$HOME_DIR" | shasum -a 256 | cut -c1-8)
security find-generic-password -s "Claude Code-credentials-$HEX" >/dev/null \
  && echo "credential present for $HOME_DIR ($HEX)" \
  || echo "no credential yet for $HOME_DIR ($HEX) — run /login in that home"
```

Run it against `$HOME/.claude` too. Two different hex suffixes, two separate
items, one per account. (Verified on Claude Code 2.1.216; the per-config-dir
namespacing is what makes the whole scheme work. If a future version changes it,
this check is how you find out.)

## Why not an OAuth token

`claude setup-token` mints a long-lived `CLAUDE_CODE_OAUTH_TOKEN`, and it looks
like the obvious way to pin a second account. Do not use it for this. It costs
you subscription features, and it is not needed.

**It is unnecessary.** The whole reason a token seemed required was the belief
that macOS holds exactly one Claude Code credential slot, so two interactive
logins would overwrite each other. That is false — the Keychain item is keyed by
config directory, as the check above demonstrates. Two interactive logins coexist
without help.

**It actively costs you.** `CLAUDE_CODE_OAUTH_TOKEN` outranks the Keychain in
Claude Code's auth precedence, so setting it means the token wins even when a
perfectly good subscription login exists in that home. A token session does not
carry the seat's subscription entitlements the way an interactive login does, and
two things break as a result:

- **The newest models fall back to usage-credit billing** instead of running under
  the subscription, because the session's model-access cache comes back empty.
- **claude.ai connectors never load.** They are subscription-only, so a
  token-authenticated home simply does not see them. Working around that means
  re-registering each connector as a local MCP server in that profile — real
  ongoing maintenance, for no gain.

So: both homes use interactive Keychain login. Separation comes from the
per-config-dir namespacing, not from a token.

If you previously set this up with a token, remove `CLAUDE_CODE_OAUTH_TOKEN` from
your shell config and any launcher, log the home in interactively, confirm the
newest models and your connectors are available, then revoke the old token in your
claude.ai account settings.

## Profiles are behavior; accounts are engine settings

Once you have two accounts, a distinction matters that a single-home machine never
forces you to make.

A **profile** describes how the agent should behave: rules, skills, MCP servers,
CLAUDE.md, output style. You swap profiles freely, and you might mount the same
profile on both accounts.

An **account** — a home — has properties that belong to the seat itself, not to
any behavior you mount on it: which model it may run, and how much reasoning
effort you want to spend. Those follow the account's plan and limits. If one seat
is on a bigger plan than the other, that is a fact about the seat, and it should
not change just because you switched which rules you're using.

So settings deploy in three layers:

```
base/settings.json                  shared defaults
  -> profiles/<name>/settings.json  behavior for this profile
    -> homes/<label>/settings.json  engine settings for this account   (wins)
```

The home layer merges **last**, keyed by home label rather than profile name.
Mounting a different profile on an account never changes that account's model or
effort level.

```
homes/
  personal/settings.json
  work/settings.json
```

```json
{
  "model": "claude-opus-5",
  "effortLevel": "medium"
}
```

Keep these files small. Anything that is really about behavior belongs in a
profile, where it can be reused across accounts. A good test: if you would want
the setting to follow you when you switch profiles, it is an account setting; if
it should change with the profile, it belongs in the profile.

An absent `homes/<label>/settings.json` is a no-op — you only need the file for
accounts you actually want to pin. `factory-zero` skips this layer entirely, so
the clean-baseline profile stays unsteered.

Deploy prints what it applied, and verification asserts every key survived:

```
  -> home settings overlay merged (work): model, effortLevel
  [ok] home settings overlay (work) applied
```

`homes/` is committed to the repo, so both machines agree on which account runs
what. The label must match the label in `local/.homes`. When you run
`deploy-profile.sh` directly without `CLAUDE_HOME_LABEL`, it derives the label
from the home directory: `~/.claude` is `personal`, and `~/.claude-<name>` is
`<name>`.

### Worked example

Say the three layers disagree about `model`:

| Layer | File | `model` | `outputStyle` |
|---|---|---|---|
| base | `base/settings.json` | `claude-haiku-4-5-20251001` | — |
| profile | `profiles/work/settings.json` | `claude-sonnet-5` | `eli5` |
| account | `homes/work/settings.json` | `claude-opus-5` | — |

Deployed to `~/.claude-work/settings.json`:

```json
{
  "model": "claude-opus-5",
  "outputStyle": "eli5"
}
```

The account layer wins `model` because it merges last. `outputStyle` survives
untouched — the account layer only overrides keys it actually names, so a profile
keeps everything the account is silent about.

### Why this makes profile switches model-safe

Before this layer existed, the model lived in whichever settings file happened to
deploy last, which meant a profile carried it. Switching profiles to try out
different rules silently switched your model too, and you could not tell which
change caused a difference in behavior.

Now `./switch-profile.sh work personal` rebinds the work home to the personal
profile — different rules, different skills, different MCP servers — and the work
account keeps running the model its own file names. The two axes move
independently.

That also makes `factory-zero` usable as a benchmark control. It short-circuits
above every layer, so it deploys no rules, no skills, and no account overlay —
whatever you measure against it is the unsteered baseline.

### Recipe: try a new model on one account

```bash
# 1. Edit that account's engine settings.
vim homes/work/settings.json      # "model": "<the new model>"

# 2. Redeploy.
./sync.sh
```

That is the whole change, and it survives every future sync because the repo is
the source. Editing `~/.claude-work/settings.json` directly would work until the
next deploy overwrote it.

To try the new model on every account, put it in `base/settings.json` instead and
leave the `homes/` files silent on `model`.

## What is per-home and what is shared

| Thing | Scope | Why |
|---|---|---|
| `model`, `effortLevel` | **Per-account** (`homes/<label>/`) | Follows the seat's plan, not the mounted profile |
| `CLAUDE.md`, `rules/`, output styles | Per-profile, deployed per-home | The two profiles differ by design — different rules, different personas |
| MCP servers, hooks | Per-profile, deployed per-home | Work servers must not appear in a personal session |
| Skills | **Shared store, per-home symlinks** | Stored once on disk; each home links only what its profile allows |
| Session history (`projects/`, `history.jsonl`, `todos/`) | Per-home | Deliberate — see below |
| Keychain credential | Per-home | Namespaced by config dir |

### Skills use a shared store

Skills live once at `~/.claude-shared/skills/`, materialized by
`scripts/deploy-shared-skills.sh`. Each home then gets per-skill symlinks into
that store, driven by its own profile allowlist. A skill you use in both homes is
one copy on disk, and a work-only skill never appears in the personal home's skill
surface.

The store deliberately sits outside both homes. A home is a deploy target that
gets torn down and rebuilt on every sync, so symlinks pointing into one home would
dangle mid-deploy; and one home's `skills/` directory is that account's live skill
surface, which should not be forced to hold the union of every home's skills.

### Session history stays separate

`projects/`, `history.jsonl`, and `todos/` are per-home on purpose. There is no
shared transcript pool: `--resume` in the work home lists only work sessions, and
work and personal transcripts never mix on disk. This is user data, not
configuration — agentfiles does not manage, sync, or back it up.

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

   For a credential-level check, use the `security find-generic-password` snippet
   in [Verify it yourself](#verify-it-yourself).

## Launch a specific home

`bin/claude-home <label>` looks the label up in `local/.homes`, points
`CLAUDE_CONFIG_DIR` at that home, and execs the real `claude`:

```bash
./bin/claude-home work            # launch the work home
./bin/claude-home work --resume   # extra args pass through to claude
```

Run with no arguments to list the homes it knows about.

### When a shim shadows the real binary

Some tools install their own wrapper named `claude` earlier on your `PATH`. The
launcher skips itself when searching, but it cannot recognize every third-party
shim — and exec'ing one can loop back into the wrapper. If that happens, name the
real binary explicitly:

```bash
CLAUDE_REAL_BIN=/path/to/real/claude ./bin/claude-home work
```

`which -a claude` shows you every candidate on `PATH` so you can pick the right
one.

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

## Codex and multi-account

Multi-home is a Claude Code feature here. `sync.sh` deploys Codex once, from the
default profile, into `~/.codex`:

```
Codex    <default profile>  ->  ~/.codex
```

Adding rows to `local/.homes` does not create additional Codex configurations.

**This is untested territory.** Everything else in agentfiles — profiles, rules,
skills, MCP servers — has been exercised against both Claude Code and Codex CLI.
Dual-account has only been tested with Claude Code. Codex handles authentication
and config discovery differently, so do not assume the pattern in this document
transfers:

- Codex may not honor a per-config-directory credential split the way Claude Code
  does, so two Codex accounts may not stay separated by pointing at two
  directories.
- There is no Codex equivalent of `bin/claude-home` in this repo.

If you need two Codex accounts, treat it as unsolved and verify the isolation
yourself before trusting it with work material. Reports of what you find are
welcome.

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

To drop the stored credential as well:

```bash
HEX=$(printf '%s' "$HOME/.claude-work" | shasum -a 256 | cut -c1-8)
security delete-generic-password -s "Claude Code-credentials-$HEX"
```

## Related documentation

- [README — Use Cases](../README.md#use-cases) — where multi-account fits among
  the other reasons to use agentfiles
- [Customization guide](customization.md) — profiles, rules, and skill allowlists,
  which decide what each home receives
