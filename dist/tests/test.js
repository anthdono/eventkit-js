"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const src_1 = require("../src");
const node_mac_permissions_1 = __importDefault(require("node-mac-permissions"));
const process_1 = __importDefault(require("process"));
(async () => {
    try {
        const permission = await node_mac_permissions_1.default.askForCalendarAccess();
        console.log(permission);
        console.log(process_1.default.env);
        const eventKit = new src_1.EventKit();
        const x = await eventKit.sources();
        console.log(x);
    }
    catch (e) {
        return;
    }
})();
//# sourceMappingURL=test.js.map