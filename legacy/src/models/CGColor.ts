import { IAdaptable } from "../interfaces";

export class CGColor implements IAdaptable {
    colorSpace: String;
    // rgba in decimal format (requires conversion to 0-255)
    components: number[];

    fromSwiftModel(object: any): CGColor {
        const result = new CGColor();
        result.colorSpace = object["colorSpace"];

        const rgba = object["components"] as Array<number>;
        rgba.forEach((color) => {
            color = color * 255;
        });
        result.components = rgba;
        return result;
    }
    toSwiftModel() {
        throw new Error("Method not implemented.");
    }
}
