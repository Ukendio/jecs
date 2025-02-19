# Contributing to Jecs

Thank you for your interest in contributing to Jecs! This document will help you get started with contributing to the project.

## Code of Conduct

We expect all contributors to follow our Code of Conduct. Please be respectful and professional in all interactions.

## Ways to Contribute

There are many ways to contribute to Jecs:

1. **Bug Reports**: Report bugs through [GitHub Issues](https://github.com/ukendio/jecs/issues)
2. **Feature Requests**: Suggest new features or improvements
3. **Documentation**: Help improve or translate documentation
4. **Code Contributions**: Submit pull requests for bug fixes or features
5. **Examples**: Create example projects using Jecs

## Development Setup

1. Fork and clone the repository:
```bash
git clone https://github.com/your-username/jecs.git
cd jecs
```

2. Install dependencies:
```bash
# Using Wally (Luau)
wally install

# Using npm (TypeScript)
npm install
```

3. Run tests:
```bash
# Luau tests
luau test/tests.luau
```

## Code Style

- Follow existing code style and formatting
- Use clear, descriptive variable and function names
- Add comments for complex logic
- Include type annotations
- Write tests for new features

## Commit Messages

- Use clear, descriptive commit messages
- Start with a verb in present tense (e.g., "Add", "Fix", "Update")
- Reference issue numbers when applicable

Example:
```
Add relationship query caching (#123)

- Implement query result caching for relationship queries
- Add cache invalidation on component changes
- Update documentation with caching examples
```

## Documentation

When adding new features or making changes:

1. Update relevant API documentation
2. Add examples demonstrating usage
3. Update type definitions if necessary
4. Consider adding performance benchmarks for significant changes

## Testing

- Add tests for new features
- Ensure all tests pass before submitting PR
- Include performance tests for performance-critical code
- Test both Luau and TypeScript implementations

## Getting Help

If you need help:

- Join our [Discord server](https://discord.gg/h2NV8PqhAD)
- Ask questions in GitHub Discussions
- Check existing issues and documentation

## License

By contributing to Jecs, you agree that your contributions will be licensed under the MIT License.