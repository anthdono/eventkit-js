import { ModelsAdapter } from "../adapters";
import { EKSource, CGColor, EKEntityMask, EKSourceType } from ".";
import { IAdaptable } from "../interfaces";

export class EKCalendar implements IAdaptable {
    calendarIdentifier: string;
    title: string;
    allowsContentModifications: boolean;
    allowedEntityTypes: (typeof EKEntityMask)[keyof typeof EKEntityMask];
    type: (typeof EKSourceType)[keyof typeof EKSourceType];
    source: EKSource;
    cgColor: CGColor;

    fromSwiftModel(object: any): EKCalendar {
        const result = new EKCalendar();

        result.calendarIdentifier = object["calendarIdentifier"];

        result.title = object["title"];

        result.allowsContentModifications =
            object["allowsContentModifications"];

        result.allowedEntityTypes =
            EKEntityMask[
                object["allowedEntityTypes"] as keyof typeof EKEntityMask
            ];

        result.type = ModelsAdapter.adaptModelFromSwift(
            new EKSourceType(),
            object["type"]
        );


        result.source = new EKSource().fromSwiftModel(object["source"]);

        result.cgColor = new CGColor().fromSwiftModel(object["cgColor"]);

        return result;
    }

    toSwiftModel() {
        return {
            calendarIdentifier: this.calendarIdentifier,
        };
    }
}
