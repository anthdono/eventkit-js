export const EKSpan = {
  THIS_EVENT: "thisEvent",
  FUTURE_EVENTS: "futureEvents",
} as const;

export type EKSpan = typeof EKSpan;
