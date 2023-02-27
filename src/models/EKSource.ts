// https://developer.apple.com/documentation/eventkit/eksource

// An abstract superclass that represents the account a calendar belongs to.
export type EKSource = {
    title: string;
    sourceType: keyof typeof EKSourceType;
    sourceIdentifier: SourceIdentifier;
};

export const EKSourceType = {
    0: "local",
    1: "exchange",
    2: "calDAV",
    3: "mobileMe",
    4: "subscribed",
    5: "birthdays",
} as const;

export type SourceIdentifier = string;