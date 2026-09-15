## How to Contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Format the code with [StyLua](https://github.com/JohnnyMorganz/StyLua): `stylua .`
4. Validate the formatting: `stylua --check .`
5. Test the addon in World of Warcraft
6. Commit your changes: `git commit -m 'Add some feature'`
7. Push to the branch: `git push origin feature/your-feature`
8. Open a Pull Request

## Development Setup

1. Clone the repository: `git clone https://github.com/bellmano/MapAchiever.git`
2. Install [StyLua](https://github.com/JohnnyMorganz/StyLua) or the recommended StyLua VS Code extension
3. Run the formatter from the repository root: `stylua .`

## Code Style

- All Lua code must be formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua) before it is committed or pushed. Run `stylua .` from the repository root.
- Write meaningful commit messages

## Testing

- Test addon changes in World of Warcraft before submitting a PR
- Ensure the formatting check passes: `stylua --check .`

## Issues

If you find a bug or have a feature request, please [open an issue on GitHub](https://github.com/bellmano/MapAchiever/issues).