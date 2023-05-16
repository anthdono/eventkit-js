import { IAdaptable } from "src/interfaces";
import { EKSourceType } from ".";

export class EKSource implements IAdaptable {
    public constructor() {}

    title: string;
    sourceType: (typeof EKSourceType)[keyof typeof EKSourceType];
    sourceIdentifier: string;

    fromSwiftModel(object: any): EKSource {
        const result = new EKSource();

        result.title = object["title"];
        result.sourceType =
            EKSourceType[object["sourceType"] as keyof typeof EKSourceType];
        result.sourceIdentifier = object["sourceIdentifier"];

        return result;
    }
    toSwiftModel() {
        throw new Error("Method not implemented.");
    }
}
