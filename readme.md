A TypeScript wrapper of Apple's [EventKit](https://developer.apple.com/documentation/eventkit) framework implemented natively via Objective C++ addons using Node-API.

## About

> [!NOTE]
> Project under development.
>
> The legacy wrapper (using Swift dynamic libs + FFI) is still available at /legacy, however it isa
> broken on recent Node.js releases due to outdated [node-ffi](https://github.com/node-ffi/node-ffi)/[node-ffi-napi](https://github.com/node-ffi-napi/node-ffi-napi).

### Why?

The native Apple frameworks expose their API to Objective-C and Swift, and
occasionally C (e.g. Core Graphics or certain parts of Core Audio). 

This project exposes Apple's EventKit framework to JavaScript/Typescript
enabling interaction with Calendars and Reminders from Node.js.

### XXX TODO
