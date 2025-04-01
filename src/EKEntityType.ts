export const EKEntityType = {
  EVENT: "event",
  REMINDER: "reminder",
} as const;

export type EKEntityType = typeof EKEntityType;
