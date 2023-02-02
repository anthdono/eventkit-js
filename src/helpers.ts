import { NativeLibCall } from "src/types";

function parseBuffer<T>(buffer: Buffer): [T] {
    const response = buffer.toString("utf8").split("\x00", 1);
    const responseAsJSON = JSON.parse(response[0]);
    return responseAsJSON as [T];
}

export function ioBufferHandler<F, T>(
    nativeLibCall: NativeLibCall,
    data: [F] | undefined
): [T] {
    let bufferAllocationSize = 10000;
    const maxBufferIncreases = 2;
    const bufferIncreaseMultiplier = 2;
    let successfulWrite = false;

    for (let i = 0; i < maxBufferIncreases; i++) {
        const buffer = Buffer.alloc(bufferAllocationSize);
        try {
            successfulWrite = nativeLibCall(
                buffer.byteLength,
                // @ts-ignore passing buffer for string arg
                buffer,
                JSON.stringify(data)
            );
            if (successfulWrite == true) {
                return parseBuffer<T>(buffer);
            } else throw new Error(buffer.toString());
        } catch (e) {
            console.debug(e);
            bufferAllocationSize +=
                bufferIncreaseMultiplier * bufferAllocationSize;
        }
    }
    throw new Error("buffer size requirement exceeds max retry size");
}
