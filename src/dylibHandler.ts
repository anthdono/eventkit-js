import { DylibFunction } from "./dylib";

export class dylibHandler {
    private static maxBufferIncreases = 5;
    private static bufferIncreaseMultiplier = 2;
    private static initialBufferAllocationSize = 10000;

    private static debugMode = false;

    public static IO<BufferType>(
        dylibFunction: DylibFunction,
        numberOfArgs: 0 | 1 | 2 | 3,
        args?: unknown[]
    ): [BufferType] {
        let bufferAllocationSize = this.initialBufferAllocationSize;
        let successfulWrite = false;

        for (let i = 0; i < this.maxBufferIncreases; i++) {
            const buffer = Buffer.alloc(bufferAllocationSize);

            successfulWrite = (() => {
                if (numberOfArgs == 0)
                    // @ts-ignore
                    return dylibFunction(buffer.byteLength, buffer);
                else if (numberOfArgs == 1)
                    return (successfulWrite =
                        // @ts-ignore
                        dylibFunction(
                            buffer.byteLength,
                            buffer,
                            JSON.stringify(args!)
                        ));
                else if (numberOfArgs == 2)
                    // @ts-ignore
                    return (successfulWrite = dylibFunction(
                        buffer.byteLength,
                        buffer,
                        JSON.stringify(args![0]),
                        JSON.stringify(args![1])
                    ));
                else if (numberOfArgs == 3)
                    return (successfulWrite = dylibFunction(
                        buffer.byteLength,
                        // @ts-ignore
                        buffer,
                        JSON.stringify(args![0]),
                        JSON.stringify(args![1]),
                        JSON.stringify(args![2])
                    ));
                else return false;
            })();

            if (successfulWrite == true) {
                return this.parseBuffer<BufferType>(buffer);
            } else {
                if (this.debugMode) console.debug(buffer.toString());
                bufferAllocationSize +=
                    this.bufferIncreaseMultiplier * bufferAllocationSize;
            }
        }
        throw new Error("buffer size requirement exceeds max retry size");
    }

    private static parseBuffer<T>(buffer: Buffer): [T] {
        try {
            const response = buffer.toString("utf8").split("\x00", 1);
            const responseAsJSON = JSON.parse(response[0]);
            return responseAsJSON as [T];
        } catch (e) {
            throw new Error("cannot parse returned empty buffer data");
        }
    }
}
