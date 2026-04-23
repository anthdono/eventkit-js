# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

TypeScript wrapper around Apple's EventKit framework, implemented as a Node-API native addon in Objective-C++. **macOS-only** — the native build links `-framework EventKit` and includes `<EventKit/…>` and `<Foundation/…>` headers.

Project is under active development; most `EKEventStore` methods currently `throw new NotImplemented`. Coverage status is tracked at `docs/coverage.md`.

## Commands

- `npm run build` — rebuild native addon + compile TS (required before tests; `EKEventStore` does `require("../build/Release/addon")` at load time)
- `npm run build:native` — `node-gyp rebuild` only
- `npm run build:ts` — `tsc -p .` only (emits to `lib/`)
- `npm test` — runs `npx jest` (jest config lives inside `package.json`; ts-jest transforms `.ts`)
- Single test: `npx jest path/to/file.test.ts` or `npx jest -t "test name pattern"`

Jest's `testRegex` picks up files under `/tests/` **or** any `*.test.ts` / `*.spec.ts`.

## Architecture

Two layers talking across a single N-API boundary:

1. **TypeScript layer (`src/*.ts`)** — classes mirroring Apple's EventKit API (`EKEventStore`, `EKEvent`, `EKCalendar`, `EKSource`, `EKCalendarItem`, `EKReminder`, `NSPredicate`, and enum-style types like `EKEntityType`, `EKAuthorizationStatus`, `EKSourceType`, `EKSpan`). `src/EventKit.ts` is the public re-export surface. Method/property names and signatures deliberately follow the Swift/Obj-C docs (`developer.apple.com/documentation/eventkit/…`) — preserve that naming when extending.
2. **Native layer (`src/native/addon.mm`)** — the only source listed in `binding.gyp`. It holds a single static `EKEventStore* store`, exposes C functions (`init`, `eventStoreIdentifier`, `sources`, …) via `napi_create_function` inside `Init(...)`, and is registered with `NAPI_MODULE`. To expose a new native method you must (a) add the C function, (b) register it in `Init`, (c) rebuild native, (d) call it from the TS class via the `addon` handle.

Other `.mm` files in `src/native/` (`addon-copy.mm`, `addon2.mm`, `test.mm`, `TestClass.mm`) are scratch/experimental and **not part of the gyp build** — `TestClass.mm` is `#import`ed from `addon.mm` but the others are unused. Don't assume they compile.

### Current native-store model

`addon.mm` uses a single process-wide `static EKEventStore* store` allocated in `init()`. The commented-out `eventStoreInstances` map + `_createEventStore` / `_getEventStore` helpers show an abandoned multi-instance design; if you reintroduce per-instance stores, update both layers together (the TS `EKEventStore.init(sources)` overload currently throws).

### Conventions

- TS source is `strict: false`; `rootDir` is `src/`, output `lib/`. The `legacy/` directory is excluded from the TS build and is being removed (many `D` entries in git status).
- Unimplemented methods should `throw new NotImplemented` (from `src/NotImplemented.ts`) rather than stub-returning — this is how coverage is tracked.
- Enum-style types are exported as `const` objects plus a matching `type` alias (see `EKEntityType.ts`); follow that pattern for new enums rather than TS `enum`.
