# Submitting Issues

When submitting issues for Jecs, please follow these guidelines to help us understand and address your concerns effectively.

## Issue Types

We use different templates for different types of issues:

1. **Bug Reports**: For reporting bugs or unexpected behavior
2. **Feature Requests**: For suggesting new features or improvements
3. **Documentation**: For documentation-related issues

## Before Submitting

1. Search existing issues to avoid duplicates
2. Check the documentation to ensure the behavior isn't intended
3. Try the latest version to see if the issue persists

## Bug Reports

When submitting a bug report:

1. Use the bug report template
2. Include a clear description of the problem
3. Provide reproduction steps
4. Include code examples
5. Specify your environment:
   - Jecs version
   - Roblox version
   - Platform (Luau/TypeScript)

Example bug report:
```markdown
**Description**
Query iterator crashes when using relationship components

**Steps to Reproduce**
1. Create a world
2. Add relationship components
3. Query for relationships
4. Iterate results

**Code Example**
```lua
local world = jecs.World.new()
local ChildOf = world:component()
-- ... rest of reproduction code
```

**Expected Behavior**
Query should iterate through all matching entities

**Actual Behavior**
Query crashes with error: ...
```

## Feature Requests

When requesting features:

1. Use the feature request template
2. Explain the use case
3. Provide example usage
4. Consider implementation details
5. Discuss alternatives considered

## Documentation Issues

For documentation issues:

1. Specify the affected documentation section
2. Explain what needs to be changed
3. Provide suggested improvements
4. Include examples if relevant

## Labels

Common issue labels:

- `bug`: Bug reports
- `enhancement`: Feature requests
- `documentation`: Documentation issues
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention needed