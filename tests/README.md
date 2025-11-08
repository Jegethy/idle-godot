# Tests

This directory contains test scripts for validating game systems.

## Running Tests

Since this is a Godot project without a formal testing framework yet, tests can be run manually:

### Option 1: Using Godot Editor
1. Open the test file in the Godot editor
2. Click the "Run" icon in the script editor toolbar
3. Check the output console for results

### Option 2: Using Command Line (if Godot is in PATH)
```bash
godot --headless --script tests/test_validation.gd
```

## Test Files

- `test_validation.gd` - Basic validation tests for PR1 scaffold
  - Verifies singletons are loaded
  - Tests resource model calculations
  - Tests upgrade model cost scaling
  - Tests economy calculations
  - Tests save schema serialization

## Future Testing

Consider adding:
- GUT (Godot Unit Testing) framework for more comprehensive testing
- Integration tests for save/load cycles
- Performance tests for large-scale calculations
- Combat simulation tests with seeded RNG
