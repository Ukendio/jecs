# Submitting Pull Requests

This guide will help you submit effective pull requests to Jecs.

## Before Creating a PR

1. Create an issue for discussion if one doesn't exist
2. Fork the repository
3. Create a feature branch
4. Ensure tests pass
5. Update documentation

## PR Guidelines

### Branch Naming

Use descriptive branch names:
- `feature/description`
- `fix/issue-description`
- `docs/update-section`

Example: `feature/add-relationship-caching`

### PR Description

Use the PR template and include:

1. Brief description of changes
2. Link to related issues
3. Breaking changes (if any)
4. Testing performed
5. Documentation updates

Example:
```markdown
## Description
Add caching support for relationship queries

Fixes #123

## Changes
- Implement query result caching
- Add cache invalidation
- Update documentation

## Breaking Changes
None

## Testing
- Added unit tests
- Performed performance benchmarks
- Tested with example project
```

### Code Review Process

1. Submit draft PR early for feedback
2. Address review comments
3. Keep commits focused and clean
4. Rebase on main when needed
5. Ensure CI passes

### Testing Requirements

- Add/update unit tests
- Test both Luau and TypeScript
- Include performance tests if relevant
- Test documentation examples

### Documentation

Update documentation:

1. API references
2. Examples
3. Type definitions
4. Performance notes

### Final Checklist

Before marking PR as ready:

- [ ] Tests pass
- [ ] Documentation updated
- [ ] Code follows style guide
- [ ] Commits are clean
- [ ] PR description complete
- [ ] Changes reviewed locally

## After Submission

1. Respond to review comments
2. Keep PR updated with main
3. Help with integration testing
4. Update based on feedback

## Getting Help

Need help with your PR?

- Ask in Discord
- Comment on the PR
- Tag maintainers if stuck