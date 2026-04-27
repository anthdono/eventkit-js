// developer.apple.com/documentation/eventkit/ekerrordomain
//
// Structured error type for EventKit operations. Subclasses Error so
// `instanceof Error` still passes and `.message` keeps working —
// additive for typical consumers; only callers checking
// `e.constructor === Error` or string-matching messages break.

import { EKErrorCode, _fromNative as _codeFromNative } from "./EKErrorCode";

export class EKError extends Error {
    code: EKErrorCode;
    domain: string;        // typically "EKErrorDomain"
    underlying?: { domain: string; code: number; message: string };

    constructor(
        message: string,
        code: EKErrorCode,
        domain: string,
        underlying?: EKError["underlying"]
    ) {
        super(message);
        this.name = "EKError";
        this.code = code;
        this.domain = domain;
        this.underlying = underlying;
    }
}

// Wrap a raw Error thrown by the native layer into a structured EKError.
// Native side throws Error with a numeric `.code` plus `.domain` and
// `.underlying` payload; this helper translates the integer code into
// the string-named EKErrorCode. Pass-through if the raw error doesn't
// carry a numeric `.code` (e.g., a TypeError from argument validation).
export function _wrapNativeError(rawError: any): any {
    if (!(rawError && typeof rawError.code === "number")) return rawError;
    return new EKError(
        rawError.message,
        _codeFromNative(rawError.code),
        rawError.domain,
        rawError.underlying,
    );
}
