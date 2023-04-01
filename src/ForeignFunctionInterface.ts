import ffi from "ffi-napi";

// enables console logging raw values during data flow between EventKitJs
// and foreign functions in 'native' dynamic library
const debugMode = false;

// interface to call exposed symbols (c functions) in
// 'native' dynamic library
const foreignFunctionInterface = ffi.Library(
    process.cwd() + "/native/.build/debug/libnative.dylib",
    {
        // define foreign functions and their args here
        getSources: 
            ["bool", 
            ["int", "string"]],
        getEvents: 
            ["bool", 
            ["int", "string", "string"]],
        getEventsWithinDateRange: [
            "bool",
            ["int", "string", "string", "string", "string"]],
        getCalendars: 
            ["bool", 
            ["int", "string", "uint"]],
        // getCalendarsOfSource: ["bool", ["int", "string", "string"]],
    }
);
type ForeignFunction = keyof typeof foreignFunctionInterface;
// types of foreign functions available to call from native
// type ForeignFunction = typeof foreignFunctions[keyof typeof foreignFunctions];

const maxBufferIncreases = 5;
const bufferIncreaseMultiplier = 2;
const initialBufferAllocationSize = 10000;

// Handles foreign function calls and data flow between foreign functions
// in the 'native' dynamic library
export function foreignFunctionCaller<returnType>(
    foreignFunction: ForeignFunction,
    foreignFunctionArgs?: Array<any>
): [returnType] {
    // mutable variables used in for loop for control flow
    let bufferAllocationSize = initialBufferAllocationSize;
    let successfulWrite = false;

    for (let i = 0; i < maxBufferIncreases; i++) {
        // allocate a buffer to pass to foreign function for it to write to.
        //
        // currently node-ffi can only return boolean types, thus passing a
        // buffer for which json string data is written to and expecting a
        // boolean return value from the foreign function call to indicate
        // whether the internal affairs of the foreign function were
        // succesful, is the implemented behaviour.
        const buffer = Buffer.alloc(bufferAllocationSize);

        // if is a getSources call
        if (foreignFunction == "getSources") {
            successfulWrite = foreignFunctionInterface.getSources(
                buffer.byteLength,
                // @ts-ignore
                buffer
            );
        }
        // if getEvents call
        // else if (foreignFunction == "getEvents") {
        //     if (foreignFunctionArgs == undefined)
        //         throw new Error("foreign function call expects args");
        //     successfulWrite = foreignFunctionInterface.getEvents(
        //         buffer.byteLength,
        //         // @ts-ignore
        //         buffer,
        //         foreignFunctionArgs[0]
        //     );
        // }
        // if getEventsWithinDateRange call
        // else if (foreignFunction == "getEventsWithinDateRange") {
        //     if (foreignFunctionArgs == undefined)
        //         throw new Error("foreign function call expects args");
        //     successfulWrite = foreignFunctionInterface.getEventsWithinDateRange(
        //         buffer.byteLength,
        //         // @ts-ignore
        //         buffer,
        //         foreignFunctionArgs[0],
        //         foreignFunctionArgs[1],
        //         foreignFunctionArgs[2]
        //     );
        // }
        // if getCalendars call
        else if (foreignFunction == "getCalendars") {
            if (foreignFunctionArgs == undefined)
                throw new Error("foreign function call expects args");
            successfulWrite = foreignFunctionInterface.getCalendars(
                buffer.byteLength,
                // @ts-ignore
                buffer,
                foreignFunctionArgs[0]
            );
        }

        // if foreign function succesfully wrote intended data to buffer
        if (successfulWrite == true) {
            // any errors in scope will be the result of trying to read
            // an empty buffer. the fault of this problem will likely
            // be  foreign function
            try {
                const response = buffer.toString("utf8").split("\x00", 1);
                const responseAsJSON = JSON.parse(response[0]);
                return responseAsJSON as [returnType];
            } catch (e) {
                throw new Error("cannot parse returned empty buffer data");
            }
            // return this.parseBuffer<model>(buffer);
        }
        // foreign function returned false
        // (often caused by buffer size being too small for the
        // data that the foreign function is trying to write)
        else {
            // foreign functions should write an error message to buffer
            // indicating why they returned false.
            // NOTE: these error messages are only logged in debug mode
            if (debugMode) console.debug(buffer.toString());

            // increase buffer size and retry foreign function call if retry
            // limit has not been reached
            bufferAllocationSize +=
                bufferIncreaseMultiplier * bufferAllocationSize;
        }
    }
    // throw when for loop terminates without function return occuring
    // within its scope
    throw new Error("buffer size requirement exceeds max retry size");
}
