## How to Contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and add or update tests
4. Run the tests: `busted --coverage tests/MapAchiever.test.lua`
5. Commit your changes: `git commit -m 'Add some feature'`
6. Push to the branch: `git push origin feature/your-feature`
7. Open a Pull Request

## Development Setup

1. Clone the repository: `git clone https://github.com/bellmano/MapAchiever.git`
2. Install [Lua](https://www.lua.org/download.html) and [LuaRocks](https://luarocks.org/)
3. Install test dependencies:
   ```bash
   luarocks install busted
   luarocks install luacov
   luarocks install luacov-reporter-lcov
   ```

## Testing

- Tests are written in [busted](https://lunarmodules.github.io/busted/) and live in the `tests/` folder
- Add or update unit tests in `tests/MapAchiever.test.lua` for any new features or bug fixes
- Run tests: `busted --coverage tests/MapAchiever.test.lua`
- Generate a coverage report: `luacov` (output: `luacov.report.out`)
- Ensure all tests pass before submitting a PR

## Issues

If you find a bug or have a feature request, please [open an issue](https://github.com/bellmano/MapAchiever/issues).