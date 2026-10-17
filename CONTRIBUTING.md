## How to Contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and add or update tests
4. Format the code with [StyLua](https://github.com/JohnnyMorganz/StyLua): `stylua .`
5. Test the addon in World of Warcraft
6. Commit your changes: `git commit -m 'Add some feature'`
7. Push to the branch: `git push origin feature/your-feature`
8. Open a Pull Request

## Development Setup

1. Clone the repository: `git clone https://github.com/bellmano/MapAchiever.git`
2. Install [StyLua](https://github.com/JohnnyMorganz/StyLua) or the recommended StyLua VS Code extension
3. Install Lua 5.1 and LuaCov (`luarocks --lua-version=5.1 install luacov`)

## Code Style

- All Lua code must be formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua) before it is committed or pushed. Run `stylua .` from the repository root.
- Write meaningful commit messages

## Testing

- Create the coverage output directory first: `New-Item -ItemType Directory -Force coverage` in PowerShell (or `mkdir -p coverage` on Linux/macOS)
- Set LuaCov's config path to `tools/luacov.lua` before running the tests: `$env:LUACOV_CONFIG = "tools/luacov.lua"` in PowerShell (or `export LUACOV_CONFIG=tools/luacov.lua` on Linux/macOS)
- Run the automated addon tests and verify 100% line coverage with `lua5.1 -lluacov tests/run.lua`, `lua5.1 tools/sonar_coverage.lua`, and `lua5.1 tools/check_coverage.lua`
- Test addon changes in World of Warcraft before submitting a PR

## Issues

If you find a bug or have a feature request, please [open an issue on GitHub](https://github.com/bellmano/MapAchiever/issues).