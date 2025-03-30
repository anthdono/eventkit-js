export class DateAdapter {
    public static toSwiftDate(date: Date): number {
        // NOTE: default encoding of swift date model to json is ms since 2001/1/1
        const referenceDate = new Date("2001-01-01T00:00:00Z");
        return (date.getTime() - referenceDate.getTime()) / 1000;
    }

    public static fromSwiftDate(date: number): Date | undefined {
        if(date == undefined) return date
        const referenceDate = new Date("2001-01-01T00:00:00Z");
        return new Date(date * 1000 + referenceDate.getTime());
    }
}
