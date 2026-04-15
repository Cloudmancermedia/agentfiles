<!-- EXAMPLE RULE: API Design
  Rules files in base/rules/ apply to all profiles. Drop any .md file here
  and it gets deployed to ~/.claude/rules/ on sync.

  This example covers REST API conventions — status codes, URL naming, error
  formats, versioning. Modify to match your API style or delete if you don't
  build APIs. -->

# API Design (REST)

- APIs should always be in REST format and should follow best practices when it comes to naming, url paths, object structures, headers and versioning.
- Use HTTP status codes correctly:
  - 200: Success with response body
  - 201: Created (for POST requests)
  - 204: Success with no response body
  - 400: Bad request (client error)
  - 401: Unauthorized
  - 403: Forbidden
  - 404: Not found
  - 500: Internal server error
- Use consistent error response format:
  ```json
  {
    "error": {
      "code": "VALIDATION_ERROR",
      "message": "User-friendly error message",
      "details": ["Specific field errors if applicable"]
    }
  }
  ```
- URL naming conventions:
  - Use nouns for resources: `/users`, `/orders`
  - Use kebab-case for multi-word resources: `/user-profiles`
  - Use HTTP verbs (GET, POST, PUT, DELETE) instead of verbs in URLs
  - Collection endpoints: `/users` (GET for list, POST for create)
  - Resource endpoints: `/users/{id}` (GET, PUT, DELETE)
- Versioning: Use URL path versioning `/v1/users` for major changes
- Always return JSON with proper `Content-Type` headers
- Use consistent field naming (camelCase for JSON responses)
