<!-- EXAMPLE RULE: Testing Strategy
  Rules files in base/rules/ apply to all profiles. Drop any .md file here
  and it gets deployed to ~/.claude/rules/ on sync.

  This example covers the testing pyramid, unit/integration test guidelines,
  test organization, and the philosophy that tests should be fast and
  focused. Adjust to your testing framework and preferences. -->

# Testing Strategy

- Follow the testing pyramid: more unit tests, fewer integration tests, minimal e2e tests
- Unit tests should:
  - Test individual functions/methods in isolation
  - Use descriptive test names that explain the scenario
  - Follow AAA pattern: Arrange, Act, Assert
  - Mock external dependencies
- Integration tests should:
  - Test component interactions (API endpoints, database operations)
  - Use test databases or containers when possible
  - Focus on critical user flows
- Test organization:
  - Keep tests close to source code (`__tests__` folders or `.test.ts` files)
  - Group related tests in describe blocks
  - Use consistent naming: `describe('ComponentName')` and `it('should do something when condition')`
- Property-based testing should focus on core business logic and data transformations
- Aim for fast test execution - slow tests discourage running them
- Write tests that fail for the right reasons - avoid brittle tests that break on implementation details
- Test error conditions and edge cases, not just happy paths
- Property-based testing should always be created with the goal of ensuring core functionality works and should not be so overloaded that it slows down development because of long, superfluous, and unfocused testing run-times with unnecessarily large amounts of input. The goal is to not let perfect be the enemy of the good.
