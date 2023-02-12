"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ioBufferHandler = void 0;
function parseBuffer(buffer) {
    const response = buffer.toString("utf8").split("\x00", 1);
    const responseAsJSON = JSON.parse(response[0]);
    return responseAsJSON;
}
function ioBufferHandler(nativeLibCall, data) {
    let bufferAllocationSize = 10000;
    const maxBufferIncreases = 5;
    const bufferIncreaseMultiplier = 2;
    let successfulWrite = false;
    for (let i = 0; i < maxBufferIncreases; i++) {
        const buffer = Buffer.alloc(bufferAllocationSize);
        try {
            successfulWrite = nativeLibCall(buffer.byteLength, buffer, JSON.stringify(data));
            if (successfulWrite == true) {
                return parseBuffer(buffer);
            }
            else
                throw new Error(buffer.toString());
        }
        catch (e) {
            bufferAllocationSize +=
                bufferIncreaseMultiplier * bufferAllocationSize;
        }
    }
    throw new Error("buffer size requirement exceeds max retry size");
}
exports.ioBufferHandler = ioBufferHandler;
//# sourceMappingURL=helpers.js.map