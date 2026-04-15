<!-- EXAMPLE RULE: TypeScript Standards
  Rules files in base/rules/ apply to all profiles. Drop any .md file here
  and it gets deployed to ~/.claude/rules/ on sync.

  This example covers TypeScript style, typing discipline, tooling, and
  best practices. Replace with standards for your primary language if
  you don't use TypeScript. -->

# TypeScript Standards

## Style
- Always use the most up to date version of the language
- Use 2 spaces for indentation
- Use single quotes for strings
- Add trailing commas in objects and arrays
- Use descriptive variable and function names
- Prefer const over let, avoid var

## Typing
- Strict typing required
- Use type annotations
- Use explicit types for all function parameters and return values
- Avoid `any` type - use `unknown` if type is truly unknown
- Use type inference for simple variable declarations

## Tooling
- Use ESLint with TypeScript rules for code quality
- Use Prettier for consistent formatting (integrates with 2-space, single-quote preferences)
- Configure `strict: true` in tsconfig.json
- Enable `noUnusedLocals` and `noUnusedParameters` in tsconfig.json

## Code Organization
- Use barrel exports (index.ts files) for clean imports
- Group imports: external packages, then internal modules, then relative imports
- Use path mapping in tsconfig.json for cleaner imports (`@/components` instead of `../../../components`)

## Best Practices
- Prefer interfaces over type aliases for object shapes
- Use enums for related constants: `enum Status { PENDING, COMPLETED }`
- Use optional chaining (`?.`) and nullish coalescing (`??`) operators
- Prefer `readonly` arrays when data shouldn't be mutated
- Use utility types: `Partial<T>`, `Pick<T, K>`, `Omit<T, K>`

## Error Handling
- Create custom error classes that extend Error
- Use discriminated unions for result types instead of throwing
- Example: `type Result<T> = { success: true; data: T } | { success: false; error: string }`

## Testing
- Use the project's established testing framework (check `package.json` for Jest, Vitest, or other). For new projects without an established framework, prefer Vitest.
- Name test files with `.test.ts` or `.spec.ts` suffix
- Use type assertions in tests: `expect(result).toEqual<ExpectedType>(...)`
