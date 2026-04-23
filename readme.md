A TypeScript wrapper of Apple's [EventKit](https://developer.apple.com/documentation/eventkit) framework implemented natively via Objective C++ addons using Node-API.

> [!NOTE]
> Project under development, see [coverage](./docs/coverage.md)
>
> The legacy wrapper (using Swift dynamic libs + FFI) is still available at /legacy, however it isa
> broken on recent Node.js releases due to outdated [node-ffi](https://github.com/node-ffi/node-ffi)/[node-ffi-napi](https://github.com/node-ffi-napi/node-ffi-napi).

## About

### Why?

The native Apple frameworks expose their API to Objective-C and Swift, and
occasionally C (e.g. Core Graphics or certain parts of Core Audio). 

This project exposes Apple's EventKit framework to JavaScript/Typescript
enabling interaction with Calendars and Reminders from Node.js.

### XXX TODO

- Library API trys to mimic swift docs 
https://developer.apple.com/documentation/eventkit/ekevent

## Running on macOS 14+

Consuming applications must include `NSCalendarsFullAccessUsageDescription`
and `NSRemindersFullAccessUsageDescription` keys in the app bundle's
`Info.plist`, and the binary must be signed. Without these, the
`request*Access*` methods on `EKEventStore` resolve silently with
`granted=false` and no system dialog is shown. This applies to any host
app that ships a Node runtime — the `node` binary itself does not carry
these keys, so running under bare `node` will never trigger the dialog.
