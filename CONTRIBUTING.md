# Contributing

Thanks for your interest in improving claudefiles!

## How to Contribute

### Reporting Issues
- Open a GitHub issue describing the problem or suggestion
- Include your OS, shell, and Claude Code version if relevant

### Pull Requests
- Fork the repo and create a branch for your change
- Keep changes focused — one feature or fix per PR
- Test your changes on a fresh clone if possible (run `./install.sh` and verify the workflow)
- Update the README if your change affects usage

### What Makes a Good Contribution
- **Script improvements** — Better error handling, new variable substitution, cross-platform support
- **Documentation** — Clearer explanations, new examples, common recipes
- **Example rules** — Well-written rule files that others can learn from (put these in `base/rules/` or a profile's `rules/` directory)

### What to Avoid
- Don't submit your personal configuration as a PR — this repo ships example content, not anyone's actual setup
- Don't add external dependencies beyond `jq` and standard Unix tools

## Security

If you find a security issue (e.g., the sync scripts could leak credentials), please open a GitHub issue or contact the maintainer directly. This is a configuration management tool — it should never handle or expose secrets.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
