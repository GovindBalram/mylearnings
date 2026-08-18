# Copilot Instructions for mylearnings

This is a personal learning repository. Copilot sessions in this repo should follow these guidelines.

## Repository Purpose

**mylearnings** is a learning and practice repository for exploring various programming concepts, technologies, and techniques. Content is exploratory and may include incomplete experiments, examples, and study notes.

## Directory Structure

Future organization should follow this pattern:

- `/[technology-or-topic]/` - Organize learning materials by technology or concept
  - `README.md` - Overview of the topic and key learnings
  - `examples/` - Working code examples
  - `notes/` - Study notes and reference material
  - `exercises/` - Practice problems or self-directed exercises
  - `resources/` - Links and references to external learning materials

Example structure:
```
/python-fundamentals/
  README.md
  examples/
    data_structures.py
    functions.py
  notes/
    decorators.md
```

## Common Tasks & Patterns

### Adding new learning material
1. Create a directory with a clear topic name (use hyphens, not spaces)
2. Start with a `README.md` explaining what will be learned
3. Add working examples first, then organize into subdirectories as content grows

### Documentation expectations
- `README.md` in each topic directory should include:
  - Brief description of the topic
  - Key concepts covered
  - Links to external resources
  - How to run any examples or exercises

### Code examples
- Keep examples small and focused (one concept per file when possible)
- Include comments explaining non-obvious parts
- Test examples to ensure they work before committing

## Git Conventions

- Commit messages should be descriptive: "Add [topic]: [specific learning item]" (e.g., "Add python-fundamentals: decorator pattern example")
- Use clear branch names for experimental topics: `learn/[topic-name]`
- Keep the main branch stable with working content

## No build/test/lint requirements

This repository contains learning materials and examples, not production code. There are no CI/CD pipelines or automated tests to maintain at this stage. However, code examples should be manually verified to work correctly before committing.
