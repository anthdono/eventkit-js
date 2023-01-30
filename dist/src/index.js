"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.EventKit = void 0;
const ffi_napi_1 = __importDefault(require("ffi-napi"));
class EventKit {
    constructor() {
        this.dylibSrc = `
        /Users/anthdono/workspace/apple-EventKit-nodejs-wrapper/
        native/.build/x86_64-apple-macosx/debug/libnative.dylib`;
        this.dylib = ffi_napi_1.default.Library(this.dylibSrc, {
            sources: ["bool", ["int", "string"]],
            createStore: ["bool", []],
        });
    }
    createStore() {
        const success = this.dylib.createStore();
        return success;
    }
    sources() {
        const buf = Buffer.alloc(2000);
        try {
            const success = this.dylib.sources(buf.byteLength, buf);
            if (success == true) {
                const response = buf.toString("utf8").split("\x00", 1);
                const responseAsJSON = JSON.parse(response[0]);
                return responseAsJSON;
            }
            else if (success == false) {
                throw new Error(buf.toString("utf8"));
            }
        }
        catch (e) {
            console.log(e);
        }
    }
}
exports.EventKit = EventKit;
//# sourceMappingURL=index.js.map