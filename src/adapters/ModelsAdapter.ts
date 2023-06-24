import { IAdaptable } from "../interfaces";

export class ModelsAdapter {
    private constructor() {}

    public static adaptModelToSwift<T extends IAdaptable>(object: T): any;
    public static adaptModelToSwift<T extends IAdaptable>(object: T[]): any;
    public static adaptModelToSwift<T extends IAdaptable>(
        object: T | T[]
    ): any | Array<any> {
        if (Array.isArray(object)) {
            const results = Array<any>();
            object.forEach((obj) => {
                results.push(obj.toSwiftModel());
            });
        } else {
            return object.toSwiftModel();
        }
    }

    public static adaptModelFromSwift<T extends IAdaptable>(
        model: T,
        object: any
    ): T;
    public static adaptModelFromSwift<T extends IAdaptable>(
        model: T[],
        object: any[]
    ): T[];
    public static adaptModelFromSwift<T extends IAdaptable>(
        model: T | T[],
        object: any | any[]
    ): T | T[] {
        if (Array.isArray(model) && Array.isArray(object)) {
            const results = Array<T>();
            object.forEach((obj) => {
                results.push(model[0].fromSwiftModel(obj));
            });
            return results;
        } else if (!Array.isArray(model)) {
            return model.fromSwiftModel(object);
        }
        throw new Error(`model to and object from are incompatible`);
    }
}
